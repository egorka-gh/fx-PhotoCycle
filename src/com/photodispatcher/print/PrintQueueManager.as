package com.photodispatcher.print{
	import com.akmeful.util.Exception;
	import com.photodispatcher.context.Context;
	import com.photodispatcher.event.AsyncSQLEvent;
	import com.photodispatcher.event.PrintEvent;
	import com.photodispatcher.factory.LabBuilder;
	import com.photodispatcher.factory.WebServiceBuilder;
	import com.photodispatcher.model.Lab;
	import com.photodispatcher.model.LabDevice;
	import com.photodispatcher.model.Order;
	import com.photodispatcher.model.OrderState;
	import com.photodispatcher.model.PrintGroup;
	import com.photodispatcher.model.SourceProperty;
	import com.photodispatcher.model.SourceType;
	import com.photodispatcher.model.dao.LabDAO;
	import com.photodispatcher.model.dao.OrderDAO;
	import com.photodispatcher.model.dao.PrintGroupDAO;
	import com.photodispatcher.model.dao.StateLogDAO;
	import com.photodispatcher.service.web.BaseWeb;
	import com.photodispatcher.util.ArrayUtil;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.filesystem.File;
	
	import mx.collections.ArrayCollection;
	
	[Event(name="managerError", type="com.photodispatcher.event.PrintEvent")]
	public class PrintQueueManager extends EventDispatcher{
		
		[Bindable]
		public var queueOrders:int;
		[Bindable]
		public var queuePGs:int;
		[Bindable]
		public var queuePrints:int;

		[Bindable]
		public var isBusy:Boolean=false;
		
		//print queue (printgroups)
		private var queue:Array;
		
		//map by source.id->map by order.id->Order 
		private var webQueue:Object=new Object;
		//map by source->web service
		private var webServices:Object=new Object;
		//PrintGroups in post 
		private var postQueue:Array=[];
		private var labNamesMap:Object;
		
		private var _initCompleted:Boolean=false;
		public function get initCompleted():Boolean{
			return _initCompleted;
		}

		
		private static var _instance:PrintQueueManager;
		public static function get instance():PrintQueueManager{
			if(_instance == null) var t:PrintQueueManager=new PrintQueueManager();
			return _instance;
		}
		
		private var _labs:ArrayCollection=new ArrayCollection();
		[Bindable(event="labsChange")]
		public function get labs():ArrayCollection{
			return _labs;
		}

		public function PrintQueueManager(){
			super(null);
			if(_instance == null){
				_instance = this;
			} else {
				throw new Exception(Exception.SINGLETON);
			}
		}
		
		public function init(rawLabs:Array=null):void{
			if(!rawLabs && initCompleted) return; 
			//TODO 4 print cancel need full lab list (not only active)
			if(rawLabs){//init from labaratory
				if(rawLabs.length==0){
					_initCompleted=false;
					return;
				}
			}
			if(!rawLabs){ //default init
				var dao:LabDAO= new LabDAO();
				var rawLabs:Array=dao.findActive(true);
				if(rawLabs==null){
					initErr('Блокировка чтения при инициализации менеджера печати');
					return;
				}
			}
			//fill labs from db
			var lab:Lab;
			var dev:LabDevice;
			var result:Array=[];
			labNamesMap= new Object();
			for each(lab in rawLabs){
				labNamesMap[lab.id.toString()]=lab.name;
				lab.getDevices(true);
				if(!lab.devices){
					initErr('Блокировка чтения при инициализации менеджера печати');
					return;
				}
				for each(dev in lab.devices){
					dev.getRolls(false,true);
					dev.getTimetable(true);
					if(!dev.rolls || !dev.timetable){
						initErr('Блокировка чтения при инициализации менеджера печати');
						return;
					}
				}
				var lb:LabBase=LabBuilder.build(lab);
				lb.refreshOnlineState();
				lb.refreshPrintQueue();
				result.push(lb);
			}
			_labs.source=result;
			refreshLabs(true);
			_initCompleted=true;
			dispatchEvent(new Event("labsChange"));
			/*
			//fill lab names (4 cancel print)
			rawLabs=dao.findAllArray(true);
			if(rawLabs==null){
				initErr('Блокировка чтения при инициализации менеджера печати');
				return;
			}
			labNamesMap= new Object();
			for each(lab in rawLabs){
				labNamesMap[lab.id.toString()]=lab.name;
			}
			*/
		}
		
		private function initErr(msg:String):void{
			_labs.source=[];
			dispatchEvent(new Event("labsChange"));
			dispatchManagerErr(msg);
		}
		private function dispatchManagerErr(msg:String):void{
			dispatchEvent(new PrintEvent(PrintEvent.MANAGER_ERROR_EVENT,null,msg));
		}

		public function get labMap():Object{
			if(!initCompleted) return null;
			var result:Object= new Object();
			var lab:LabBase;
			for each(lab in _labs.source){
				if(lab){
					result[lab.id.toString()]=lab;
				}
			}
			return result;
		}
		
		public function reSync(printGrps:Array=null):void{
			if (!printGrps){
				var pgDao:PrintGroupDAO=new PrintGroupDAO();
				printGrps=pgDao.findAllArray(OrderState.PRN_WAITE,OrderState.PRN_PRINT);

			}
			if (!printGrps) return; //read lock
			
			//PrintGroup to save
			var inProcess:Array=[];
			
			var o:Object;
			var oMap:Object;
			var order:Order;
			var pg:PrintGroup;
			
			if(!printGrps) printGrps=[];
			//add from web queue
			for each(oMap in webQueue){
				for (var key:String in oMap){
					order=oMap[key] as Order;
					if(order && order.printGroups){
						for each(o in order.printGroups){
							inProcess.push(o);
						}
					}
				}
			}
			//add from post queue
			inProcess=inProcess.concat(postQueue);
			
			var idx:int;
			for each(o in inProcess){
				pg= o as PrintGroup;
				if(pg){
					//replace
					idx=ArrayUtil.searchItemIdx('id',pg.id,printGrps);
					if(idx!=-1){
						printGrps[idx]=pg;
					}else{
						//add?
						trace('PrintManager.reSync printGroup not found, add');
						if(pg.state == OrderState.ERR_WRITE_LOCK 
							|| pg.state == OrderState.PRN_WEB_CHECK
							|| pg.state == OrderState.PRN_WEB_OK
							|| pg.state == OrderState.PRN_POST) printGrps.unshift(pg);
					}
				}
			}
			//set print queue 
			queue=printGrps.concat();
			//TODO recalc totals
		}

		public function post(printGrps:Vector.<Object>,lab:LabBase):void{
			var pg:PrintGroup;
			if(!lab || !printGrps || printGrps.length==0) return;
			lab.addEventListener(PrintEvent.POST_COMPLETE_EVENT,onPostComplete);
			
			//fill webQueue
			for each(var o:Object in printGrps){
				pg= o as PrintGroup;
				if(pg && (pg.state==OrderState.PRN_WAITE || pg.state==OrderState.PRN_CANCEL || pg.state<0) && pg.state!=OrderState.ERR_WRITE_LOCK && pg.order_folder){
					//force load printgroup files
					pg.preparePrint();
					pg.destinationLab=lab;
					pg.state=OrderState.PRN_QUEUE;
					
					//check if reprint
					if(pg.is_reprint){
						//skip check's
						pg.state=OrderState.PRN_WEB_OK;
						//add to postQueue
						postQueue.push(pg);
						//post to lab
						pg.destinationLab.post(pg);
						
					}else{
						//push to webQueue (check print group state) 
						var srcOrders:Object=webQueue[pg.source_id.toString()];
						if(!srcOrders){
							srcOrders=new Object();
							webQueue[pg.source_id.toString()]=srcOrders;
						}
						var order:Order= srcOrders[pg.order_id] as Order;
						if(!order){
							order=new Order();
							order.id=pg.order_id;
							order.source=pg.source_id;
							order.ftp_folder=pg.order_folder;
							order.printGroups=[];
							order.state=OrderState.PRN_QUEUE;
							srcOrders[pg.order_id]=order;
						}
						order.printGroups.push(pg);
					}
				}
			}
			checkOrders();
			
			//start check web state
			//scan sources
			var orderId:String;
			var src_id:String;
			for(src_id in webQueue){
				//var svc:ProfotoWeb=webServices[src_id] as ProfotoWeb;
				var svc:BaseWeb=webServices[src_id] as BaseWeb;
				if(!svc){
					//svc= new ProfotoWeb(Context.getSource(int(src_id)));
					svc= WebServiceBuilder.build(Context.getSource(int(src_id)));
					svc.addEventListener(Event.COMPLETE,serviceCompliteHandler);
					webServices[src_id]=svc;
				}
				if(!svc.isRunning) serviceCheckNext(svc);
			}
			checkWebComplite();
		}

		private function checkOrders():void{
			var oMap:Object;
			//first check in database
			var dbReadOk:Boolean=true;
			var dbStateOk:Boolean=true;
			var order:Order;
			var bdOrder:Order;
			var key:String;
			for each(oMap in webQueue){
				for (key in oMap){
					order=oMap[key] as Order;
					if(order.state==OrderState.PRN_QUEUE && !order.bdCheckComplete){
						//check state in bd
						var pg:Object;
						var dao:OrderDAO=new OrderDAO();
						bdOrder=dao.getItem(order.id);
						if(!bdOrder){
							dbReadOk=false;
							//set errState
							for each (pg in order.printGroups){
								pg.state=OrderState.ERR_READ_LOCK;
							}
							delete oMap[key];
						}else{
							//check state
							if(bdOrder.state!=OrderState.PRN_WAITE && bdOrder.state!=OrderState.PRN_CANCEL && bdOrder.state!=OrderState.PRN_POST){
								dbStateOk=false;
								//set to order state
								for each (pg in order.printGroups){
									pg.state=bdOrder.state;
								}
								delete oMap[key];
							}else{
								order.bdCheckComplete=true;
							}
						}
					}
					if(!dbReadOk) dispatchManagerErr('Часть заказов не размещена из-за блокировки чтения.');
					if(!dbStateOk) dispatchManagerErr('Часть заказов не размещена из-за не сответствия статуса заказа.');
				}
			}
			//clean up webQueue, remove empty orders map
			var srcKey:String;
			for (srcKey in webQueue){
				oMap=webQueue[srcKey];
				key='';
				for (key in oMap){
					if(key) break;
				}
				if(!key) delete webQueue[srcKey];
			}
		}
		
		private function checkWebComplite():Boolean{
			//check if any source in process
			var src_id:String='';
			for(src_id in webServices){
				//var svc:ProfotoWeb=webServices[src_id] as ProfotoWeb;
				var svc:BaseWeb=webServices[src_id] as BaseWeb;
				if(svc && svc.isRunning){
					return false;
				}
			}
			var result:Boolean=true;
			src_id='';
			for(src_id in webQueue){
				result=false;
				break;
			}
			if(result){
				//all sources completed
				trace('PrintManager: web check completed.');
			}
			return result;
		}
		
		private function serviceCheckNext(service:BaseWeb):void{
			if(service.isRunning) return;
			
			var oMap:Object;
			var src_id:String=service.source.id.toString();
			oMap=webQueue[src_id];
			if (!oMap){
				//complited return
				return;
			}
			var order:Order;
			for each(var o:Object in oMap){
				order=o as Order;
				if(order && order.state==OrderState.PRN_QUEUE) break;
			}
			if (order && order.state==OrderState.PRN_QUEUE){
				order.state=OrderState.PRN_WEB_CHECK;
				for each (var pg:Object in order.printGroups){
					pg.state=OrderState.PRN_WEB_CHECK;
				}
				service.getOrder(order);
			}
		}
		
		private function serviceCompliteHandler(e:Event):void{
			var svc:BaseWeb=e.target as BaseWeb;
			var pg:Object;
			var prnGrp:PrintGroup;
			if(svc){
				//svc.removeEventListener(Event.COMPLETE,serviceCompliteHandler);
				var oMap:Object=webQueue[svc.source.id.toString()];
				var order:Order=oMap[svc.lastOrderId] as Order;
				//check web service err
				if(svc.hasError){
					dispatchManagerErr('Ошибка web сервиса: '+svc.errMesage);
					for each (pg in order.printGroups){
						pg.state=OrderState.ERR_WEB;
						StateLogDAO.logState(OrderState.ERR_WEB,order.id,pg.id,'Ошибка проверки на сайте: '+svc.errMesage);
					}
				}else{
					//TODO order can be in state PRN_POST, so check both remote state  
					if(svc.isValidLastOrder()){
						//set state 
						for each (pg in order.printGroups){
							prnGrp= pg as PrintGroup;
							if(prnGrp){
								prnGrp.state=OrderState.PRN_WEB_OK;
								//add to postQueue
								postQueue.push(prnGrp);
								//post to lab
								prnGrp.destinationLab.post(prnGrp);
							}
						}
					}else{
						dispatchManagerErr('Заказ #'+svc.lastOrderId+' отменен на сайте. Обновите данные. Размещение заказа на печать отменено.');
						//mark as canceled
						for each (pg in order.printGroups){
							pg.state=OrderState.CANCELED;
							pg.destinationLab=null;
						}
					}
				}
				delete oMap[svc.lastOrderId];
				//compact webQueue
				var key:String;
				for(key in oMap){
					if(key) break;
				}
				if(!key){
					delete webQueue[svc.source.id.toString()];
				}
				//check next
				serviceCheckNext(svc);
			}
			//check if any source in process
			checkWebComplite();
		}

		private function onPostComplete(e:PrintEvent):void{
			//remove from postQueue
			var idx:int;
			idx=ArrayUtil.searchItemIdx('id',e.printGroup.id,postQueue);
			if(idx!=-1){
				postQueue.splice(idx,1);
			}
			if(!e.hasErr){
				//save
				var dao:PrintGroupDAO=new PrintGroupDAO();
				dao.addEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT, onWrite);
				dao.writePrintState(e.printGroup);
			}
		}
		
		public function refreshLabs(recalcOnly:Boolean=false):void{
			var newqueueOrders:int;
			var newqueuePGs:int;
			var newqueuePrints:int;
			var lab:LabBase;
			for each(lab in _labs.source){
				if(!recalcOnly) lab.refresh();
				newqueueOrders+=lab.printQueue.queueOrders;
				newqueuePGs+=lab.printQueue.queuePGs;
				newqueuePrints+=lab.printQueue.queuePrints;
			}
			queueOrders=newqueueOrders;
			queuePGs=newqueuePGs;
			queuePrints=newqueuePrints;
		}
		
		public function savePrintState(printGroups:Array):void{
			var dao:PrintGroupDAO=new PrintGroupDAO();
			dao.addEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT, onWrite);
			var pg:PrintGroup;
			for each(pg in printGroups) dao.writePrintState(pg);
		}

		private function onWrite(e:AsyncSQLEvent):void{
			var oDAO:PrintGroupDAO=e.target as PrintGroupDAO;
			if(oDAO) oDAO.removeEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT, onWrite);
			if(e.result!=AsyncSQLEvent.RESULT_COMLETED){
				dispatchManagerErr('Блокировка записи при сохранении статуса группы печати');
			}
			if(postQueue.length==0){
				//complited refresh lab
				refreshLabs();
			}
		}

		/************ cancel print ***********/
		private var cancelPostPrintGrps:Array;
		
		public function cancelPost(printGrps:Array):void{
			if(isBusy ||!printGrps || !labNamesMap) return;
			isBusy=true;
			//currentLab=lab;
			cancelPostPrintGrps=printGrps;
			var dao:PrintGroupDAO= new PrintGroupDAO();
			dao.addEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT, onCancelPostWrite);
			trace('PrintManager cancel print, '+printGrps.length+' print groups');
			var l:LabBase;
			dao.cancelPrint(printGrps,labNamesMap);
		}
		private function onCancelPostWrite(e:AsyncSQLEvent):void{
			var oDAO:PrintGroupDAO=e.target as PrintGroupDAO;
			if(oDAO) oDAO.removeEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT, onCancelPostWrite);
			if(e.result==AsyncSQLEvent.RESULT_COMLETED){
				trace('PrintManager cancel print write db completed.');
				clearHotFolder();
			}else{
				trace('PrintManager cancel print write db locked '+ '; err: '+e.error);
				dispatchManagerErr('Отмена печати не выполнена.');
				cancelPostPrintGrps=null;
				isBusy=false;
			}
		}
		private function clearHotFolder():void{
			var pg:PrintGroup;
			for each (var o:Object in cancelPostPrintGrps){
				pg=o as PrintGroup;
				if(pg) pg.state=OrderState.PRN_CANCEL;
			}
			deleteNextFolder();
		}
		private function deleteNextFolder():void{
			if(!cancelPostPrintGrps || cancelPostPrintGrps.length==0){
				//complited
				isBusy=false;
				cancelPostPrintGrps=null;
				return;
			}
			var pg:PrintGroup=cancelPostPrintGrps.pop() as PrintGroup;
			//build path
			var currentLab:LabBase=ArrayUtil.searchItem('id',pg.destination,labs.source) as LabBase;
			if(!currentLab){
				dispatchManagerErr('Не определена лаборатория id:'+pg.destination.toString()+'. Файлы заказа '+pg.id+' не удалены.');
				deleteNextFolder();
				return;
			}
			if(currentLab.src_type==SourceType.LAB_XEROX){
				//TODO implement delete by fiie
				//skiped, xerox hasn't order folder, pdf is order container  
				deleteNextFolder();
				return;
			}
			if(!currentLab.orderFolderName(pg)){
				//skip  
				deleteNextFolder();
				return;
			}
			var prefix:String=SourceProperty.getProperty(currentLab.src_type,SourceProperty.HF_PREFIX);
			var sufix:String=SourceProperty.getProperty(currentLab.src_type,SourceProperty.HF_SUFIX_READY);
			var path:String=currentLab.hot+File.separator+prefix+currentLab.orderFolderName(pg)+sufix;
			var pathNHF:String;
			if(currentLab.src_type==SourceType.LAB_NORITSU && currentLab.hot_nfs){
				prefix=SourceProperty.getProperty(SourceType.LAB_NORITSU_NHF,SourceProperty.HF_PREFIX);
				sufix=SourceProperty.getProperty(SourceType.LAB_NORITSU_NHF,SourceProperty.HF_SUFIX_READY);
				pathNHF=currentLab.hot_nfs+File.separator+prefix+(currentLab as LabNoritsu).orderFolderNameNHF(pg)+sufix;
			}
			
			var dstFolder:File;
			//check dest folder
			try{
				dstFolder= new File(path);
			}catch(e:Error){}
			
			if((!dstFolder || !dstFolder.exists || !dstFolder.isDirectory) && pathNHF){
				try{
					dstFolder= new File(pathNHF);
				}catch(e:Error){}
			}
			if(!dstFolder || !dstFolder.exists || !dstFolder.isDirectory){
				dispatchManagerErr('Не найдена папка "'+path+'". Файлы заказа '+pg.id+' не удалены.');
				deleteNextFolder();
			}
			dstFolder.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onDelFault);
			dstFolder.addEventListener(IOErrorEvent.IO_ERROR, onDelIoFault);
			dstFolder.addEventListener(Event.COMPLETE,onDelete);
			dstFolder.deleteDirectoryAsync(true);
		}
		private function onDelFault(e:SecurityErrorEvent):void{
			var dstFolder:File=e.target as File;
			dstFolder.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onDelFault);
			dstFolder.removeEventListener(IOErrorEvent.IO_ERROR, onDelIoFault);
			dstFolder.removeEventListener(Event.COMPLETE,onDelete);
			dispatchManagerErr('Ошибка при удалении папки.'+e.text);
			deleteNextFolder();
		}
		private function onDelIoFault(e:IOErrorEvent):void{
			var dstFolder:File=e.target as File;
			dstFolder.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onDelFault);
			dstFolder.removeEventListener(IOErrorEvent.IO_ERROR, onDelIoFault);
			dstFolder.removeEventListener(Event.COMPLETE,onDelete);
			dispatchManagerErr('Ошибка при удалении папки.'+e.text);
			deleteNextFolder();
		}
		private function onDelete(e:Event):void{
			var dstFolder:File=e.target as File;
			dstFolder.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onDelFault);
			dstFolder.removeEventListener(IOErrorEvent.IO_ERROR, onDelIoFault);
			dstFolder.removeEventListener(Event.COMPLETE,onDelete);
			deleteNextFolder();
		}

	}
}