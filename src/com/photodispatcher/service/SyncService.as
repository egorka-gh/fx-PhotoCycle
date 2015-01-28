package com.photodispatcher.service{
	import com.photodispatcher.event.AsyncSQLEvent;
	import com.photodispatcher.factory.WebServiceBuilder;
	import com.photodispatcher.model.ProcessState;
	import com.photodispatcher.model.mysql.AsyncLatch;
	import com.photodispatcher.model.mysql.DbLatch;
	import com.photodispatcher.model.mysql.entities.Source;
	import com.photodispatcher.model.mysql.entities.SourceType;
	import com.photodispatcher.model.mysql.services.OrderService;
	import com.photodispatcher.service.web.BaseWeb;
	import com.photodispatcher.util.ArrayUtil;
	import com.photodispatcher.view.ModalPopUp;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.globalization.DateTimeFormatter;
	
	import mx.collections.ArrayCollection;
	import mx.collections.ArrayList;
	import mx.managers.CursorManager;
	
	import org.granite.tide.Tide;
	
	[Event(name="complete", type="flash.events.Event")]
	public class SyncService extends EventDispatcher{
		//async, interact vs sites, fetch raw orders into memory
		//serial, interact vs bd, translate to regular order obj's & persists in bd
		
		public var sources:Array;
		
		//private var waitWebSync:Array;
		//private var waitBdSync:Array;
		private var syncItems:Array;
		private var popup:ModalPopUp;
		private var isRunning:Boolean=false;
		private var service:OrderService;
		
		public function SyncService(){
			super(null);
		}
		
		public function sync():void{
			if (isRunning) return;
			if (!sources) return;

			/*
			popup= new ModalPopUp();
			popup.label='Синхронизация';
			popup.open(null);
			*/
			webSync();
		}
		
		/*
		private function webSyncOld():void{
			CursorManager.setBusyCursor();
			//waitWebSync=new Array();
			isRunning=true;
			for each (var src:Source in sources){
				if(src && src.online && src.type!=SourceType.SRC_FBOOK_MANUAL){
					var syncSvc:BaseWeb=WebServiceBuilder.build(src);
					if(syncSvc){
						src.syncState.setState(ProcessState.STATE_RUNINNG,'Синхронизация.');
						waitWebSync.push(syncSvc);
						syncSvc.addEventListener(Event.COMPLETE,handleWebComplete);
						syncSvc.sync();
					}
				}
			}
			if(waitWebSync.length==0) endSync();
		}
		*/
		
		private var webLath:DbLatch;
		private function webSync():void{
			//CursorManager.setBusyCursor();
			//waitWebSync=new Array();
			isRunning=true;
			syncItems=[];
			webLath=new DbLatch(true);
			webLath.addEventListener(Event.COMPLETE,onWebSyncComplite);
			var aLath:AsyncLatch;
			for each (var src:Source in sources){
				if(src && src.online && src.type!=SourceType.SRC_FBOOK_MANUAL){
					var syncSvc:BaseWeb=WebServiceBuilder.build(src);
					if(syncSvc){
						src.syncState.items=0;
						src.syncState.setState(ProcessState.STATE_RUNINNG,'Синхронизация.');
						//waitWebSync.push(syncSvc);
						aLath=new AsyncLatch();
						syncSvc.latch=aLath;
						webLath.join(aLath);
						aLath.start();
						syncSvc.addEventListener(Event.COMPLETE,handleWebComplete);
						syncSvc.sync();
					}
				}
			}
			//clear temp table
			if(!service) service=Tide.getInstance().getContext().byType(OrderService,true) as OrderService;
			webLath.addLatch(service.beginSync());
			//waite complite
			webLath.start();
		}

		private function endSync():void{
			//bdSyncRunning=false;
			isRunning=false;
			CursorManager.removeBusyCursor();
			dispatchEvent(new Event(Event.COMPLETE));
			if(popup && popup.isOpen){
				popup.close();
				popup=null;
			}
		}
		
		private function handleWebComplete(e:Event):void{
			var proSync:BaseWeb=e.target as BaseWeb;
			proSync.removeEventListener(Event.COMPLETE,handleWebComplete);
			/*
			//remove from waite web
			var i:int=waitWebSync.indexOf(e.target);
			if(i!=-1){
				var o:Object=waitWebSync.splice(i,1)[0];
			}
			*/
			//check if completed
			if(proSync.hasError){
				proSync.source.syncState.setState(ProcessState.STATE_ERROR,'Ошибка синхронизации ('+proSync.errMesage+')');
				//if(waitWebSync.length==0) endSync();
				//return;
			}else{
				if(proSync.orderes){
					proSync.source.syncState.items=proSync.orderes.length;
				}
				proSync.source.syncState.caption='Web ok. Элементов: '+proSync.source.syncState.items.toString();
				syncItems=syncItems.concat(proSync.orderes);
			}
			proSync.latch.release();
			/*
			if(!waitBdSync) waitBdSync=[];
			waitBdSync.push(proSync);
			startDbSync();
			*/
		}

		private function onWebSyncComplite(e:Event):void{
			webLath.removeEventListener(Event.COMPLETE,onWebSyncComplite);
			if(syncItems.length==0){
				endSync();
				return;
			}
			fillDb();
		}
		
		private function fillDb():void{
			var dbLatch:DbLatch;
			if(syncItems.length==0){
				//fill complite , run db sync pocedure
				//TODO 4 debug
				//endSync();
				dbLatch= new DbLatch(true);
				dbLatch.addEventListener(Event.COMPLETE, onSyncComplite);
				dbLatch.addLatch(service.sync());
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
				var df:DateTimeFormatter=new DateTimeFormatter('ru_RU'); df.setDateTimePattern('HH:mm');
				var s:String;
				var target:Source;
				if(dbLatch.complite){
					var sa:Array=dbLatch.lastDataArr;
					if(sa){
						for each(var result:Source in sa){
							if(result.online){
								target=ArrayUtil.searchItem('id',result.id, sources) as Source;
								if(target){
									if(result.sync_state){
										//s='Синхронизирован в '+df.format(new Date());
										s='Ok. Элементов: '+target.syncState.items.toString()+', в '+df.format(new Date());
										target.syncState.setState(ProcessState.STATE_OK_WAITE,s);
									}else{
										s='Ошибка синхронизации в '+df.format(new Date());
										target.syncState.setState(ProcessState.STATE_ERROR,s);
									}
								}
							}
						}
					}
				}else{
					for each(target in sources){
						if(target.online){
							s='Ошибка синхронизации в '+df.format(new Date());
							target.syncState.setState(ProcessState.STATE_ERROR,s);
						}
					}
					dbLatch.showError();
				}
			}
			endSync();
		}

		/*
		private function startDbSync():void{
			if(bdSyncRunning) return;
			nextDbSync();
		}

		private var currBdSync:BaseWeb; 
		private var bdSyncRunning:Boolean=false; 
		private function nextDbSync():void{
			if(!waitBdSync || waitBdSync.length==0){
				//completed or empty queue
				bdSyncRunning=false;
				if (waitWebSync.length==0){
					//complited
					endSync();
				}
				return;
			}
			bdSyncRunning=true;
			var ws:BaseWeb=waitBdSync.shift() as BaseWeb;
			currBdSync=ws;
			currBdSync.source.syncState.setState(ProcessState.STATE_RUNINNG,'Обработка данных ('+currBdSync.orderes.length.toString()+')');
			var oDAO:OrderDAO= new OrderDAO();
			oDAO.addEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT, onDbSync);
			oDAO.sync(currBdSync.source,currBdSync.orderes);
		}
		*/
		/*
		private function onDbSync(e:AsyncSQLEvent):void{
			var oDAO:OrderDAO=e.target as OrderDAO;
			var df:DateTimeFormatter=new DateTimeFormatter('ru_RU'); df.setDateTimePattern('HH:mm');
			var s:String;
			
			if(oDAO) oDAO.removeEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT, onDbSync);
			if(e.result==AsyncSQLEvent.RESULT_COMLETED){
				s='Синхронизирован в '+df.format(new Date())+'. Обработанно '+currBdSync.orderes.length.toString();
				currBdSync.source.syncState.setState(ProcessState.STATE_OK_WAITE,s);
			}else{
				s='Ошибка синхронизации в '+df.format(new Date())+'. '+e.error;
				currBdSync.source.syncState.setState(ProcessState.STATE_OK_WAITE,s);
			}
			nextDbSync();
		}
		*/
		
	}
}