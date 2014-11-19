package com.photodispatcher.shell{
	import com.photodispatcher.context.Context;
	
	import flash.desktop.NativeProcess;
	import flash.events.ErrorEvent;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.TimerEvent;
	import flash.filesystem.File;
	import flash.utils.Timer;
	
	[Event(name="error", type="flash.events.ErrorEvent")]
	public class OORuner extends EventDispatcher{
		private static const EXECUTABLE_CALC:String='scalc.exe';
		private static const EXECUTABLE_OFFICE:String='soffice.exe';
		private static const EXECUTABLE_SUBFOLDER:String='program';
//"D:\Program Files\OpenOffice 4\program\soffice.exe" -p "C:\Tmp\tm.xls"
// -pt <printer> <doc>		
		private var runner:ProcessRunner;
		private var proc:NativeProcess;
		
		public var hasError:Boolean;

		public var errorResponse:String='';

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
		}
		
		private function releaseErr(err:String){
			hasError=true;
			errorResponse=err;
			dispatchEvent(new ErrorEvent(ErrorEvent.ERROR,false,false,err));
		}
		
		public function check(folder:String):Boolean{
			_ooPath='';
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
			return true;
		}
		

	}
}