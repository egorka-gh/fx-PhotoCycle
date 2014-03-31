package com.photodispatcher.shell{
	import flash.desktop.NativeProcess;
	import flash.desktop.NativeProcessStartupInfo;
	import flash.events.NativeProcessExitEvent;
	import flash.filesystem.File;
	import flash.system.Capabilities;

	public class ProcessRunner{
		//TODO class still dummy
		private var _executable:String;
		private var _startupInfo:NativeProcessStartupInfo;
		private var _process:NativeProcess;
		
		public function ProcessRunner(executable:String){
			_executable=executable;
		}

		public function prepare(workingDirectory:String, arguments:Vector.<String>):NativeProcess{
			_startupInfo=null;
			_process=null;
			if(!_executable){
				//TODO exception/alert 
				return null;
			}
			if(!NativeProcess.isSupported){
				//TODO exception/alert 
				return null;
			}
			/*check os?
			if (Capabilities.os.toLowerCase().indexOf('win')=-1){
			}
			*/
			//TODO check if exists workingDirectory & _executable 
			var file:File= new File(_executable);
			if(!file.exists || file.isDirectory){
				return null;
			}
			_startupInfo= new NativeProcessStartupInfo();
			_startupInfo.executable=file;
			if(workingDirectory){
				var wDir:File= new File(workingDirectory);
				if(!wDir.exists || !wDir.isDirectory){
					return null;
				}
				//wDir.nativePath=workingDirectory;
				_startupInfo.workingDirectory=wDir;
			}
			if(arguments){
				_startupInfo.arguments=arguments;
			}
			_process = new NativeProcess();
			//TODO add listeners
			
			return _process;
		}

		public function run():void{
			if (_process && _startupInfo){
				_process.start(_startupInfo);
			}
		}
		
		public function stop(force:Boolean=false):void{
			if (_process && _process.running){
				_process.exit(force);
				_process=null;
			}
		}

		public function get process():NativeProcess{
			return _process;
		}
		
		public function get isRunning():Boolean{
			return _process && _process.running;
		}
		
		public function get executable():String{
			return _executable;
		}
		public function set executable(value:String):void{
			_executable = value;
		}

	}
}