package com.photodispatcher.print{
	import com.akmeful.util.Exception;
	import com.photodispatcher.context.Context;
	import com.photodispatcher.event.PrintEvent;
	import com.photodispatcher.factory.LabBuilder;
	import com.photodispatcher.factory.WebServiceBuilder;
	import com.photodispatcher.model.mysql.DbLatch;
	import com.photodispatcher.model.mysql.entities.AbstractEntity;
	import com.photodispatcher.model.mysql.entities.Lab;
	import com.photodispatcher.model.mysql.entities.LabDevice;
	import com.photodispatcher.model.mysql.entities.Order;
	import com.photodispatcher.model.mysql.entities.OrderExtraInfo;
	import com.photodispatcher.model.mysql.entities.OrderState;
	import com.photodispatcher.model.mysql.entities.PrintGroup;
	import com.photodispatcher.model.mysql.entities.SourceProperty;
	import com.photodispatcher.model.mysql.entities.SourceType;
	import com.photodispatcher.model.mysql.entities.StateLog;
	import com.photodispatcher.model.mysql.services.LabService;
	import com.photodispatcher.model.mysql.services.OrderService;
	import com.photodispatcher.model.mysql.services.OrderStateService;
	import com.photodispatcher.model.mysql.services.PrintGroupService;
	import com.photodispatcher.service.web.BaseWeb;
	import com.photodispatcher.util.ArrayUtil;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.filesystem.File;
	
	import mx.collections.ArrayCollection;
	
	import org.granite.tide.Tide;
	
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
		//PrintGroups in load 
		private var loadQueue:Array=[];
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
		
		protected var _devices:ArrayCollection;
		[Bindable(event="devicesChange")]
		public function get devices():ArrayCollection {
			return _devices;
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
			if(rawLabs){
				fillLabs(rawLabs);
				return;
			}
			//TODO 4 print cancel need full lab list (not only active)
			//read from bd
			var svc:LabService=Tide.getInstance().getContext().byType(LabService,true) as LabService;
			var latch:DbLatch= new DbLatch();
			latch.addEventListener(Event.COMPLETE,onLabsLoad);
			latch.addLatch(svc.loadAll(false));
			latch.start();
		}
		private function onLabsLoad(evt:Event):void{
			var latch:DbLatch= evt.target as DbLatch;
			if(!latch) return;
			latch.removeEventListener(Event.COMPLETE,onLabsLoad);
			if(!latch.complite) return;
			var rawLabs:Array=latch.lastDataArr;
			if(!rawLabs) return;
			fillLabs(rawLabs);
		}
		
		private function fillLabs(rawLabs:Array):void{
			//fill labs 
			var lab:Lab;
			var result:Array=[];
			var devArr:Array = [];
			var lb:LabGeneric;
			labNamesMap= new Object();
			for each(lab in rawLabs){
				labNamesMap[lab.id.toString()]=lab.name;
				lb=LabBuilder.build(lab);
				lb.refresh();
				result.push(lb);
				devArr = devArr.concat(lb.devices.toArray());
			}
			_labs.source=result;
			refreshLabs(true);
			
			//fill devices
			_devices = new ArrayCollection(devArr);
			dispatchEvent(new Event("devicesChange"));
			
			_initCompleted=true;
			dispatchEvent(new Event("labsChange"));
			
		}
		
		private function initErr(msg:String):void{
			_labs.source=[];
			dispatchEvent(new Event("labsChange"));
			_devices = null;
			dispatchEvent(new Event("devicesChange"));
			dispatchManagerErr(msg);
		}
		private function dispatchManagerErr(msg:String):void{
			dispatchEvent(new PrintEvent(PrintEvent.MANAGER_ERROR_EVENT,null,msg));
		}

		public function get labMap():Object{
			if(!initCompleted) return null;
			var result:Object= new Object();
			var lab:LabGeneric;
			for each(lab in _labs.source){
				if(lab){
					result[lab.id.toString()]=lab;
				}
			}
			return result;
		}
		
		public function get labDeviceMap():Object {
			if(!initCompleted) return null;
			var result:Object= new Object();
			var dev:LabDevice;
			for each(dev in _devices.source){
				if(dev){
					result[dev.id.toString()]=dev;
				}
			}
			return result;
		}
		
		public function reSync(printGrps:Array=null):void{
			if(printGrps){
				_reSync(printGrps);
				return;
			}
			var svc:PrintGroupService=Tide.getInstance().getContext().byType(PrintGroupService,true) as PrintGroupService;
			var latch:DbLatch= new DbLatch();
			latch.addEventListener(Event.COMPLETE,onLoadPgSync);
			latch.addLatch(svc.loadByState(OrderState.PRN_WAITE,OrderState.PRN_PRINT));
			latch.start();
		}
		private function onLoadPgSync(evt:Event):void{
			var latch:DbLatch= evt.target as DbLatch;
			if(latch){
				latch.removeEventListener(Event.COMPLETE,onLoadPgSync);
				if(!latch.complite) return;
				_reSync(latch.lastDataArr);
			}
		}

		private function _reSync(printGrps:Array):void{
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

			//add from load queue
			inProcess=inProcess.concat(loadQueue);
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
							|| pg.state == OrderState.PRN_PREPARE
							|| pg.state == OrderState.PRN_POST) printGrps.unshift(pg);
					}
				}
			}
			//set print queue 
			queue=printGrps.concat();
			//TODO recalc totals
		}
		
		/**
		 * deprecated
		 */
		public function autoPost():void{
			//labs is refreshed
			//queue is in sync
			
			if(labs.length==0 || !queue || queue.length==0) return;
			var avalLabs:Array=[];
			//check labs
			if (getAvailableLabs().length==0) return;
			
		}
		
		/**
		 * deprecated
		 */
		private function getAvailableLabs():Array{
			if(labs.length==0) return [];
			var lab:LabGeneric;
			var result:Array=[];
			for each(lab in labs){
				if(lab.is_active && lab.is_managed && 
					(lab.onlineState==LabGeneric.STATE_ON || lab.onlineState==LabGeneric.STATE_SCHEDULED_ON) && 
					lab.printQueue.printQueueLen<lab.queue_limit){
					result.push(lab);
				}
			}
			return result;
		}
		
		private function getPrintApplicant():PrintGroup{
			if(!queue || queue.length==0) return null;
			var result:PrintGroup;
			var pg:PrintGroup;
			for each(pg in queue){
				if(pg && (pg.state==OrderState.PRN_WAITE || pg.state==OrderState.PRN_CANCEL || pg.state<0) && pg.state!=OrderState.ERR_WRITE_LOCK && pg.order_folder){
					//lock if cant print???????
				}
			}
			return result;
		}
		
		public function post(printGrps:Vector.<Object>,lab:LabGeneric):void{
			var pg:PrintGroup;
			if(!lab || !printGrps || printGrps.length==0) return;
			lab.addEventListener(PrintEvent.POST_COMPLETE_EVENT,onPostComplete);
			
			//check state & fill vs files
			var ids:ArrayCollection= new ArrayCollection();
			for each(pg in printGrps){
				if(pg && (pg.state==OrderState.PRN_WAITE || pg.state==OrderState.PRN_CANCEL || pg.state<0) && pg.state!=OrderState.ERR_WRITE_LOCK && pg.order_folder){
					pg.destinationLab=lab;
					pg.state=OrderState.PRN_QUEUE;
					//put to load
					var idx:int=loadQueue.indexOf(pg);
					if(idx!=-1){
						loadQueue[idx]=pg;
					}else{
						loadQueue.push(pg);
					}
					ids.addItem(pg.id);
				}
			}
			
			if(ids.length>0){
				var svc:PrintGroupService=Tide.getInstance().getContext().byType(PrintGroupService,true) as PrintGroupService;
				var latch:DbLatch= new DbLatch();
				latch.addEventListener(Event.COMPLETE,onPGLoad);
				latch.addLatch(svc.loadPrintPost(ids));
				latch.start();
			}
		}
		private function onPGLoad(evt:Event):void{
			var pgBd:PrintGroup;
			var pg:PrintGroup;
			var latch:DbLatch= evt.target as DbLatch;
			if(latch) latch.removeEventListener(Event.COMPLETE,onPGLoad);
			if(!latch || !latch.complite){
				//reset
				for each(pg in loadQueue) pg.state=OrderState.PRN_WAITE;
				loadQueue=[];
			}
			var result:Array=latch.lastDataArr;
			var left:Array=[];
			var post:Array=[];
			var idx:int;
			var hasErr:Boolean;
			for each(pg in loadQueue){
				idx= ArrayUtil.searchItemIdx('id',pg.id,result);
				if(idx==-1){
					left.push(pg);
				}else{
					pgBd=result[idx] as PrintGroup;
					if(pgBd){
						if((pgBd.state!=OrderState.PRN_WAITE && pgBd.state!=OrderState.PRN_CANCEL) || !pgBd.files || pgBd.files.length==0){
							//wrong state or empty files
							pg.state=pgBd.state; 
							hasErr=true;
						}else{
							//files loaded & state ok
							pg.files=pgBd.files;
							
							if(pg.is_reprint){
								//skip check's
								pg.state=OrderState.PRN_WEB_OK;
								//add to postQueue
								postQueue.push(pg);
								//post to lab
								var revers:Boolean=Context.getAttribute('reversPrint');
								pg.destinationLab.post(pg,revers);
								
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
									order.printGroups=new ArrayCollection();
									order.state=OrderState.PRN_QUEUE;
									srcOrders[pg.order_id]=order;
								}
								if(order.printGroups.length==0 || order.printGroups.getItemIndex(pg)==-1) order.printGroups.addItem(pg);
							}
						}
					}
				}
			}
			loadQueue=left;
			if(hasErr) dispatchManagerErr('Часть заказов не размещена из-за не сответствия статуса заказа (bd).');
			//start check web state
			//scan sources
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
						StateLog.logByPGroup(OrderState.ERR_WEB,pg.id,'Ошибка проверки на сайте: '+svc.errMesage);
					}
				}else{
					//TODO order can be in state PRN_POST, so check both remote state  
					if(svc.isValidLastOrder()){
						//update extra info 4  FOTOKNIGA type
						if(svc.source.type==SourceType.SRC_FOTOKNIGA && svc.getLastOrder()){
							var ei:OrderExtraInfo=svc.getLastOrder().extraInfo;
							if(ei){
								ei.persistState=AbstractEntity.PERSIST_CHANGED;
								var osvc:OrderService=Tide.getInstance().getContext().byType(OrderService,true) as OrderService;
								var latch:DbLatch= new DbLatch(true);
								latch.addLatch(osvc.persistExtraInfo(ei));
								latch.start();
							}
						}
						//set state 
						for each (pg in order.printGroups){
							prnGrp= pg as PrintGroup;
							if(prnGrp){
								if(prnGrp.state==OrderState.PRN_WEB_CHECK){
									prnGrp.state=OrderState.PRN_WEB_OK;
									//add to postQueue
									postQueue.push(prnGrp);
									//post to lab
									var revers:Boolean=Context.getAttribute('reversPrint');
									prnGrp.destinationLab.post(prnGrp,revers);
								}else{
									StateLog.logByPGroup(OrderState.ERR_WEB,prnGrp.id,'Ошибка статуса при проверке на сайте ('+prnGrp.state.toString()+')');
								}
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
				/*
				var dao:PrintGroupDAO=new PrintGroupDAO();
				dao.addEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT, onWrite);
				dao.writePrintState(e.printGroup);
				*/
				
				var svc:OrderStateService=Tide.getInstance().getContext().byType(OrderStateService,true) as OrderStateService;
				var latch:DbLatch= new DbLatch();
				latch.addEventListener(Event.COMPLETE,onPostWrite);
				latch.addLatch(svc.printPost(e.printGroup.id, e.printGroup.destination));
				latch.start();
			}
		}
		private function onPostWrite(evt:Event):void{ //onWrite(e:AsyncSQLEvent):void{
			/*
			var oDAO:PrintGroupDAO=e.target as PrintGroupDAO;
			if(oDAO) oDAO.removeEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT, onWrite);
			if(e.result!=AsyncSQLEvent.RESULT_COMLETED){
				dispatchManagerErr('Блокировка записи при сохранении статуса группы печати');
			}
			*/
			var latch:DbLatch=evt.target as DbLatch;
			if(latch){
				latch.removeEventListener(Event.COMPLETE,onPostWrite);
			}
			if(postQueue.length==0){
				//complited refresh lab
				refreshLabs();
			}
		}
		
		public function refreshLabs(recalcOnly:Boolean=false):void{
			var newqueueOrders:int;
			var newqueuePGs:int;
			var newqueuePrints:int;
			var lab:LabGeneric;
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
		

		public function setPrintedState(printGroups:Array):void{
			/*
			var dao:PrintGroupDAO=new PrintGroupDAO();
			//dao.addEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT, onWrite);
			var pg:PrintGroup;
			for each(pg in printGroups) dao.writePrintState(pg);
			*/
			if(!printGroups || printGroups.length==0) return;
			var ids:Array=[];
			var pg:PrintGroup;
			for each(pg in printGroups) ids.push(pg.id);
			var svc:OrderStateService=Tide.getInstance().getContext().byType(OrderStateService,true) as OrderStateService;
			var latch:DbLatch= new DbLatch();
			//latch.addEventListener(Event.COMPLETE,onPostWrite);
			latch.addLatch(svc.printEndManual(ids));
			latch.start();
		}
		

		/************ cancel print ***********/
		private var cancelPostPrintGrps:Array;
		
		public function cancelPost(printGrps:Array):void{
			if(isBusy ||!printGrps || !labNamesMap) return;
			isBusy=true;
			//currentLab=lab;
			cancelPostPrintGrps=printGrps;
			/*
			var dao:PrintGroupDAO= new PrintGroupDAO();
			dao.addEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT, onCancelPostWrite);
			trace('PrintManager cancel print, '+printGrps.length+' print groups');
			var l:LabGeneric;
			dao.cancelPrint(printGrps,labNamesMap);
			*/
			var ids:Array=[];
			var pg:PrintGroup;
			for each(pg in cancelPostPrintGrps) ids.push(pg.id);
			var svc:OrderStateService=Tide.getInstance().getContext().byType(OrderStateService,true) as OrderStateService;
			var latch:DbLatch= new DbLatch();
			latch.addEventListener(Event.COMPLETE,onCancelPost);
			latch.addLatch(svc.printCancel(ids));
			latch.start();
		}
		private function onCancelPost(evt:Event):void{ //onCancelPostWrite(e:AsyncSQLEvent):void{
			/*
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
			*/
			var latch:DbLatch= evt.target as DbLatch;
			if(latch){
				latch.removeEventListener(Event.COMPLETE,onCancelPost);
				if(latch.complite){
					trace('PrintManager cancel print write db completed.');
					clearHotFolder();
				}else{
					trace('PrintManager cancel print write db locked '+ '; err: '+latch.error);
					dispatchManagerErr('Отмена печати не выполнена.');
					cancelPostPrintGrps=null;
					isBusy=false;
				}
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
			var currentLab:LabGeneric=ArrayUtil.searchItem('id',pg.destination,labs.source) as LabGeneric;
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