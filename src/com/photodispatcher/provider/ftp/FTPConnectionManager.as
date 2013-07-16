package com.photodispatcher.provider.ftp{
	import com.photodispatcher.event.ConnectionsProgressEvent;
	import com.photodispatcher.event.ImageProviderEvent;
	import com.photodispatcher.model.Source;
	import com.photodispatcher.model.SourceService;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	
	import pl.maliboo.ftp.events.FTPEvent;
	
	[Event(name="connect", type="flash.events.Event")]
	[Event(name="flowError", type="com.photodispatcher.event.ImageProviderEvent")]
	[Event(name="connectionsProgress", type="com.photodispatcher.event.ConnectionsProgressEvent")]
	public class FTPConnectionManager extends EventDispatcher{

		private static const DEBUG_TRACE:Boolean=false;
		private static const CNN_ERR_LIMIT:int=3;

		
		private var inuse:Array=[];
		private var free:Array=[];
		private var pending:Array=[];
		private var source:Source;
		private var limit:int=0;
		private var ftpService:SourceService;
		private var waiteConnect:Boolean=false;

		private var err_counter:int=0;
		
		public function FTPConnectionManager(source:Source){
			super(null); 
			this.source=source;
			if(source && source.ftpService){
				ftpService=source.ftpService;
				limit=ftpService.connections;
			}
		}
		
		/**
		 *ask 4 connection 
		 * initiates cnn & login or checks cnn pool
		 * dispatches Event.Connect when has connection
		 * use getConnection on Connect event
		 */		
		public function connect():void{
			if(free.length>0){
				if(DEBUG_TRACE) trace('FTPConnectionManager has free connection '+ftpService.url);
				dispatchEvent(new Event(Event.CONNECT));
				return;
			}
			if(waiteConnect) return;
			if(!source || !ftpService){
				flowError('Не заданы параметры подключения (FTPConnectionManager)');
				return;
			}
			if(canConnect()){
				waiteConnect=true;
				var cnn:FtpTask=new FtpTask(source);
				listenLogin(cnn);
				pending.push(cnn);
				if(DEBUG_TRACE) trace('FTPConnectionManager attempt to connect '+ftpService.url);
				cnn.connect();
			}
			reportConnections();
		}

		public function getConnection():FtpTask{
			var cnn:FtpTask;
			if(free.length>0){
				do{
					cnn=free.shift() as FtpTask;
					listenConnection(cnn,false);
				} while(free.length>0 && (!cnn || !cnn.isConnected));
				if(cnn && cnn.isConnected){
					inuse.push(cnn);
					if(DEBUG_TRACE) trace('FTPConnectionManager getConnection return cnn '+ftpService.url);
					reportConnections();
					return cnn;
				}else{
					connect();
					return null;
				}
			}
			return null;
		}

		/**
		 *save connection in pull & dispatch connected 
		 */		
		/*
		public function reuse(cnn:FtpTask):void{
			if(!cnn) return;
			if(DEBUG_TRACE) trace('FTPConnectionManager reuse '+ftpService.url);
			var idx:int=inuse.indexOf(cnn);
			if(idx!=-1) inuse.splice(idx,1);
			if(cnn.isConnected){
				free.push(cnn);
				dispatchEvent(new Event(Event.CONNECT));
			}else{
				destroyConnection(cnn);
				connect();
			}
			reportConnections();
		}
		*/

		/**
		 *save connection in pull 
		 */		
		public function release(cnn:FtpTask):void{
			if(!cnn) return;
			if(DEBUG_TRACE) trace('FTPConnectionManager release '+ftpService.url);
			var idx:int=inuse.indexOf(cnn);
			if(idx!=-1) inuse.splice(idx,1);
			if(cnn.isConnected && canConnect()){
				listenConnection(cnn);
				free.push(cnn);
			}
			reportConnections();
		}

		/**
		 *some problem vs connection
		 * close it and open new 
		 */		
		public function reconnect(cnn:FtpTask):void{
			if(!cnn) return;
			if(DEBUG_TRACE) trace('FTPConnectionManager reconnect '+ftpService.url);
			var idx:int=inuse.indexOf(cnn);
			if(idx!=-1) inuse.splice(idx,1);
			reportConnections();
			//pending.push(cnn); TODO some bug wile wait disconnect
			//destroyConnection(cnn);
			
			cnn.close();
			connect();
		}
		
		public function stopDownload(orderId:String):Array{
			if(!orderId) return [];
			
			var c:FtpTask;
			var arr:Array=[];
			for each (c in inuse){
				if(c && c.orderId==orderId){
					arr.push(c);
				}
			}
			if(DEBUG_TRACE) trace('FTPConnectionManager stopDownload:'+orderId+' connections:'+arr.length.toString());
			for each (c in arr){
				if(c){
					var idx:int=inuse.indexOf(c);
					if(idx!=-1) inuse.splice(idx,1);
					listenConnection(c);
					pending.push(c);
					c.abort();
				}
			}
			reportConnections();
			return arr;
		}
		
		
		private function canConnect():Boolean{
			if(!source || !ftpService) return false;
			var count:int=inuse.length+free.length;
			return count < limit;
		}
		
		private function reportConnections():void{
			dispatchEvent( new ConnectionsProgressEvent(inuse.length,limit,free.length,pending.length));
		}
		
		private function flowError(errMsg:String):void{
			dispatchEvent(new ImageProviderEvent(ImageProviderEvent.FLOW_ERROR_EVENT,null,errMsg));
		}

		private function listenLogin(cnn:FtpTask, listen:Boolean=true):void{
			if(!cnn) return;
			if(listen){
				cnn.addEventListener(FTPEvent.LOGGED,onLogged);
				cnn.addEventListener(FTPEvent.INVOKE_ERROR,onLoggFault);
				cnn.addEventListener(FTPEvent.DISCONNECTED, onLoggFault);
			}else{
				cnn.removeEventListener(FTPEvent.LOGGED,onLogged);
				cnn.removeEventListener(FTPEvent.INVOKE_ERROR,onLoggFault);
				cnn.removeEventListener(FTPEvent.DISCONNECTED, onLoggFault);
			}
		}
		
		private function onLogged(e:FTPEvent):void{
			waiteConnect=false;
			var cnn:FtpTask=e.target as FtpTask;
			if(!cnn) return;
			trace('FTPConnectionManager log complited '+ftpService.url);
			err_counter=0;
			listenLogin(cnn,false);

			var idx:int=pending.indexOf(cnn);
			if(idx!=-1) pending.splice(idx,1);
			listenConnection(cnn);
			free.push(cnn);
			reportConnections();
			dispatchEvent(new Event(Event.CONNECT));
		}
		
		private function listenConnection(cnn:FtpTask, listen:Boolean=true):void{
			if(!cnn) return;
			if(listen){
				cnn.addEventListener(FTPEvent.PAUSE, onPause);
				cnn.addEventListener(FTPEvent.DISCONNECTED, onDisconnected);
				cnn.addEventListener(FTPEvent.INVOKE_ERROR, onInvokeError);
			}else{
				cnn.removeEventListener(FTPEvent.PAUSE, onPause);
				cnn.removeEventListener(FTPEvent.DISCONNECTED, onDisconnected);
				cnn.removeEventListener(FTPEvent.INVOKE_ERROR, onInvokeError);
			}
		}

		private function onDisconnected(e:FTPEvent):void{
			var cnn:FtpTask=e.target as FtpTask;
			if(!cnn) return;
			if(DEBUG_TRACE) trace('FTPConnectionManager get disconnected');
			listenConnection(cnn,false);
			//remove from free
			var idx:int=free.indexOf(cnn);
			if(idx!=-1){
				free.splice(idx,1);
			}
			//remove from pending
			idx=pending.indexOf(cnn);
			if(idx!=-1){
				pending.splice(idx,1);
			}
			reportConnections();
		}

		private function onPause(e:FTPEvent):void{
			var cnn:FtpTask=e.target as FtpTask;
			if(!cnn) return;
			if(DEBUG_TRACE) trace('FTPConnectionManager get pause (aborted)');
			//remove from pending
			var idx:int=pending.indexOf(cnn);
			if(idx!=-1){
				pending.splice(idx,1);
				//add to free
				if(cnn.isConnected && canConnect()){
					free.push(cnn);
				}else{
					listenConnection(cnn,false);
				}
				reportConnections();
			}
		}

		private function onInvokeError(e:FTPEvent):void{
			var cnn:FtpTask=e.target as FtpTask;
			if(!cnn) return;
			//check if in pending
			var idx:int=pending.indexOf(cnn);
			if(idx!=-1){
				listenConnection(cnn,false);
				pending.splice(idx,1);
				cnn.close();
			}
		}
		
		private function onLoggFault(e:FTPEvent):void{
			waiteConnect=false;
			var cnn:FtpTask=e.target as FtpTask;
			if(!cnn) return;
			trace('FTPConnectionManager login fault '+ftpService.url);
			err_counter++;
			listenLogin(cnn,false);

			var idx:int=pending.indexOf(cnn);
			if(idx!=-1) pending.splice(idx,1);
			flowError('Ошибка подключения ftp: '+ftpService.url+'; '+(e.error?e.error.message:'timeout'));
			cnn.close();
			if(err_counter<CNN_ERR_LIMIT){
				//TODO timeout?
				connect();
			}else{
				reportConnections();
			}
		}
		
	}
}