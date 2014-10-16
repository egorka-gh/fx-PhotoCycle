package  com.photodispatcher.shell{
	
	import com.photodispatcher.context.Context;
	import com.photodispatcher.event.IMRunerEvent;
	
	import flash.desktop.NativeProcess;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.NativeProcessExitEvent;
	import flash.events.ProgressEvent;
	import flash.events.TimerEvent;
	import flash.filesystem.File;
	import flash.sampler.NewObjectSample;
	import flash.utils.Dictionary;
	import flash.utils.Timer;
	import flash.utils.getTimer;
	
	[Event(name="imCompleted",     type="com.photodispatcher.event.IMRunerEvent")]
	public class IMRuner extends EventDispatcher{
		[Bindable]
		public static var isRunning:Boolean=false;
		
		private static var instanceMap:Dictionary=new Dictionary();
		
		public static function registerInstance(ir:IMRuner):void{
			if(ir){
				instanceMap[ir]=ir;
				isRunning=true;
			}
		}

		public static function unregisterInstance(ir:IMRuner):void{
			if(ir){
				var running:Boolean=false;
				delete instanceMap[ir];
				for each (var o:Object in instanceMap){
					if(o){
						running=true;
						break;
					}
				}
				isRunning=running;
			}
		}

		public static function stopAll():void{
			var ir:IMRuner;
			for each (ir in instanceMap){
				if(ir) ir.stop();
			}
			instanceMap=new Dictionary();
			isRunning=false;
		}

		
		private static const PING_TIMEOUT:int=2000;
		private static const PING_EXECUTABLE:String='convert.exe';

		private var workFolder:String;
		//private var outFolder:String;
		private var runner:ProcessRunner;
		private var proc:NativeProcess;

		private var _hasError:Boolean;
		private function get hasError():Boolean{
			return _hasError;
		}

		private function set hasError(value:Boolean):void{
			_hasError = value;
			if(_hasError && command) command.state=IMCommand.STATE_ERR; 
		}

		private var errorResponse:String='';
		
		private var _command:IMCommand;
		public function get command():IMCommand{
			return _command;
		}

		private var imPath:String;
		
		private var respond:String;
		private var timer:Timer;

		public var targetObject:Object;
		
		public function IMRuner(imPath:String, workFolder:String){
			super(null);
			this.workFolder=workFolder;
			this.imPath=imPath;
		}
		
		public function start(command:IMCommand, register:Boolean=true):void{
			_command=command;
			if (proc){
				hasError=true;
				errorResponse='Не завершено выполнение предыдущей команды. ';
				dispatchEvent(new IMRunerEvent(IMRunerEvent.IM_COMPLETED,command,true,errorResponse));
				return;
			}
			if(!workFolder){
				hasError=true;
				errorResponse='Не задана рабочая папка';
				dispatchEvent(new IMRunerEvent(IMRunerEvent.IM_COMPLETED,command,true,errorResponse));
				return;
			}
			if(!command){
				hasError=true;
				errorResponse='Не указана команда запуска';
				dispatchEvent(new IMRunerEvent(IMRunerEvent.IM_COMPLETED,command,true,errorResponse));
				return;
			}
			//imPath=Context.getAttribute('imPath');
			if(!imPath){
				hasError=true;
				errorResponse='Не указана папка ImageMagick';
				dispatchEvent(new IMRunerEvent(IMRunerEvent.IM_COMPLETED,command,true,errorResponse));
				return;
			}
			runCommand(register);
		}
		
		public function stop():void{
			if(proc){
				proc.removeEventListener(NativeProcessExitEvent.EXIT,complite);
				proc.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, procRespond);
				proc.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, procErr);
				if(proc.running){
					hasError=true;
					errorResponse='Terminated';
					proc.exit(true);
				}
				proc=null;
			}
		}
		
		private function runCommand(register:Boolean):void{
			hasError=false;
			command.state=IMCommand.STATE_STARTED;
			trace('IMRuner run cmd: '+workFolder+' '+command.toString());
			runner= new ProcessRunner(imPath+File.separator+command.executable);
			var args:Vector.<String>=new Vector.<String>();
			var prm:String
			for each(prm in command.parameters){
				args.push(prm);
			}
			proc= runner.prepare(workFolder,args);
			if(proc){
				proc.addEventListener(NativeProcessExitEvent.EXIT,complite);
				proc.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, procRespond);
				proc.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, procErr);
				try{
					command.profileStart=getTimer();
					runner.run();
				}catch(e:Error){
					proc=null;
					hasError=true;
					errorResponse='Ошибка запуска команды: '+e.message;
					dispatchEvent(new IMRunerEvent(IMRunerEvent.IM_COMPLETED,command,true,errorResponse));
					return;
				}
				if(register) IMRuner.registerInstance(this);
			}else{
				hasError=true;
				errorResponse='Не верная папка ImageMagick или не верная рабочая папка';
				dispatchEvent(new IMRunerEvent(IMRunerEvent.IM_COMPLETED,command,true,errorResponse));
			}
		}
		
		private function procErr(e:Event):void{
			//proc.removeEventListener(NativeProcessExitEvent.EXIT,complite);
			//proc.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, procRespond);
			//proc.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, procErr);
			errorResponse+=proc.standardError.readUTFBytes(proc.standardError.bytesAvailable);
			//proc=null;
			hasError=true;
			//dispatchEvent(new IMRunerEvent(IMRunerEvent.IM_COMPLETED,command,true,errorResponse));
		}
		private function procRespond(e:Event):void{
			//proc.removeEventListener(NativeProcessExitEvent.EXIT,complite);
			//proc.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, procRespond);
			//proc.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, procErr);
			errorResponse+=proc.standardOutput.readUTFBytes(proc.standardOutput.bytesAvailable);
			//proc=null;
			hasError=true;
			//dispatchEvent(new IMRunerEvent(IMRunerEvent.IM_COMPLETED,command,true,errorResponse));
		}
		private function complite(e:Event):void{
			IMRuner.unregisterInstance(this);
			proc.removeEventListener(NativeProcessExitEvent.EXIT,complite);
			proc.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, procRespond);
			proc.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, procErr);
			proc=null;
			command.profileEnd=getTimer();
			//Duration in s
			command.profileDuration=(command.profileEnd-command.profileStart)/1000;
			if(!hasError) command.state=IMCommand.STATE_COMPLITE;
			dispatchEvent(new IMRunerEvent(IMRunerEvent.IM_COMPLETED,command,hasError,errorResponse));
		}
		
		public function get currentCommand():String{
			if(command){
				return command.toString();
			}
			return '';
		}
		
		public function getIMPath():String{
			return imPath;
		}
		
		public function ping(imFolder:String):void{
			if (proc) return;
			imPath=imFolder;
			if (!imFolder){
				errorResponse='Не указан путь к папке ImageMagick';
				hasError=true;
				dispatchEvent(new IMRunerEvent(IMRunerEvent.IM_COMPLETED,null,true,errorResponse));
				return;
			}
			hasError=false;
			runner = new ProcessRunner('');
			timer = new Timer(PING_TIMEOUT);
			timer.addEventListener(TimerEvent.TIMER,onTimeout);

			respond='';
			imFolder=imFolder + File.separator+PING_EXECUTABLE;
			runner.executable = imFolder;
			var args:Vector.<String>=new Vector.<String>();
			args.push('-version');
			proc= runner.prepare(workFolder,args);
			if(proc){
				proc.addEventListener(NativeProcessExitEvent.EXIT,complitePing);
				proc.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, procRespondPing);
				proc.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, procErrPing);
				//add time out
				timer.start();
				try{
					runner.run();
				}catch(e:Error){
					errorResponse='Ошибка запуска ImageMagick: '+e.message;
					hasError=true;
					dispatchEvent(new IMRunerEvent(IMRunerEvent.IM_COMPLETED,null,true,errorResponse));
				}
			}else{
				errorResponse='Не верный путь к ImageMagick или рабочая папка приложения';
				hasError=true;
				dispatchEvent(new IMRunerEvent(IMRunerEvent.IM_COMPLETED,null,true,errorResponse));
			}
		}

		private function procErrPing(e:Event):void{
			errorResponse='Ошибка приложения ImageMagick';
			hasError=true;
		}
		private function procRespondPing(e:Event):void{
			if(proc) respond= respond+proc.standardOutput.readUTFBytes(proc.standardOutput.bytesAvailable) +'\n';
		}
		private function complitePing(e:Event):void{
			if(timer.running) timer.reset();
			if(proc){
				proc.removeEventListener(NativeProcessExitEvent.EXIT,complite);
				proc.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, procRespond);
				proc.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, procErr);
				proc=null;
			}
			if(hasError || errorResponse){
				dispatchEvent(new IMRunerEvent(IMRunerEvent.IM_COMPLETED,null,true,errorResponse));
			}else{
				//GraphicsMagick 1.3.12 2010-03-08 Q16 http://www.GraphicsMagick.org/
				if (respond.toLowerCase().indexOf('imagemagick')!=-1){
					respond=respond.split('\n',1)[0];
					dispatchEvent(new IMRunerEvent(IMRunerEvent.IM_COMPLETED,null,false,respond));
				}else{
					errorResponse='Запущено не верное приложение';
					hasError=true;
					dispatchEvent(new IMRunerEvent(IMRunerEvent.IM_COMPLETED,null,true,errorResponse));
				}
			}
		}
		
		private function onTimeout(event:TimerEvent):void{
			if(proc){
				proc.removeEventListener(NativeProcessExitEvent.EXIT,complite);
				proc.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, procRespond);
				proc.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, procErr);
				proc=null;
				errorResponse='Запущено не верное приложение';
				hasError=true;
				dispatchEvent(new IMRunerEvent(IMRunerEvent.IM_COMPLETED,null,true,errorResponse));
			}
		}

	}
}