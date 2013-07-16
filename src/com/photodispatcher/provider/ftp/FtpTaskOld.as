package com.photodispatcher.provider.ftp{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.model.SourceService;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	import flash.utils.Dictionary;
	
	import mx.controls.Alert;
	
	import pl.maliboo.ftp.Commands;
	import pl.maliboo.ftp.FTPCommand;
	import pl.maliboo.ftp.FTPFile;
	import pl.maliboo.ftp.core.FTPClient;
	import pl.maliboo.ftp.events.FTPEvent;
	import pl.maliboo.ftp.utils.ConsoleListener;
	
	[Event(name="complete", type="flash.events.Event")]
	[Event(name="progress", type="flash.events.ProgressEvent")]
	public class FtpTaskOld extends EventDispatcher{
		public static const FTP_PORT:int=21;

		[Bindable]
		public var ftpListener:ConsoleListener;
		[Bindable]
		public var mbytesTotal:Number=0;
		
		private var ftpClient:FTPClient;
		private var source:SourceService;
		private var srcFolder:String;
		private var dstFolder:String;
		
		private var bytesLoaded:int;
		private var bytesTotal:int;
		private var filesNum:int;

		public function FtpTaskOld(source:SourceService,srcFolder:String,dstFolder:String){
			super(null);
			this.source=source;
			this.srcFolder=srcFolder;
			this.dstFolder=dstFolder;
		}
		
		
		public function stop():void{
			//TODO implement stop
			ftpClient.stop();
			//disconnect
			ftpClient.sendDirectCommand(new FTPCommand(Commands.QUIT));
		}
		
		public function start():void{
			if(!source || !srcFolder || !dstFolder){
				//TODO rise err
				return;
			}
			ftpClient= new FTPClient();
			/*listen*/
			ftpClient.addEventListener(FTPEvent.CONNECTED, handleConnected);
			ftpClient.addEventListener(FTPEvent.LOGGED, handleLogged);
			ftpClient.addEventListener(FTPEvent.PROGRESS, progressListener);
			ftpClient.addEventListener(FTPEvent.DOWNLOAD, downloadListener);	
			ftpClient.addEventListener(FTPEvent.INVOKE_ERROR, handleError);	
			//ftpClient.addEventListener(FTPEvent.UPLOAD, uploadListener);
			//ftpClient.addEventListener(FTPEvent.CHANGE_DIR, refresh_remote_Handler);
			//ftpClient.addEventListener(Event.CLOSE, dissconnectListener);	
			//ftpClient.addEventListener(FTPEvent.DELETE_FILE, refresh_remote_Handler);
			//ftpClient.addEventListener(FTPEvent.RENAME_FILE, refresh_remote_Handler);
			//ftpClient.addEventListener(FTPEvent.CREATE_DIR, refresh_remote_Handler);
			//ftpClient.addEventListener(FTPEvent.STOP, stopListener);
			//ftpClient.addEventListener(FTPEvent.PAUSE, pauseListener);
			
			if (!ftpListener) ftpListener = new ConsoleListener(ftpClient);
			ftpClient.workingDirectory="/";
			//run ftp sess
			ftpClient.connect(source.url, FTP_PORT);				
		}
		/////////////////////////////////////////////////
		//Слушатели событий при взаимодействии с сервером
		/////////////////////////////////////////////////			
		private function handleError(e:FTPEvent):void{
			//TODO implement
		}
		//Функция вызываемая при отключении от сервера
		private function dissconnectListener(e:Event=null):void{
		}
		//Функция отображения состояния загрузки файла
		private var lastLoadedProgress:int=0;
		private function progressListener(e:FTPEvent):void{
			bytesLoaded+=(e.bytes-lastLoadedProgress);
			lastLoadedProgress=e.bytes;
			dispatchEvent(new ProgressEvent(ProgressEvent.PROGRESS,false,false,bytesLoaded,bytesTotal));
			//file_lb.text=e.file+" "+numberFormatter.format(e.bytesTotal/1024)+" kB";		
		}
		//Функция вызываемая при остановке закачки файла с помощью кнопки "стоп"
		private function stopListener(e:FTPEvent):void{
		}
		//Функция вызываемая при отановке закачки файла с помощью кнопки "пауза"
		private function pauseListener(e:FTPEvent):void{
			/*
			p_bytes=e.bytes;
			p_local_file=e.file;
			p_remote_file=e.path;
			p_size=e.bytesTotal;
			p_type=e.process;
			*/
		}						
		//Функция вызываемая при начале закачки файла на сервер
		private function uploadListener(e:FTPEvent):void{
		}
		//Функция вызываемая при загрузки файла с сервера
		private function downloadListener(e:FTPEvent):void{
			downloadNext();
		}
		
		//Функция вызываемая при установлении связи в сервером
		private function handleConnected (evt:FTPEvent):void{				
			if(source && source.user){ 
				ftpClient.login(source.user, source.pass);
			} else {
				//TODO rise err
				ftpClient.login('anonymous', 'anonymous@anonymous.net');
			}
		}
		
		//Функция вызываемая при успешной авторизации на сервере
		private function handleLogged (evt:FTPEvent):void{
			ftpClient.addEventListener(FTPEvent.LISTING, handleListing);
			listFolder(srcFolder);
		}

		private var foldersToScan:Array=[];/*of FTPFile*/
		private var ftpFiles:Array=[];/*of FTPFile*/
		private var currFolder:FTPFile;
		private function listFolder(folder:String):void{
			trace('FtpTask start build ftp file list, root folder :' +folder);
			ftpClient.list(folder);	
		}
		
		//Функция вызываемая при получении списка файлов на удалённом сервере
		private function handleListing(evt:FTPEvent):void {
			var lst:Array=evt.listing;
			var fl:FTPFile;
			if(lst){
				for each(var o:* in lst){
					fl=(o as FTPFile);
					if(fl && fl.name!='..'){//skip parent dir
						if(fl._isDir){
							foldersToScan.push(fl);
						}else{
							ftpFiles.push(fl);
						}
					}
				}
			}
			//check queue
			if(foldersToScan.length>0){
				//list next
				fl=foldersToScan.shift() as FTPFile;
				if(fl){
					currFolder=fl;
					trace('FtpTask scan subdir, folder :'+fl.fullPath);
					ftpClient.list(fl.fullPath);
				}else{
					//TODO posible bug (hung if !fl)
				}
			}else{
				//completed
				ftpClient.removeEventListener(FTPEvent.LISTING, handleListing);
				filesNum=ftpFiles.length;
				var toLoad:int;
				for each(fl in ftpFiles){
					if(fl) toLoad+=fl.size;
				}
				bytesTotal=toLoad;
				mbytesTotal= Math.round(bytesTotal/(1024*1024));
				trace('FtpTask ftp file list ready, files num:' +filesNum.toString()+', total size: '+bytesTotal+'b');
				//run download
				startDownload();
			}
		}
		
		private var currDownloadIdx:int;
		//private var lockalRootPath:String;
		private function startDownload():void{
			//TODO implement
			bytesLoaded=0;
			currDownloadIdx=-1;
			dispatchEvent(new ProgressEvent(ProgressEvent.PROGRESS,false,false,bytesLoaded,bytesTotal));
			downloadNext();
		}
		private function downloadNext():void{
			var fl:FTPFile;
			var dstDir:String;
			var f:File;
			if(currDownloadIdx!=-1){
				fl=ftpFiles[currDownloadIdx] as FTPFile;
				if(fl){
					trace('FtpTask. Complited download file: '+fl.fullPath);
					f=new File(dstFolder+fl.path+File.separator+fl.name+'.tmp');
					if(f.exists){
						//rename
						var ff:File=f.parent;
						ff=ff.resolvePath(fl.name);
						try{
							f.moveTo(ff,true);
						}catch (error:Error){
							trace('FtpTask. Rename error:'+ error.message);
						}
					}else{
						trace('FtpTask. File not found: '+f.nativePath);
					}
				}
			}
			currDownloadIdx++;
			if (currDownloadIdx<ftpFiles.length){
				lastLoadedProgress=0;
				fl=ftpFiles[currDownloadIdx] as FTPFile;
				if (fl){
					//check/create dir
					dstDir=dstFolder+fl.path;
					f=new File(dstDir);
					f.createDirectory();
					//add .tmp ext'n (download incompleted)
					f=f.resolvePath(fl.name+'.tmp');
					trace('FtpTask. Start download file: '+fl.fullPath);
					ftpClient.getFile(fl.fullPath, fl.size, f.nativePath, 0);
				}else{
					//
				}
			}else{
				//completed
				//TODO implement
				trace('FtpTask. Download completed.');
				dispatchEvent(new ProgressEvent(ProgressEvent.PROGRESS,false,false,bytesLoaded,bytesTotal));
				dispatchEvent(new Event(Event.COMPLETE));
				//Alert.show('FtpTask. Download completed.');
				//disconnect
				ftpClient.sendDirectCommand(new FTPCommand(Commands.QUIT));
			}

		}
		
		
		/**
		 * 
		 * @return map key->fileParentDir value->arrayFileNames 
		 * 
		 */
		public function getFileStructure():Dictionary{
			var fl:FTPFile;
			var path:String;
			var map:Dictionary=new Dictionary;
			for each(fl in ftpFiles){
				if(fl){
					path=fl.parentDir;
					var arr:Array=map[path] as Array;
					if(!arr){
						arr=new Array();
						map[path]=arr;
					}
					arr.push(fl.name);
				}
			}
			//remove root
			delete map[srcFolder.substr(1)];
			return map;
		}
	}
}