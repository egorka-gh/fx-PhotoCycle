package com.photodispatcher.provider.check{
	
	import by.blooddy.crypto.MD5;
	
	import com.photodispatcher.context.Context;
	import com.photodispatcher.event.IMRunerEvent;
	import com.photodispatcher.model.mysql.entities.Order;
	import com.photodispatcher.model.mysql.entities.OrderFile;
	import com.photodispatcher.model.mysql.entities.OrderState;
	import com.photodispatcher.model.mysql.entities.Source;
	import com.photodispatcher.model.mysql.entities.StateLog;
	import com.photodispatcher.shell.IMCommand;
	import com.photodispatcher.shell.IMRuner;
	import com.photodispatcher.shell.IMSequenceRuner;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.utils.ByteArray;
	
	[Event(name="complete", type="flash.events.Event")]
	[Event(name="progress", type="flash.events.ProgressEvent")]
	public class IMChecker extends BaseChecker{
		
		private var imPath:String;
		private var maxThreads:int;
		private var orderFolder:String;
		private var commands:Array;
		private var runner:IMSequenceRuner;
		
		public function IMChecker(){
			super();
		}
		
		override public function init():void{
			imPath=Context.getAttribute('imPath');
			maxThreads=Context.getAttribute('imThreads');
			maxThreads=Math.max(1,maxThreads);
		}
		
		override public function stop():void{
			super.stop();
			IMRuner.stopAll();
		}
		
		
		
		override protected function reset():void{
			if(runner){
				runner.removeEventListener(ProgressEvent.PROGRESS, onProgress); 
				runner.removeEventListener(IMRunerEvent.IM_COMPLETED, onComplete); 
			}
			runner=null;
			orderFolder=null;
			commands=[];
			//TODO implement
		}
		
		override public function check(order:Order):void{
			if(isBusy) return;
			if(!imPath){
				progressCaption='IM не настроен ';
				return;
			}

			progressCaption='IM';
			hasError=false;
			error='';
			if(!order) return;
			reset();
			currOrder=order;
			if(!currOrder.files || currOrder.files.length==0){
				currOrder.state=OrderState.ERR_CHECK;
				releaseErr('Пустой список файлов');
				return;
			}
			//get order path
			var path:String;
			var file:File;
			var source:Source=Context.getSource(currOrder.source);
			if(source) path=source.getWrkFolder();
			if(path){
				path=path+File.separator+order.ftp_folder;
				file=new File(path);
				if(!file.exists || !file.isDirectory) file=null;
			}
			if(!file){
				currOrder.state=OrderState.ERR_FILE_SYSTEM;
				releaseErr('Папка заказа не доступна '+path);
				return;
			}
			orderFolder=file.nativePath;
			currOrder.state=OrderState.FTP_CHECK;
			createCommands();
			if(commands.length==0){
				//complited
				_isBusy=false;
				dispatchEvent(new Event(Event.COMPLETE));
				return;
			}
			_isBusy=true;
			progressCaption='IM '+currOrder.id;
			trace('IMChecker start: '+currOrder.id);
			runner= new IMSequenceRuner(null,true);
			runner.addEventListener(ProgressEvent.PROGRESS, onProgress); 
			runner.addEventListener(IMRunerEvent.IM_COMPLETED, onComplete); 
			runner.start(commands,maxThreads);
		}

		private function createCommands():void{
			var of:OrderFile;
			var command:IMCommand;
			for each(of in currOrder.files){
				if(of && of.state<OrderState.FTP_COMPLETE){
					command=new IMCommand(IMCommand.IM_CMD_CONVERT);
					command.folder=orderFolder;
					command.sourceObject=of;
					command.add(of.file_name);
					command.add('null:');
					commands.push(command);
				}
			}
		}

		private function onProgress(e:ProgressEvent):void{
			dispatchEvent(e.clone());
		}
		private function onComplete(e:IMRunerEvent):void{
			if(runner){
				runner.removeEventListener(ProgressEvent.PROGRESS, onProgress); 
				runner.removeEventListener(IMRunerEvent.IM_COMPLETED, onComplete);
			}
			if(!currOrder || !isBusy) return;//stop

			var of:OrderFile;
			var command:IMCommand;

			//mark files as complited
			for each(of in currOrder.files){
				if(of) of.state=OrderState.FTP_COMPLETE;
			}
			if(!e.hasError){
				//complite
				currOrder.state=OrderState.FTP_COMPLETE;
				currOrder.saveState();
				_isBusy=false;
				dispatchEvent(new Event(Event.COMPLETE));
			}else{
				hasError=true;
				error='Ошибка проверки IM:';
				currOrder.state=OrderState.FTP_INCOMPLITE;
				currOrder.saveState();
				//mark files
				for each(command in commands){
					if(command){
						if(command.state==IMCommand.STATE_ERR){
							of=command.sourceObject as OrderFile;
							if(of){
								of.state=OrderState.ERR_CHECK_IM;
								StateLog.log(OrderState.ERR_CHECK_IM,currOrder.id,'',of.file_name+' err: '+command.error);
								//trace('IMChecker err: '+currOrder.id+'; '+of.file_name+' err: ' command.error);
								error=error+' '+of.file_name+';';
							}
						}
					}
				}
				trace('IMChecker err: '+currOrder.id+'; '+error);
				_isBusy=false;
				dispatchEvent(new Event(Event.COMPLETE));
			}
		}
		
		
		private function releaseErr(err:String):void{
			hasError=true;
			error=err;
			if(currOrder){
				trace('IMChecker err: '+currOrder.id+'; '+err);
				StateLog.log(currOrder.state,currOrder.id,'',err);
			}
			reset();
			_isBusy=false;
			dispatchEvent(new ProgressEvent(ProgressEvent.PROGRESS,false,false,0,0));
			dispatchEvent(new Event(Event.COMPLETE));
		}
		
	}
}