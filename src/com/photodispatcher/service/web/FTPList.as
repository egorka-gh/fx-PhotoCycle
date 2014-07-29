package com.photodispatcher.service.web{
	import com.photodispatcher.model.mysql.entities.Source;
	import com.photodispatcher.provider.ftp.FtpTask;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	
	import pl.maliboo.ftp.events.FTPEvent;
	
	[Event(name="complete", type="flash.events.Event")]
	public class FTPList extends EventDispatcher{
		
		protected var _hasError:Boolean;
		public function get hasError():Boolean{
			return _hasError;
		}
		
		protected var _errMesage:String;
		public function get errMesage():String{
			return _errMesage;
		}

		protected var _listing:Array;
		public function get listing():Array{
			return _listing;
		}

		private var source:Source;
		
		public function FTPList(source:Source){
			super(null);
			this.source=source;
		}
		
		private var ftp:FtpTask;
		private var attempt:int;
		public function list():void{
			if(!source || !source.ftpService){
				abort('FTPList: Не верные параметры запуска');
				return;
			}
			attempt=0;
			startList();
		}
		
		private function startList():void{
			attempt++;
			ftp= new FtpTask(source);
			//listen
			ftp.addEventListener(FTPEvent.LOGGED,onLogged);
			ftp.addEventListener(FTPEvent.INVOKE_ERROR,onFault);
			ftp.addEventListener(FTPEvent.DISCONNECTED, onFault);
			ftp.connect();
		}

		private function onFault(e:FTPEvent):void{
			trace('FTPList: error: '+source.ftpService.url+'; '+(e.error?e.error.message:'timeout'));
			if(attempt<3){
				//restart
				trace('FTPList: restart, attempt: '+attempt.toString());
				stopFtp();
				startList();
				return;
			}
			abort('FTPList: Ошибка FTP: '+source.ftpService.url+'; '+(e.error?e.error.message:'timeout'));
		}

		private function abort(errMsg:String):void{
			_hasError=true;
			_errMesage=errMsg;
			stopFtp();
			dispatchEvent(new Event(Event.COMPLETE));
		}

		private function stopFtp():void{
			//trace('FTPList: stop ftp '+source.ftpService.url);
			if(!ftp) return;
			ftp.removeEventListener(FTPEvent.LOGGED,onLogged);
			ftp.removeEventListener(FTPEvent.INVOKE_ERROR,onFault);
			ftp.removeEventListener(FTPEvent.DISCONNECTED, onFault);
			ftp.removeEventListener(FTPEvent.SCAN_DIR,onList);
			ftp.close();
			ftp=null;
		}

		private function onLogged(e:FTPEvent):void{
			trace('FTPList: login complited '+source.ftpService.url);
			ftp.addEventListener(FTPEvent.SCAN_DIR,onList);
			ftp.listFolder();
		}

		private function onList(e:FTPEvent):void{
			trace('FTPList: list complited '+source.ftpService.url);
			_listing=e.listing;
			stopFtp();
			dispatchEvent(new Event(Event.COMPLETE));
		}
	}
}