package com.photodispatcher.shell{
	import com.photodispatcher.context.Context;
	
	import flash.desktop.NativeProcess;
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.NativeProcessExitEvent;
	import flash.events.ProgressEvent;
	import flash.events.TimerEvent;
	import flash.filesystem.File;
	import flash.utils.Timer;
	
	import mx.managers.CursorManager;
	
	[Event(name="error", type="flash.events.ErrorEvent")]
	public class OORuner extends EventDispatcher{
		public static const TRANSPORT_URL:int=0;
		public static const TRANSPORT_FILESYSTEM:int=1;

		
		private static const EXECUTABLE_CALC:String='scalc.exe';
		private static const EXECUTABLE_OFFICE:String='soffice.exe';
		private static const EXECUTABLE_SUBFOLDER:String='program';
		private static const PRINT_OPTION_DEFAULT_PRINTER:String='-p';
		private static const PRINT_OPTION_NAMED_PRINTER:String='-pt';
		
//"D:\Program Files\OpenOffice 4\program\soffice.exe" -p "C:\Tmp\tm.xls"
// -pt <printer> <doc>		
		private var runner:ProcessRunner;
		private var proc:NativeProcess;
		
		public var hasError:Boolean;
		public var errorResponse:String='';
		public var transport:int=TRANSPORT_URL;

		[Bindable]
		public var enabled:Boolean;
		[Bindable]
		public var busy:Boolean;
		
		private var _ooPath:String;
		public function get ooPath():String{
			return _ooPath;
		}

		private var respond:String;
		private var timer:Timer;

		
		public function OORuner(path:String=null){
			super(null);
			if(path){
				_ooPath=path;
			}else{
				_ooPath=Context.getAttribute('ooPath');
			}
			checkPrinter();
		}
		
		private function releaseErr(err:String):void{
			hasError=true;
			errorResponse=err;
			dispatchEvent(new ErrorEvent(ErrorEvent.ERROR,false,false,err));
		}


		public function check(folder:String):Boolean{
			_ooPath='';
			enabled=false;
			if (!folder){
				errorResponse='Не указан путь к папке OpenOfice';
				return false;
			}
			var oFolder:File= new File(folder);
			if(!oFolder.exists || !oFolder.isDirectory){
				errorResponse='Папка OpenOfice не найдена '+folder;
				return false;
			}
			var calc:File=oFolder.resolvePath(EXECUTABLE_CALC);
			var office:File=oFolder.resolvePath(EXECUTABLE_OFFICE);
			if(!calc.exists || !office.exists){
				//check programm subdir
				oFolder=oFolder.resolvePath(EXECUTABLE_SUBFOLDER);
				if(!oFolder.exists || !oFolder.isDirectory){
					errorResponse='Не верный путь к папке OpenOfice '+folder;
					return false;
				}
				calc=oFolder.resolvePath(EXECUTABLE_CALC);
				office=oFolder.resolvePath(EXECUTABLE_OFFICE);
				if(!calc.exists || !office.exists){
					errorResponse='Не верный путь к папке OpenOfice '+folder;
					return false;
				}
			}
			_ooPath=oFolder.nativePath;
			Context.setAttribute('ooPath',_ooPath);
			enabled=true;
			return true;
		}
		
		private function checkPrinter():Boolean{
			var res:Boolean=true;
			if(!_ooPath){
				res=false;
			}else{
				var oFolder:File= new File(_ooPath);
				if(!oFolder.exists || !oFolder.isDirectory){
					res=false;
				}else{
					var calc:File=oFolder.resolvePath(EXECUTABLE_CALC);
					var office:File=oFolder.resolvePath(EXECUTABLE_OFFICE);
					if(!calc.exists || !office.exists){
						res=false;
					}
				}
			}
			enabled=res;
			return res;
		}

		public function print(path:String, printer:String=null):void{
			if(!enabled || busy) return;
			hasError=false;
			errorResponse='';
			if(transport==TRANSPORT_URL){
				//build url
				//"D:\Program Files\OpenOffice 4\program\soffice.exe" -v "http://apache:8080/XReport/result/32ED79F1E016A64D84783F513D1FD7E1/operDayComp.xls"
				var url:String=Context.getServerRootUrl();
				if(!url){
					releaseErr('Не настроен сервер');
					return;
				}
				if(url.charAt(url.length-1)!='/' && path.charAt(0)!='/') url+='/';
				path=url+path;
			}else{
				//local file
				var file:File=new File(path);
				if(!file.exists || file.isDirectory){
					releaseErr('Не найден файл '+path);
					return;
				}
			}
			
			runner= new ProcessRunner(ooPath+File.separator+EXECUTABLE_OFFICE);
			var args:Vector.<String>=new Vector.<String>();
			args.push(PRINT_OPTION_DEFAULT_PRINTER);
			args.push('"'+path+'"');
			proc= runner.prepare(File.userDirectory.nativePath,args);
			busy=true;
			CursorManager.setBusyCursor();
			if(proc){
				proc.addEventListener(NativeProcessExitEvent.EXIT,onComplite);
				proc.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, procRespond);
				proc.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, procErr);
				try{
					runner.run();
				}catch(e:Error){
					proc=null;
					busy=false;
					CursorManager.removeBusyCursor();
					releaseErr('Ошибка запуска команды: '+e.message);
					return;
				}
			}else{
				busy=false;
				CursorManager.removeBusyCursor();
				releaseErr('Не верная папка OpenOffice');
			}
		}
	
		private function procErr(e:Event):void{
			errorResponse+=proc.standardError.readUTFBytes(proc.standardError.bytesAvailable);
			hasError=true;
		}
		private function procRespond(e:Event):void{
			errorResponse+=proc.standardOutput.readUTFBytes(proc.standardOutput.bytesAvailable);
			hasError=true;
		}
		private function onComplite(e:Event):void{
			CursorManager.removeBusyCursor();
			destroyProcess();
			if(hasError){
				releaseErr(errorResponse);
			}else{
				dispatchEvent(new Event(Event.COMPLETE));
			}
		}

		private function destroyProcess():void{
			busy=false;
			if(proc){
				proc.removeEventListener(NativeProcessExitEvent.EXIT,onComplite);
				proc.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, procRespond);
				proc.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, procErr);
				proc=null;
			}
		}

	}
}