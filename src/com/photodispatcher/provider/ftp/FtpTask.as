package com.photodispatcher.provider.ftp{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.model.Source;
	import com.photodispatcher.model.SourceService;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.ProgressEvent;
	import flash.events.TimerEvent;
	import flash.filesystem.File;
	import flash.utils.Dictionary;
	import flash.utils.Timer;
	
	import pl.maliboo.ftp.Commands;
	import pl.maliboo.ftp.FTPCommand;
	import pl.maliboo.ftp.FTPFile;
	import pl.maliboo.ftp.core.FTPClient;
	import pl.maliboo.ftp.errors.FTPError;
	import pl.maliboo.ftp.events.FTPEvent;
	import pl.maliboo.ftp.utils.ConsoleListener;
	
	[Event(name="complete", type="flash.events.Event")]
	[Event(name="progress", type="flash.events.ProgressEvent")]

	[Event(name="logged", 		type="pl.maliboo.ftp.FTPEvent")]
	[Event(name="download", 	type="pl.maliboo.ftp.FTPEvent")]
	[Event(name="scanDir", 		type="pl.maliboo.ftp.FTPEvent")]
	[Event(name="invokeError", 	type="pl.maliboo.ftp.FTPEvent")]
	[Event(name="stop", 		type="pl.maliboo.ftp.FTPEvent")]
	[Event(name="pause", 		type="pl.maliboo.ftp.FTPEvent")]
	[Event(name="disconnected", type="pl.maliboo.ftp.FTPEvent")]
	public class FtpTask extends EventDispatcher{
		public static const FTP_PORT:int=21;
		public static const IDLE_TIMEOUT:int	=180000;//3min
		public static const ABORT_TIMEOUT:int	=30000;//30s
		public static const CONNECT_TIMEOUT:int	=15000;//15s
		

		public var ftpListener:ConsoleListener;
		public var mbytesTotal:Number=0;
		public var orderId:String;
		
		private var ftpClient:FTPClient;
		private var source:Source;
		
		private var bytesLoaded:int;
		private var bytesTotal:int;
		private var filesNum:int;

		public function FtpTask(source:Source){
			super(null);
			this.source=source;
		}
		
		public function get isConnected():Boolean{
			if(ftpClient && ftpClient.isConnected) return true;
			return false;
		}

		public function close():void{
			destroyIdleTimer();
			if(isConnected && ftpClient){
				//disconnect
				try{
					ftpClient.sendDirectCommand(new FTPCommand(Commands.QUIT));
					//ftpClient.stop();
					ftpClient.close();
				} catch(e:Error){
					//do nothing
					//dispatchEvent(new FTPEvent(FTPEvent.DISCONNECTED));
				}
			}
			dispatchEvent(new FTPEvent(FTPEvent.DISCONNECTED));
			ftpClient=null;
		}
		
		private function destroy():void{
			destroyIdleTimer();
			if(!ftpClient) return;
			ftpClient.removeEventListener(FTPEvent.INVOKE_ERROR, handleError);
			ftpClient.removeEventListener(FTPEvent.CONNECTED, handleConnected);
			ftpClient.removeEventListener(FTPEvent.LOGGED, handleLogged);
			ftpClient.removeEventListener(FTPEvent.LISTING, handleListing);
			//ftpClient.removeEventListener(FTPEvent.PROGRESS, progressListener);
			ftpClient.removeEventListener(FTPEvent.DOWNLOAD, downloadListener);
			ftpClient.removeEventListener(FTPEvent.PAUSE, onPause);
			ftpClient.removeEventListener(FTPEvent.DISCONNECTED, onDisconnected);
			ftpClient=null;
		}
		
		public function connect():void{
			if(!source || !source.ftpService){
				dispatchErr('Не верные параметры запуска');
				return;
			}
			ftpClient= new FTPClient();
			/*listen*/
			ftpClient.addEventListener(FTPEvent.CONNECTED, handleConnected);
			ftpClient.addEventListener(FTPEvent.INVOKE_ERROR, handleError);
			// 4 debug if (!ftpListener) ftpListener = new ConsoleListener(ftpClient);
			ftpClient.workingDirectory="/";
			//connect timeout
			startIdleTimer(CONNECT_TIMEOUT);
			//run ftp sess
			ftpClient.connect(source.ftpService.url, FTP_PORT);				
		}

		private var _abort:Boolean=false;
		public function abort():void{
			_abort=true;
			if(isConnected && ftpClient.isBusy){
				//ftpClient.sendDirectCommand(new FTPCommand(Commands.ABOR));
				ftpClient.abort();
				//server can ignore abort
				startIdleTimer(ABORT_TIMEOUT);
			}else{
				dispatchEvent(new FTPEvent(FTPEvent.PAUSE));
			}
		}

		private function handleError(e:FTPEvent):void{
			stopIdleTimer();
			if(downloadFile) downloadFile.loadState=FTPFile.LOAD_ERR;
			dispatchEvent(e.clone());
		}

		/*
		//private var lastLoadedProgress:int=0;
		private function progressListener(e:FTPEvent):void{
			//bytesLoaded+=(e.bytes-lastLoadedProgress);
			//lastLoadedProgress=e.bytes;
			//dispatchEvent(new ProgressEvent(ProgressEvent.PROGRESS,false,false,bytesLoaded,bytesTotal));
			//file_lb.text=e.file+" "+numberFormatter.format(e.bytesTotal/1024)+" kB";
			dispatchEvent(new ProgressEvent(ProgressEvent.PROGRESS,false,false,e.bytesTransferred,e.bytesTotal));
		}
		*/
		
		//Функция вызываемая при установлении связи в сервером
		private function handleConnected (evt:FTPEvent):void{
			stopIdleTimer();
			ftpClient.removeEventListener(FTPEvent.CONNECTED, handleConnected);
			ftpClient.addEventListener(FTPEvent.LOGGED, handleLogged);
			if(source && source.ftpService && source.ftpService.user){ 
				ftpClient.login(source.ftpService.user, source.ftpService.pass);
			} else {
				//TODO rise err
				ftpClient.login('anonymous', 'anonymous@anonymous.net');
			}
		}
		
		//Функция вызываемая при успешной авторизации на сервере
		private function handleLogged (evt:FTPEvent):void{
			ftpClient.removeEventListener(FTPEvent.LOGGED, handleLogged);
			listenClient();
			startIdleTimer();
			dispatchEvent(evt.clone());
		}
		
		private function listenClient():void{
			ftpClient.addEventListener(FTPEvent.PAUSE, onPause);
			ftpClient.addEventListener(FTPEvent.DISCONNECTED, onDisconnected);
		}
		private function onPause(evt:FTPEvent):void{
			startIdleTimer();
			dispatchEvent(evt.clone());
		}
		private function onDisconnected(evt:FTPEvent):void{
			dispatchEvent(evt.clone());
			destroy();
		}
		
		private var foldersToScan:Array=[];/*of FTPFile*/
		private var ftpFiles:Array=[];/*of FTPFile*/
		private var currFolder:FTPFile;
		private var folderToScan:String;
		public function scanFolder(folder:String):void{
			_abort=false;
			stopIdleTimer();
			if(!isConnected){
				//dispatchEvent(new FTPEvent(FTPEvent.DISCONNECTED));
				dispatchErr('FtpTask. Disconnected');
				return;
			}
			foldersToScan=[];
			ftpFiles=[];
			ftpClient.addEventListener(FTPEvent.LISTING, handleListing);
			trace('FtpTask start build ftp file list, root folder :' +folder);
			folderToScan=folder;
			ftpClient.list(folder);	
		}
		
		//Функция вызываемая при получении списка файлов на удалённом сервере
		private function handleListing(evt:FTPEvent):void {
			if(_abort){
				ftpClient.removeEventListener(FTPEvent.LISTING, handleListing);
				startIdleTimer();
				dispatchEvent(new FTPEvent(FTPEvent.PAUSE));
				return;
			}
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
					//trace('FtpTask scan subdir, folder :'+fl.fullPath);
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
				trace('FtpTask ftp file list ready '+folderToScan+', files num:' +filesNum.toString()+', total size: '+bytesTotal+'b');
				
				var e:FTPEvent=new FTPEvent(FTPEvent.SCAN_DIR);
				e.listing=ftpFiles;
				startIdleTimer();
				dispatchEvent(e);
			}
		}

		private function dispatchErr(errMsg:String):void{
			var err:FTPEvent=new FTPEvent(FTPEvent.INVOKE_ERROR);
			if(_abort){
				/*
				dispatchEvent(new FTPEvent(FTPEvent.PAUSE));
				startIdleTimer();
				*/
				close();
				return;
			}else{
				err.error=new FTPError(errMsg);
				dispatchEvent(err);
			}
		}
		
		public var downloadFile:FTPFile;
		private var localFolder:String;
		public function download(ftpFile:FTPFile,dstFolder:String):void{
			_abort=false;
			stopIdleTimer();
			if(!isConnected){
				dispatchErr('FtpTask. Disconnected');
				return;
			}
			//ftpClient.addEventListener(FTPEvent.PROGRESS, progressListener);
			ftpClient.addEventListener(FTPEvent.DOWNLOAD, downloadListener);
			downloadFile=ftpFile;
			localFolder=dstFolder;
			var dstDir:String=dstFolder+File.separator+ ftpFile.path;
			var f:File=new File(dstDir);
			//TODO try/catch
			f.createDirectory();
			//add .tmp ext'n (download incompleted)
			f=f.resolvePath(ftpFile.name+'.tmp');
			trace('FtpTask. Start download file: '+ftpFile.fullPath);
			ftpFile.loadState=FTPFile.LOAD_STARTED;
			ftpClient.getFile(ftpFile.fullPath, ftpFile.size, f.nativePath, 0);
			
		}

		private function downloadListener(evt:FTPEvent):void{
			//download completed
			//ftpClient.removeEventListener(FTPEvent.PROGRESS, progressListener);
			ftpClient.removeEventListener(FTPEvent.DOWNLOAD, downloadListener);
			if(_abort){
				startIdleTimer();
				dispatchEvent(new FTPEvent(FTPEvent.PAUSE));
				return;
			}
			trace('FtpTask. Complited download file: '+downloadFile.fullPath);

			var err:FTPEvent;
			var f:File=new File(localFolder+File.separator+downloadFile.path+File.separator+downloadFile.name+'.tmp');
			if(f.exists){
				//rename
				var ff:File=f.parent;
				ff=ff.resolvePath(downloadFile.name);
				try{
					f.moveTo(ff,true);
				}catch (error:Error){
					trace('FtpTask. Rename error:'+ error.message);
					downloadFile.loadState=FTPFile.LOAD_ERR;
					dispatchErr('FtpTask. Rename error:'+ error.message);
					return;
				}
			}else{
				trace('FtpTask. File not found: '+f.nativePath);
				downloadFile.loadState=FTPFile.LOAD_ERR;
				dispatchErr('FtpTask. File not found: '+f.nativePath);
				return;
			}
			downloadFile.loadState=FTPFile.LOAD_COMPLETE;
			startIdleTimer();
			dispatchEvent(evt.clone());
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
			if(!ftpFiles) return map; 
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
			delete map[folderToScan];
			return map;
		}
		
		private var idleTimer:Timer;
		private function startIdleTimer(timeout:int=IDLE_TIMEOUT):void{
			trace('ftpTsk startIdleTimer '+timeout.toString());
			if(!idleTimer){
				idleTimer= new Timer(timeout,1);
				idleTimer.addEventListener(TimerEvent.TIMER, onIdleTimer);
			}else{
				idleTimer.stop();
				idleTimer.reset();
				idleTimer.delay=timeout;
			}
			idleTimer.start();
		}
		private function stopIdleTimer():void{
			trace('ftpTsk stopIdleTimer');
			if(idleTimer){
				idleTimer.stop();
				idleTimer.reset();
			}
		}
		private function onIdleTimer(evt:Event):void{
			trace('ftpTsk onIdleTimer - close');
			close();
		}
		
		private function destroyIdleTimer():void{
			if(idleTimer){
				idleTimer.stop();
				idleTimer.removeEventListener(TimerEvent.TIMER, onIdleTimer);
				idleTimer=null;
			}
		}

	}
}