package pl.maliboo.ftp.invokers
{
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.net.Socket;
	import flash.utils.ByteArray;
	
	import pl.maliboo.ftp.Commands;
	import pl.maliboo.ftp.FTPCommand;
	import pl.maliboo.ftp.Responses;
	import pl.maliboo.ftp.core.FTPClient;
	import pl.maliboo.ftp.core.FTPInvoker;
	import pl.maliboo.ftp.errors.InvokeError;
	import pl.maliboo.ftp.events.FTPEvent;
	import pl.maliboo.ftp.utils.PassiveSocketInfo;

	public class DownloadInv extends FTPInvoker
	{
		
		private var remoteFile:String;		
		private var localFile:String;
		
		private var targetFile:FileStream;
		private var fileMode:String;
		private var passiveSocket:Socket;
		
		private var bytes:int=0;
		private var bytesTotal:int=0;
		private var byteBegin:uint;
		
		public function DownloadInv(client:FTPClient, remoteFile:String, remoteFileSize:int,
										localFile:String, byteBegin:uint)
		{
			super(client);
			this.remoteFile = remoteFile;
			this.localFile = localFile;			
			targetFile = new FileStream();
			this.byteBegin=byteBegin;
			if(byteBegin!=0){
				bytes=byteBegin;
				fileMode = FileMode.APPEND;	
			} else {
				fileMode=FileMode.WRITE;
			}
			bytesTotal=remoteFileSize;
		}
		
		override protected function startSequence ():void
		{
			try{
				targetFile.open(new File(localFile), fileMode);			
				sendCommand(new FTPCommand(Commands.BINARY));
				startTimeoutTimer();
			} catch(e:Error){
				releaseWithError(new InvokeError(e.message));
			}
		}
		
		override protected function responseHandler(evt:FTPEvent):void{
			resetTimeoutTimer();
			switch (evt.response.code)
			{
				case Responses.COMMAND_OK:
					sendCommand(new FTPCommand(Commands.PASV));
					break;
				case Responses.ENTERING_PASV:
					try{
						passiveSocket = PassiveSocketInfo.createPassiveSocket(evt.response.message, handleConnect, handleData, handleIOErr, handleClose);
						client.passiveInfo='--';
					} catch(e:Error){
						releaseWithError(new InvokeError(e.message));
						return;
					}
					break;
				case Responses.DATA_CONN_CLOSE:
					//completed
					if(bytes>=bytesTotal){
						if(targetFile) targetFile.close();	
						var downloadEvent:FTPEvent = new FTPEvent(FTPEvent.DOWNLOAD);
						downloadEvent.bytesTotal = bytesTotal;
						downloadEvent.file = localFile;
						cleanUpPassiveSocket();
						//passiveSocket.removeEventListener(ProgressEvent.SOCKET_DATA, handleData);
						release(downloadEvent);
					}else{
						trace('Server says finish download, but transfer incomplete, waite data socket close');
						/*
						trace('Data connection closed (transfer completed), wrong data len, loaded: ' +bytes.toString()+', need: '+bytesTotal.toString()) ;
						releaseWithError(new InvokeError('Data connection closed'));
						*/
					}
					break;
				case Responses.MORE_INFO:
					sendCommand(new FTPCommand(Commands.RETR, remoteFile));
					break;
				case Responses.FILE_STATUS_OK:
					//???
					/*
					if(bytes>=bytesTotal){
						targetFile.close();	
						var downloadEvent2:FTPEvent = new FTPEvent(FTPEvent.DOWNLOAD);
						downloadEvent2.bytesTotal = bytesTotal;
						downloadEvent2.file = localFile;
						
						passiveSocket.removeEventListener(ProgressEvent.SOCKET_DATA, handleData);
						release(downloadEvent2);
					}
					*/
					break;
				case Responses.CONNECTION_CLOSED:	//ABOR Connection closed; transfer aborted.
					//TODO process in releaseWithError??
					if(targetFile) targetFile.close();				
					//if(passiveSocket.connected) passiveSocket.close();
					cleanUpPassiveSocket();
					
					if(aborted){
						var pauseEvent:FTPEvent = new FTPEvent(FTPEvent.PAUSE);
						pauseEvent.bytes = bytes;
						pauseEvent.bytesTotal=bytesTotal;
						pauseEvent.file = localFile;
						pauseEvent.path= remoteFile;
						pauseEvent.process="downloading";
						release(pauseEvent);
					}else{
						trace('Data connection closed (transfer aborted)') ;
						releaseWithError(new InvokeError('Data connection closed'));
					}
					break;
				default:
					releaseWithError(new InvokeError(evt.response.message));
			}	
		}
		
		private function handleConnect (evt:Event):void{
			resetTimeoutTimer();
			client.passiveInfo=passiveSocket.localAddress+':'+passiveSocket.localPort.toString()+'->'+passiveSocket.remoteAddress+':'+passiveSocket.remotePort.toString();
			if(byteBegin!=0){
				sendCommand(new FTPCommand(Commands.REST, byteBegin.toString()));
			} else {
				sendCommand(new FTPCommand(Commands.RETR, remoteFile));
			}
		}

		private function handleIOErr (evt:IOErrorEvent):void{
			trace('IO err '+evt.text);
			releaseWithError(new InvokeError(evt.text));
		}
		private function handleClose (evt:Event):void{
			//releaseWithError(new InvokeError('Data socket closed'));
			/*
			if(bytes<bytesTotal && !aborted){
				trace('Data socket closed, incomplite download');
				releaseWithError(new InvokeError('Data connection closed'));
			}
			*/
			if(aborted) return;

			if(bytes>=bytesTotal){
				trace('Data connection closed (data Socket close), download complite') ;
				if(targetFile) targetFile.close();	
				var downloadEvent:FTPEvent = new FTPEvent(FTPEvent.DOWNLOAD);
				downloadEvent.bytesTotal = bytesTotal;
				downloadEvent.file = localFile;
				cleanUpPassiveSocket();
				//passiveSocket.removeEventListener(ProgressEvent.SOCKET_DATA, handleData);
				release(downloadEvent);
			}else{
				trace('Data connection closed (data Socket close), wrong data len, loaded: ' +bytes.toString()+', need: '+bytesTotal.toString()) ;
				releaseWithError(new InvokeError('Data connection closed'));
			}

		}

		private function handleData (evt:ProgressEvent):void{
			resetTimeoutTimer();
			var bytesAval:uint=0;
			//trace(bytes);
			if((bytes+passiveSocket.bytesAvailable)>bytesTotal){
				bytesAval=bytesTotal-bytes;
				bytes=bytesTotal;				
			} else {
				bytes += passiveSocket.bytesAvailable;
				bytesAval=passiveSocket.bytesAvailable;
			}
			//trace(bytesTotal);

			var bytesArr:ByteArray = new ByteArray();
			passiveSocket.readBytes(bytesArr, 0, bytesAval);	
			
			if(targetFile) targetFile.writeBytes(bytesArr, 0, bytesArr.bytesAvailable);
			var progressEvent:FTPEvent = new FTPEvent(FTPEvent.PROGRESS);
			progressEvent.bytesTotal = bytesTotal;
			progressEvent.bytes = bytes;
			progressEvent.bytesTransferred = bytesAval;
			progressEvent.file = localFile;
			client.dispatchEvent(progressEvent);
			/*
			if(bytes>=bytesTotal){
				// 	ftp still in transfere mode
				//	completed == DATA_CONN_CLOSE
				targetFile.close();	
				var downloadEvent:FTPEvent = new FTPEvent(FTPEvent.DOWNLOAD);
				downloadEvent.bytesTotal = bytesTotal;
				downloadEvent.file = localFile;
				passiveSocket.removeEventListener(ProgressEvent.SOCKET_DATA, handleData);
				release(downloadEvent);
			} else {			
				var progressEvent:FTPEvent = new FTPEvent(FTPEvent.PROGRESS);
				progressEvent.bytesTotal = bytesTotal;
				progressEvent.bytes = bytes;
				progressEvent.bytesTransferred = bytesAval;
				progressEvent.file = localFile;
				client.dispatchEvent(progressEvent);
			}
			*/
		}		
	
		
		private function cleanUpPassiveSocket():void{
			if(passiveSocket!=null){
				passiveSocket.removeEventListener(ProgressEvent.SOCKET_DATA, handleData);
				passiveSocket.removeEventListener(Event.CONNECT, handleConnect);
				passiveSocket.removeEventListener(IOErrorEvent.IO_ERROR, handleIOErr);
				passiveSocket.removeEventListener(Event.CLOSE, handleClose);
				//if(passiveSocket.connected) passiveSocket.close();
				try{
					if(passiveSocket.connected) passiveSocket.close();
				}catch(err:Error){}
				passiveSocket=null;
			}
		}
		
		override protected function cleanUp ():void		{			
			cleanUpPassiveSocket();				
			if(targetFile){
				try{
					targetFile.close();
				}catch(err:Error){}
			}
			//passiveSocket.removeEventListener(ProgressEvent.SOCKET_DATA, handleData);
		}
		
		override public function abort():void{
			if(targetFile){
				try{
					targetFile.close();
					targetFile=null;
				}catch(err:Error){}
			}
		}
		
	}
}