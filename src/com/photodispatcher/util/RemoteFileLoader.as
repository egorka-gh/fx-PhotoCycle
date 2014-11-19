package com.photodispatcher.util{
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.net.URLLoader;
	import flash.net.URLLoaderDataFormat;
	import flash.net.URLRequest;
	import flash.utils.ByteArray;
	
	[Event(name="error", type="flash.events.ErrorEvent")]
	[Event(name="complete", type="flash.events.Event")]
	public class RemoteFileLoader extends EventDispatcher{
		
		public var url:String;
		public var baseUrl:String;
		public var targetFileName:String;
		public var targetFolder:String;

		public var targetFile:File;
		
		private var loader : URLLoader;
		private var content:ByteArray;
		
		
		public function RemoteFileLoader(url:String, targetFileName:String, baseUrl:String=null, targetFolder:String=null){
			super(null);
			this.url=url;
			this.baseUrl=baseUrl;
			this.targetFileName=targetFileName;
			this.targetFolder=targetFolder;
		}
		
		public function load():void{
			if(!url){
				dispatchEvent(new ErrorEvent(ErrorEvent.ERROR, true, false, 'Не задан url'));
				return;
			}
			if(!targetFileName){
				dispatchEvent(new ErrorEvent(ErrorEvent.ERROR, true, false, 'Не задано имя файла'));
				return;
			}
			loader = new URLLoader();
			loader.dataFormat = URLLoaderDataFormat.BINARY;
			//loader.addEventListener(ProgressEvent.PROGRESS, onProgressHandler, false, 0, true);
			loader.addEventListener(Event.COMPLETE, onCompleteHandler, false, 0, true);
			loader.addEventListener(IOErrorEvent.IO_ERROR, onErrorHandler, false, 0, true);
			//loader.addEventListener(HTTPStatusEvent.HTTP_STATUS, super.onHttpStatusHandler, false, 0, true);
			//loader.addEventListener(Event.OPEN, onStartedHandler, false, 0, true);
			loader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityErrorHandler, false, 0, true);
			var fullUrl:String=url;
			if(baseUrl){
				if(baseUrl.charAt(baseUrl.length-1)!='/' && url.charAt(0)!='/') baseUrl+='/';
				fullUrl=baseUrl+url;
			}
			try{
				// TODO: test for security error thown.
				loader.load(new URLRequest(fullUrl));
			}catch( e : SecurityError){
				onSecurityErrorHandler(_createErrorEvent(e));
				
			}
		}
		
		private function cleanListeners() : void {
			if(loader){
				//loader.removeEventListener(ProgressEvent.PROGRESS, onProgressHandler, false);
				loader.removeEventListener(Event.COMPLETE, onCompleteHandler, false);
				loader.removeEventListener(IOErrorEvent.IO_ERROR, onErrorHandler, false);
				//loader.removeEventListener(BulkLoader.OPEN, onStartedHandler, false);
				//loader.removeEventListener(HTTPStatusEvent.HTTP_STATUS, super.onHttpStatusHandler, false);
				loader.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityErrorHandler, false);
			}
		}
		
		private function onSecurityErrorHandler(e : ErrorEvent) : void{
			e.stopPropagation();
			dispatchEvent(new ErrorEvent(ErrorEvent.ERROR, true, false, e.text));
		}
		
		private function onErrorHandler(evt : ErrorEvent) : void{
			evt.stopPropagation();
			dispatchEvent(new ErrorEvent(ErrorEvent.ERROR, true, false, evt.text));
		}
		
		private function _createErrorEvent(e : Error) : ErrorEvent{
			return new ErrorEvent(ErrorEvent.ERROR, false, false, e.message);
		}
		
		
		public function stop() : void{
			try{
				if(loader) loader.close();
			}catch(e : Error){}
		}
		
		
		public function destroy() : void{
			stop();
			cleanListeners();
			content = null;
			loader = null;
		}   

		private function onCompleteHandler(evt : Event) : void {
			content = loader.data as ByteArray;
			evt.stopPropagation();
			if(content.length==0){
				dispatchEvent(new ErrorEvent(ErrorEvent.ERROR, true, false, 'Пустой контент'));
				return;
			}
			saveFile();
			dispatchEvent(new Event(Event.COMPLETE));
		}
		
		private function saveFile():Boolean{
			if(!content || content.length==0) return false;
			var folder:File;
			if(targetFolder){
				folder= new File(targetFolder);
				if(!folder.exists || !folder.isDirectory) folder=null;
			}
			if(!folder) folder=File.userDirectory;
			var fileName:String=StrUtil.removeFileExtension(targetFileName);
			var fileExt:String=StrUtil.getFileExtension(targetFileName);
			var file:File= folder.resolvePath(targetFileName);
			var i:int=0;
			while(file.exists && i<100){
				try{
					file.deleteFile();
				}catch(error:Error){}
				if(file.exists){
					i++;
					file=folder.resolvePath(fileName+i.toString()+'.'+fileExt);
				}
			}
			if(file.exists){
				dispatchEvent(new ErrorEvent(ErrorEvent.ERROR, true, false, 'Ошибка создания файла'));
				return false;
			}
			try{
				var fs:FileStream = new FileStream();
				fs.open(file, FileMode.WRITE);
				fs.writeBytes(content);
				fs.close();
			} catch(err:Error){
				dispatchEvent(new ErrorEvent(ErrorEvent.ERROR, true, false, 'Ошибка записи в файл ' + err.message));
				return false;
			}
			targetFile=file;
			return true;
		}

	}	
}
