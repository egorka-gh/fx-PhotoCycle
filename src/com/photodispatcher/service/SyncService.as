package com.photodispatcher.service{
	import com.photodispatcher.event.AsyncSQLEvent;
	import com.photodispatcher.factory.WebServiceBuilder;
	import com.photodispatcher.model.ProcessState;
	import com.photodispatcher.model.Source;
	import com.photodispatcher.model.dao.OrderDAO;
	import com.photodispatcher.service.web.BaseWeb;
	import com.photodispatcher.view.ModalPopUp;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.globalization.DateTimeFormatter;
	
	import mx.collections.ArrayList;
	import mx.managers.CursorManager;
	
	[Event(name="complete", type="flash.events.Event")]
	public class SyncService extends EventDispatcher{
		//async, interact vs sites, fetch raw orders into memory
		//serial, interact vs bd, translate to regular order obj's & persists in bd
		
		public var sources:Array;
		
		private var waitWebSync:Array;
		private var waitBdSync:Array;
		private var popup:ModalPopUp;
		private var isRunning:Boolean=false;
		
		public function SyncService(){
			super(null);
		}
		
		public function sync():void{
			if (isRunning) return;
			if (!sources) return;

			popup= new ModalPopUp();
			popup.label='Синхронизация';
			popup.open(null);
			webSync();
		}
		
		private function webSync():void{
			CursorManager.setBusyCursor();
			waitWebSync=new Array();
			isRunning=true;
			for each (var src:Source in sources){
				if(src && src.online){
					var syncSvc:BaseWeb=WebServiceBuilder.build(src);
					if(syncSvc){
						src.syncState.setState(ProcessState.STATE_RUNINNG,'Синхронизация.');
						waitWebSync.push(syncSvc);
						syncSvc.addEventListener(Event.COMPLETE,handleWebComplete);
						syncSvc.sync();
					}
					/*
					switch (src.type_id){
						case 1: //profoto
							src.syncState.setState(ProcessState.STATE_RUNINNG,'Синхронизация.');
							var proSync:ProfotoWeb=new ProfotoWeb(src);
							waitWebSync.push(proSync);
							proSync.addEventListener(Event.COMPLETE,handleWebComplete);
							proSync.sync();
							break;
					}
					*/
				}
			}
			if(waitWebSync.length==0) endSync();
		}
		
		private function endSync():void{
			bdSyncRunning=false;
			isRunning=false;
			CursorManager.removeBusyCursor();
			dispatchEvent(new Event(Event.COMPLETE));
			if(popup && popup.isOpen){
				popup.close();
				popup=null;
			}
		}
		
		private function handleWebComplete(e:Event):void{
			//var proSync:ProfotoWeb=e.target as ProfotoWeb;
			var proSync:BaseWeb=e.target as BaseWeb;
			proSync.removeEventListener(Event.COMPLETE,handleWebComplete);
			//remove from waite web
			var i:int=waitWebSync.indexOf(e.target);
			if(i!=-1){
				var o:Object=waitWebSync.splice(i,1)[0];
			}
			//check if completed
			if(proSync.hasError){
				proSync.source.syncState.setState(ProcessState.STATE_ERROR,'Ошибка синхронизации ('+proSync.errMesage+')');
				if(waitWebSync.length==0) endSync();
				return;
			}
			if(!waitBdSync) waitBdSync=[];
			waitBdSync.push(proSync);
			startDbSync();
		}

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
		
	}
}