package com.photodispatcher.print{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.event.AsyncSQLEvent;
	import com.photodispatcher.event.PrintEvent;
	import com.photodispatcher.factory.WebServiceBuilder;
	import com.photodispatcher.model.mysql.entities.Order;
	import com.photodispatcher.model.mysql.entities.OrderState;
	import com.photodispatcher.model.mysql.entities.PrintGroup;
	import com.photodispatcher.model.SourceProperty;
	import com.photodispatcher.model.mysql.entities.SourceType;
	import com.photodispatcher.model.dao.OrderDAO;
	import com.photodispatcher.model.dao.PrintGroupDAO;
	import com.photodispatcher.model.dao.StateLogDAO;
	import com.photodispatcher.service.web.BaseWeb;
	import com.photodispatcher.util.ArrayUtil;
	import com.photodispatcher.view.ModalPopUp;
	
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.filesystem.File;
	
	import mx.controls.Alert;
	import mx.managers.CursorManager;

	[Event(name="complete", type="flash.events.Event")]
	public class PrintManager_Kill extends EventDispatcher{
		//[Bindable]
		public var isRunning:Boolean=false;

		[Bindable]
		public var isWriting:Boolean=false;

		//map by source.id->map by order.id->Order 
		private var webQueue:Object=new Object;
		
		//PrintGroups in post 
		private var postQueue:Array=[];

		/*
		*complited not saved pg
		*/
		protected var writeQueue:Array=[];

		//map by source->web service
		private var webServices:Object=new Object;

		public function PrintManager_Kill(){
			super(null);
		}

		public function reSync(printGrps:Array):void{
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
			//add from write queue
			inProcess=inProcess.concat(writeQueue);
			
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

		}

		/*
		protected function reSyncFilter(element:*, index:int, arr:Array):Boolean {
			var pg:PrintGroup=element as PrintGroup;
			return pg!=null && (pg.state==OrderState.PRN_WAITE || pg.state==OrderState.PRN_CANCEL);
		}
		*/

		public function post(printGrps:Vector.<Object>,lab:LabGeneric):void{
			var pg:PrintGroup;
			if(isWriting || !lab || !printGrps || printGrps.length==0) return;
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
					if(!dbReadOk) Alert.show('Часть заказов не размещена из-за блокировки чтения.');
					if(!dbStateOk) Alert.show('Часть заказов не размещена из-за не сответствия статуса заказа.');
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
				//dispatchEvent(new Event(Event.COMPLETE));
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
					Alert.show('Ошибка web сервиса: '+svc.errMesage);
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
						Alert.show('Заказ #'+svc.lastOrderId+' отменен на сайте. Обновите данные. Размещение заказа на печать отменено.');
						//mark as canceled
						for each (pg in order.printGroups){
							pg.state=OrderState.CANCELED_SYNC;
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
		

		public function getWriteQueue():Array{
			return writeQueue;
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
				writeQueue.push(e.printGroup);
				flushWriteQueue();
			}
		}
		
		public function savePrintState(printGroups:Array):void{
			if(printGroups) writeQueue=writeQueue.concat(printGroups);
			flushWriteQueue();
		}

		private var writePg:PrintGroup;
		public function flushWriteQueue():void{
			if(isWriting) return;
			if(writeQueue) writeNext();
		}
		private function writeNext():void{
			if(writeQueue.length==0){
				if(!writePg) isWriting=false;
				return;
			}
			var pg:PrintGroup= writeQueue.shift() as PrintGroup;
			if(!pg || (pg.state!=OrderState.PRN_PRINT && pg.state!=OrderState.PRN_COMPLETE && pg.state!=OrderState.ERR_WRITE_LOCK)){
				//isWriting=false;
				writeNext();
				return;
			}
			if(pg.state==OrderState.ERR_WRITE_LOCK) pg.restoreState();//pg.state=OrderState.PRN_PRINT;
			isWriting=true;
			writePg=pg;
			var dao:PrintGroupDAO= new PrintGroupDAO();
			dao.addEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT, onWrite);
			trace('PrintManager write PrintGroup to db '+ pg.id);
			dao.writePrintState(pg);
		}
		private function onWrite(e:AsyncSQLEvent):void{
			var oDAO:PrintGroupDAO=e.target as PrintGroupDAO;
			if(oDAO) oDAO.removeEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT, onWrite);
			if(e.result==AsyncSQLEvent.RESULT_COMLETED){
				trace('PrintManager write completed '+ writePg.id);
				writePg=null;
				writeNext();
			}else{
				trace('PrintManager write locked '+ writePg.id+'; err: '+e.error);
				isWriting=false;
				writePg.state=OrderState.ERR_WRITE_LOCK;
				writeQueue.push(writePg);
				writePg=null;
			}
		}

		private var cancelPostPrintGrps:Array;
		//private var currentLab:LabBase;
		private var currentLabMap:Object;

		public function cancelPost(printGrps:Array,labMap:Object):void{
			//if(isRunning ||!printGrps || !lab) return;
			if(isRunning ||!printGrps || !labMap) return;
			isRunning=true;
			//currentLab=lab;
			currentLabMap=labMap;
			cancelPostPrintGrps=printGrps;
			var dao:PrintGroupDAO= new PrintGroupDAO();
			dao.addEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT, onCancelPostWrite);
			trace('PrintManager cancel print, '+printGrps.length+' print groups');
			var nameMap:Object= new Object();
			var l:LabGeneric;
			for each(l in labMap){
				if(l) nameMap[l.id.toString()]=l.name; 
			}
			dao.cancelPrint(printGrps,nameMap);
		}
		private function onCancelPostWrite(e:AsyncSQLEvent):void{
			var oDAO:PrintGroupDAO=e.target as PrintGroupDAO;
			if(oDAO) oDAO.removeEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT, onCancelPostWrite);
			if(e.result==AsyncSQLEvent.RESULT_COMLETED){
				trace('PrintManager cancel print write db completed.');
				clearHotFolder();
			}else{
				trace('PrintManager cancel print write db locked '+ '; err: '+e.error);
				Alert.show('Отмена печати не выполнена.');
				cancelPostPrintGrps=null;
				isRunning=false;
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
				isRunning=false;
				//currentLab=null;
				currentLabMap=null;
				cancelPostPrintGrps=null;
				return;
			}
			var pg:PrintGroup=cancelPostPrintGrps.pop() as PrintGroup;
			//build path
			var currentLab:LabGeneric=currentLabMap[pg.destination.toString()] as LabGeneric;
			if(!currentLab){
				Alert.show('Не определена лаборатория id:'+pg.destination.toString()+'. Файлы заказа '+pg.id+' не удалены.');
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
				
			var dstFolder:File;
			//check dest folder
			try{
				dstFolder= new File(path);
			}catch(e:Error){}
			if(!dstFolder || !dstFolder.exists || !dstFolder.isDirectory){
				Alert.show('Не найдена папка "'+path+'". Файлы заказа '+pg.id+' не удалены.');
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
			Alert.show('Ошибка при удалении папки.'+e.text);
			deleteNextFolder();
		}
		private function onDelIoFault(e:IOErrorEvent):void{
			var dstFolder:File=e.target as File;
			dstFolder.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onDelFault);
			dstFolder.removeEventListener(IOErrorEvent.IO_ERROR, onDelIoFault);
			dstFolder.removeEventListener(Event.COMPLETE,onDelete);
			Alert.show('Ошибка при удалении папки.'+e.text);
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