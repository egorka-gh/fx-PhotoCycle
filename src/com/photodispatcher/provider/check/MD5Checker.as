package com.photodispatcher.provider.check{
	
	import by.blooddy.crypto.MD5;
	
	import com.photodispatcher.context.Context;
	import com.photodispatcher.model.mysql.entities.Order;
	import com.photodispatcher.model.mysql.entities.OrderFile;
	import com.photodispatcher.model.mysql.entities.OrderState;
	import com.photodispatcher.model.mysql.entities.Source;
	import com.photodispatcher.model.mysql.entities.StateLog;
	
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
	public class MD5Checker extends BaseChecker{
		
		private var currOrderFile:OrderFile;
		private var orderFolder:File;
		private var orderFiles:Array;
		private var fileBytes:ByteArray;
		
		public function MD5Checker(){
			super();
		}
		
		override public function init():void{
			// nothing to init
		}
		
		override protected function reset():void{
			if(inStream){
				inStream.removeEventListener(ProgressEvent.PROGRESS,onFsProgress);
				inStream.removeEventListener(IOErrorEvent.IO_ERROR,onFsErr);
				inStream.removeEventListener(Event.COMPLETE,onFsRead);
			}
			inStream=null;
			if(fileBytes) fileBytes.clear();
			fileBytes=null;
			orderFolder=null;
			orderFiles=null;
		}
		
		override public function check(order:Order):void{
			if(isBusy) return;
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
			orderFolder=file;
			orderFiles=currOrder.files.source.concat();
			currOrder.state=OrderState.FTP_CHECK;
			_isBusy=true;
			checkNext();
		}
		
		private function checkNext():void{
			showProgress();
			if(!orderFiles || !orderFolder) return; //stop?
			if(orderFiles.length==0){
				//complited
				hasError=currOrder.state<0;
				if(hasError) error='Часть файлов не прошла проверку MD5';
				reset();
				showProgress();
				_isBusy=false;
				dispatchEvent(new Event(Event.COMPLETE));
				return;
			}
			currOrderFile=orderFiles.shift() as OrderFile;
			if(!currOrderFile || 
					!currOrderFile.hash_remote || //no site hash 
					(currOrderFile.state>OrderState.FTP_WAITE_CHECK && currOrderFile.hash_local && currOrderFile.hash_local==currOrderFile.hash_remote)){ //hash ok
				if(currOrderFile && !currOrderFile.hash_remote){
					StateLog.log(OrderState.ERR_CHECK_MD5,currOrder.id,'','Не указан MD5 '+currOrderFile.file_name);
					trace('Не указан MD5 '+currOrderFile.file_name);
				}
				checkNext();
				return;
			}
			//if(!currOrderFile || !currOrderFile.hash_remote) return;
			currOrderFile.state=OrderState.FTP_CHECK;
			progressCaption=progressCaption+':'+ currOrderFile.file_name; 
			//load file
			fileBytes=new ByteArray();
			var file:File= orderFolder.resolvePath(currOrderFile.file_name);
			inStream= new FileStream();
			inStream.addEventListener(IOErrorEvent.IO_ERROR,onFsErr);
			inStream.addEventListener(ProgressEvent.PROGRESS,onFsProgress);
			inStream.addEventListener(Event.COMPLETE,onFsRead);
			inStream.openAsync(file,FileMode.READ);
			inStream.readBytes(fileBytes);
		}
		
		private var inStream:FileStream;
		private function onFsProgress(event:ProgressEvent):void{
			if(!inStream || !fileBytes) return;//stop
			inStream.readBytes(fileBytes, inStream.position, inStream.bytesAvailable); 
		} 
		private function onFsErr(evt:IOErrorEvent):void{
			if(!inStream || !fileBytes) return;//stop
			if(inStream){
				inStream.removeEventListener(ProgressEvent.PROGRESS,onFsProgress);
				inStream.removeEventListener(IOErrorEvent.IO_ERROR,onFsErr);
				inStream.removeEventListener(Event.COMPLETE,onFsRead);
				inStream.close();
			}
			currOrder.state=OrderState.ERR_FILE_SYSTEM;
			releaseErr(evt.text);
		}
		private function onFsRead(evt:Event):void{
			if(inStream){
				inStream.removeEventListener(ProgressEvent.PROGRESS,onFsProgress);
				inStream.removeEventListener(IOErrorEvent.IO_ERROR,onFsErr);
				inStream.removeEventListener(Event.COMPLETE,onFsRead);
				inStream.close();
			}
			if(!inStream || !fileBytes) return;//stop
			//md5 calc
			checkMD5();
		}

		private function checkMD5():void{
			if(!fileBytes || !currOrderFile) return;//stop
			fileBytes.position=0;
			var result:String = MD5.hashBytes(fileBytes);
			fileBytes.clear();
			currOrderFile.hash_local=result;
			var hasErr:Boolean;
			var str:String=currOrderFile.file_name;
			if(!result){
				hasErr=true;
				str=str+': пустой локальный MD5';
			}else if(result!=currOrderFile.hash_remote){
				hasErr=true;
				str=str+': не совпадают MD5';
			}
			if(hasErr){
				currOrder.state=OrderState.ERR_CHECK_MD5;
				currOrderFile.state=OrderState.ERR_CHECK_MD5;
				StateLog.log(OrderState.ERR_CHECK_MD5,currOrder.id,'',str);
				trace('MD5Checker md5err: '+currOrder.id+'; '+str);
			}
			trace('MD5Checker MD5 OK :'+currOrder.id+'; '+str);
			checkNext();
		}
		
		
		private function releaseErr(err:String):void{
			hasError=true;
			error=err;
			if(currOrder){
				trace('MD5Checker err: '+currOrder.id+'; '+err);
				StateLog.log(currOrder.state,currOrder.id,'',err);
			}
			reset();
			_isBusy=false;
			dispatchEvent(new ProgressEvent(ProgressEvent.PROGRESS,false,false,0,0));
			dispatchEvent(new Event(Event.COMPLETE));
		}
		
		private function showProgress():void{
			progressCaption='MD5 ';
			if(!orderFiles || !currOrder || !currOrder.files){
				dispatchEvent(new ProgressEvent(ProgressEvent.PROGRESS,false,false,0,0));
			}else{
				progressCaption=progressCaption+currOrder.id
				dispatchEvent(new ProgressEvent(ProgressEvent.PROGRESS,false,false,currOrder.files.length-orderFiles.length,currOrder.files.length));
			}
		}
	}
}