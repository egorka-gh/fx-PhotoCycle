package com.photodispatcher.service{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.event.AsyncSQLEvent;
	import com.photodispatcher.factory.WebServiceBuilder;
	import com.photodispatcher.model.ProcessState;
	import com.photodispatcher.model.mysql.AsyncLatch;
	import com.photodispatcher.model.mysql.DbLatch;
	import com.photodispatcher.model.mysql.entities.Order;
	import com.photodispatcher.model.mysql.entities.OrderLoad;
	import com.photodispatcher.model.mysql.entities.OrderState;
	import com.photodispatcher.model.mysql.entities.OrderTemp;
	import com.photodispatcher.model.mysql.entities.Source;
	import com.photodispatcher.model.mysql.entities.SourceType;
	import com.photodispatcher.model.mysql.entities.StateLog;
	import com.photodispatcher.model.mysql.services.OrderLoadService;
	import com.photodispatcher.service.web.BaseWeb;
	import com.photodispatcher.service.web.FotoknigaWeb;
	import com.photodispatcher.util.ArrayUtil;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.filesystem.File;
	import flash.globalization.DateTimeFormatter;
	
	import mx.collections.ArrayCollection;
	import mx.collections.ArrayList;
	import mx.managers.CursorManager;
	
	import org.granite.tide.Tide;
	
	[Event(name="complete", type="flash.events.Event")]
	public class SyncInactiveLoaderService extends EventDispatcher{
		//async, interact vs sites, fetch raw orders into memory
		//serial, interact vs bd, translate to regular order obj's & persists in bd
		
		public var sources:Array;
		
		private var syncItems:Array;
		private var isRunning:Boolean=false;
		private var service:OrderLoadService;
		
		
		
		public function SyncInactiveLoaderService(){
			super(null);
		}
		
		public function get isBusy():Boolean{
			return isRunning;
		}

		public function sync():void{
			if (isRunning) return;
			if (!sources) return;

			webSync();
		}
		
		private var webLath:DbLatch;
		private function webSync():void{
			arrToReset=[];
			isRunning=true;
			syncItems=[];
			webLath=new DbLatch(true);
			webLath.addEventListener(Event.COMPLETE,onWebSyncComplite);
			var aLath:AsyncLatch;
			for each (var src:Source in sources){
				if(src && src.online && src.type==SourceType.SRC_FOTOKNIGA){
					var syncSvc:BaseWeb=WebServiceBuilder.build(src);
					if(syncSvc){
						src.syncState.items=0;
						src.syncState.setState(ProcessState.STATE_RUNINNG,'Синхронизация.');
						aLath=new AsyncLatch();
						syncSvc.latch=aLath;
						webLath.join(aLath);
						aLath.start();
						syncSvc.addEventListener(Event.COMPLETE,handleWebComplete);
						syncSvc.syncActiveLoader();
					}
				}
			}
			//clear temp table
			if(!service) service=Tide.getInstance().getContext().byType(OrderLoadService,true) as OrderLoadService;
			webLath.addLatch(service.beginSync());
			//waite complite
			webLath.start();
		}

		private function endSync():void{
			isRunning=false;
			CursorManager.removeBusyCursor();
			dispatchEvent(new Event(Event.COMPLETE));
			
			//load orders 2 restart
			var dbLatch:DbLatch = new DbLatch(true);
			dbLatch.addEventListener(Event.COMPLETE, onRestartLoaded);
			if(restartCount==0){
				dbLatch.addLatch(service.loadByState(OrderState.FTP_INCOMPLITE, OrderState.FTP_INCOMPLITE+1));
			}else{
				dbLatch.addLatch(service.loadByState(OrderState.CANCELED_LOADER_RESET, OrderState.CANCELED_LOADER_RESET+1));
			}
			dbLatch.start();

		}
		
		private function handleWebComplete(e:Event):void{
			var proSync:BaseWeb=e.target as BaseWeb;
			proSync.removeEventListener(Event.COMPLETE,handleWebComplete);
			//check if completed
			if(proSync.hasError){
				proSync.source.syncState.setState(ProcessState.STATE_ERROR,'Ошибка синхронизации ('+proSync.errMesage+')');
			}else{
				if(proSync.orderes){
					proSync.source.syncState.items=proSync.orderes.length;
				}
				proSync.source.syncState.caption='Web ok. Элементов: '+proSync.source.syncState.items.toString();
				syncItems=syncItems.concat(proSync.orderes);
			}
			proSync.latch.release();
		}

		private function onWebSyncComplite(e:Event):void{
			webLath.removeEventListener(Event.COMPLETE,onWebSyncComplite);
			if(syncItems.length==0){
				endSync();
				return;
			}
			
			//mark order to reset
			for each(var o:OrderTemp in syncItems){
				if(int(o.src_state) == FotoknigaWeb.ORDER_STATE_PAYMENT_ACCEPTED){
					o.state=OrderState.CANCELED_LOADER_RESET;
				}
			}
			
			fillDb();
		}
		
		private function fillDb():void{
			var dbLatch:DbLatch;
			if(syncItems.length==0){
				//fill complite , run db sync pocedure
				dbLatch= new DbLatch(true);
				dbLatch.addEventListener(Event.COMPLETE, onSyncComplite);
				dbLatch.addLatch(service.syncValid());
				dbLatch.start();
				return;
			}
			//add by 50 items 
			var batch:Array=syncItems.splice(0,Math.min(50,syncItems.length));
			dbLatch= new DbLatch(true);
			dbLatch.addEventListener(Event.COMPLETE, onItemsAdd);
			dbLatch.addLatch(service.addSyncItems(new ArrayCollection(batch)));
			dbLatch.start();
		}
		private function onItemsAdd(e:Event):void{
			var dbLatch:DbLatch=e.target as DbLatch;
			if(dbLatch){
				dbLatch.removeEventListener(Event.COMPLETE,onItemsAdd);
				if(dbLatch.complite){
					fillDb();
				}else{
					dbLatch.showError();
					endSync();
					return;
				}
			}
		}
		private function onSyncComplite(e:Event):void{
			var dbLatch:DbLatch=e.target as DbLatch;
			if(dbLatch){
				dbLatch.removeEventListener(Event.COMPLETE,onSyncComplite);
				//var df:DateTimeFormatter=new DateTimeFormatter('ru_RU'); df.setDateTimePattern('HH:mm');
				var s:String;
				var target:Source;
				if(!dbLatch.complite){
					for each(target in sources){
						if(target.online){
							s='Ошибка синхронизации активных';
							target.syncState.setState(ProcessState.STATE_ERROR,s);
						}
					}
					dbLatch.showError();
				}else{
					for each(target in sources){
						if(target.online){
							target.syncState.setState(ProcessState.STATE_OK_WAITE);
						}
					}
				}
			}
			endSync();
		}


		private var arrToReset:Array=[];
		private var toResetOrder:Order;
		private var restartCount:int=0;
		
		private function onRestartLoaded(e:Event):void{
			restartCount=(restartCount+1)%10;
			//restartCount==1 - reset vs FTP_INCOMPLITE state
			var dbLatch:DbLatch=e.target as DbLatch;
			if(dbLatch){
				dbLatch.removeEventListener(Event.COMPLETE,onRestartLoaded);
				if(dbLatch.complite){
					arrToReset=dbLatch.lastDataArr;
					resetNext();
				}
			}
		}
		
		private function resetNext():void{
			if(!arrToReset || arrToReset.length==0) return;
			if(toResetOrder) return; //running
			toResetOrder=arrToReset.shift() as Order;
			if(!toResetOrder){
				resetNext();
				return;
			}
			
			var source:Source=Context.getSource(toResetOrder.source);
			if(!source){
				toResetOrder=null;
				resetNext();
				return;
			}
			//ask loader state and ..
			StateLog.log(OrderState.CANCELED_LOADER_RESET, toResetOrder.id,'','Попытка перезапуска');
			var webService:BaseWeb=WebServiceBuilder.build(source);
			webService.addEventListener(Event.COMPLETE,onGetOrderWeb);
			var wo:Order= new Order();
			wo.src_id=toResetOrder.src_id;
			webService.getLoaderOrder(wo);
			
		}
		
		private function onGetOrderWeb(e:Event):void{
			var latch:DbLatch;
			var webService:BaseWeb=e.target as BaseWeb;
			webService.removeEventListener(Event.COMPLETE,onGetOrderWeb);
			if(!toResetOrder){
				//removed from queue or some else
				//check next or stop
				toResetOrder=null;
				resetNext();
				return;
			}
			if(webService.hasError){
				StateLog.log(OrderState.ERR_WEB, toResetOrder.id,'',webService.errMesage);
				toResetOrder=null;
				resetNext();
				return;
			}
			var wo:Order=webService.getLastOrder();
			toResetOrder.canChangeRemoteState=wo.canChangeRemoteState;
			
			StateLog.log(OrderState.CANCELED_LOADER_RESET, toResetOrder.id,'','Статус на сайте "'+wo.src_state+'"');
			StateLog.log(OrderState.CANCELED_LOADER_RESET, toResetOrder.id,'','Разрешена смена статуса '+wo.canChangeRemoteState);
			
			if(restartCount==1){
				//reset vs FTP_INCOMPLITE state
				if(wo.canChangeRemoteState){
					resetSiteState();
					return;
				}
				toResetOrder=null;
				resetNext();
				return;
			}
			
			if(wo.src_state==OrderLoad.REMOTE_STATE_COPY.toString()  
				|| (wo.src_state==OrderLoad.REMOTE_STATE_DONE.toString() && wo.canChangeRemoteState)){
				//attempt to reset
				resetSiteState();
				return;
			}

			if(wo.src_state==OrderLoad.REMOTE_STATE_DONE.toString() || wo.src_state==OrderLoad.REMOTE_STATE_DEL.toString()){
				//loaded
				//check lockal files
				var path:String;
				var file:File;
				var source:Source=Context.getSource(toResetOrder.source);
				if(source) path=source.getWrkFolder();
				if(path){
					path=path+File.separator+toResetOrder.ftp_folder;
					file=new File(path);
					if(!file.exists || !file.isDirectory){
						file=null;
					}else{
						var arr:Array=file.getDirectoryListing();
						//dirty check
						// wo.files is empty if REMOTE_STATE_DEL
						if(arr.length==0) file=null;
					}
				}
				if(!file){
					//deleted lockaly
					StateLog.log(OrderState.ERR_FILE_SYSTEM,toResetOrder.id,'','Нет локальных файлов заказа (не загружены или удалены). '+path);
					if(wo.src_state==OrderLoad.REMOTE_STATE_DONE.toString()){
						//attempt to reset
						resetSiteState();
						return;
					}else{
						StateLog.log(OrderState.ERR_LOAD,toResetOrder.id,'','Файлы заказа удалены на сайте');
						toResetOrder.state=OrderState.FTP_INCOMPLITE;
						latch= new DbLatch(true);
						//latch.addEventListener(Event.COMPLETE,onOrderLoad);
						latch.addLatch(service.save(OrderLoad.fromOrder(toResetOrder),0));
						latch.start();

						toResetOrder=null;
						resetNext();
						return;
					}
				}
				StateLog.log(OrderState.CANCELED_LOADER_RESET,toResetOrder.id,'','Папка локальных файлов доступна. Восстанавливаю статус заказа Загружен');
				//restore loaded state
				toResetOrder.state=OrderState.FTP_COMPLETE;
				latch= new DbLatch(true);
				//latch.addEventListener(Event.COMPLETE,onOrderLoad);
				latch.addLatch(service.save(OrderLoad.fromOrder(toResetOrder),0));
				latch.start();
				
			}
			toResetOrder=null;
			resetNext();
		}

		private function resetSiteState():void{
			if(!toResetOrder) return;
			
			var latch:DbLatch;
			//attempt to reset
			StateLog.log(toResetOrder.state, toResetOrder.id,'','Сброс на сайте');
			//check if not locked
			if(!toResetOrder.canChangeRemoteState){
				//can't change site state
				StateLog.log(OrderState.ERR_WEB,toResetOrder.id,'','Запрет смены статуса на сайте');
				//mark canceled
				toResetOrder.state=OrderState.FTP_INCOMPLITE;
				latch= new DbLatch(true);
				//latch.addEventListener(Event.COMPLETE,onOrderLoad);
				latch.addLatch(service.save(OrderLoad.fromOrder(toResetOrder),0));
				latch.start();
				
				toResetOrder=null;
				resetNext();
				return;
			}
				
			toResetOrder.src_state=OrderLoad.REMOTE_STATE_READY.toString();
			var source:Source=Context.getSource(toResetOrder.source);
			if(!source){
				toResetOrder=null;
				resetNext();
				return;
			}
			var webService:BaseWeb=WebServiceBuilder.build(source);
			webService.addEventListener(Event.COMPLETE,onSetOrderStateWeb);
			webService.setLoaderOrderState(toResetOrder);
		}
		
		private function onSetOrderStateWeb(e:Event):void{
			var pw:BaseWeb=e.target as BaseWeb;
			pw.removeEventListener(Event.COMPLETE,onSetOrderStateWeb);
			var order:Order=pw.getLastOrder();
			if(order){
				if(pw.hasError){
					//web err or site reject state change
					//reset state
					order.state=OrderState.FTP_INCOMPLITE;
					StateLog.log(order.state, order.id,'',pw.errMesage);
					var latch:DbLatch= new DbLatch(true);
					//latch.addEventListener(Event.COMPLETE,onOrderLoad);
					latch.addLatch(service.save(OrderLoad.fromOrder(order),0));
					latch.start();
				}else{
					StateLog.log(order.state, order.id,'','Сброс выполнен');
				}
			}

			toResetOrder=null;
			resetNext();
		}

	}
}