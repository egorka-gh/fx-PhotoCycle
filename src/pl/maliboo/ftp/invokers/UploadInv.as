package pl.maliboo.ftp.invokers
{
	import flash.errors.IOError;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.net.Socket;
	import flash.utils.ByteArray;
	import flash.utils.clearInterval;
	import flash.utils.getTimer;
	import flash.utils.setInterval;
	
	import pl.maliboo.ftp.Commands;
	import pl.maliboo.ftp.FTPCommand;
	import pl.maliboo.ftp.Responses;
	import pl.maliboo.ftp.core.FTPClient;
	import pl.maliboo.ftp.core.FTPInvoker;
	import pl.maliboo.ftp.errors.InvokeError;
	import pl.maliboo.ftp.events.FTPEvent;
	import pl.maliboo.ftp.utils.PassiveSocketInfo;

	public class UploadInv extends FTPInvoker
	{
		private var localFile:String;
		private var remoteFile:String;
		
		private var sourceFile:FileStream;
		private var fileMode:String;
		private var passiveSocket:Socket;
		
		private var bytesTotal:int=0;
		private var bufferSize:uint = 4096;
		
		private var interval:uint;
		
		private var startTime:int;
		private var byteBegin:uint;
		
		public function UploadInv(client:FTPClient, localFile:String, remoteFile:String, byteBegin:uint)
		{
			super(client);
			this.localFile = localFile;
			this.remoteFile = remoteFile;
			this.byteBegin = byteBegin;
			sourceFile = new FileStream();
		}
		
		override protected function startSequence ():void
		{
			sourceFile.open(new File(localFile), FileMode.READ);
			trace("File has: "+sourceFile.bytesAvailable+" bytes");			
			bytesTotal=sourceFile.bytesAvailable;
			sourceFile.position=byteBegin;
			sendCommand(new FTPCommand(Commands.BINARY));
		}
		
		override protected function responseHandler(evt:FTPEvent):void
		{
			switch (evt.response.code)
			{
				case Responses.COMMAND_OK:
					sendCommand(new FTPCommand(Commands.PASV));
					break;
				case Responses.ENTERING_PASV:
					passiveSocket = PassiveSocketInfo.createPassiveSocket(evt.response.message,
																			handleConnect,
																			handleData,
																			handleIOErr,
																			handleClose);
					break;
				case Responses.DATA_CONN_CLOSE:
					sourceFile.close();
					trace(getTimer()+" ACK/"+(getTimer()-startTime))
					//passiveSocket.close();
					var downloadEvent:FTPEvent = new FTPEvent(FTPEvent.UPLOAD);
					downloadEvent.bytesTotal = bytesTotal;
					downloadEvent.file = remoteFile;
					downloadEvent.time = getTimer() - startTime;
					release(downloadEvent);
					
					break;
				case Responses.FILE_STATUS_OK:
					startSendingData();
					break;	
				case Responses.MORE_INFO:
					sendCommand(new FTPCommand(Commands.STOR, remoteFile));
					break;
				case Responses.CONNECTION_CLOSED:	
					var pauseEvent:FTPEvent = new FTPEvent(FTPEvent.PAUSE);
					pauseEvent.bytes = bytesTotal-sourceFile.bytesAvailable;
					pauseEvent.file = localFile;
					pauseEvent.path= remoteFile;
					pauseEvent.process="uploading";
					
					clearInterval(interval);
					sourceFile.close();				
					if(passiveSocket.connected) passiveSocket.close();	
					
					release(pauseEvent);
					break;
				default:
					try{
					clearInterval(interval);
					sourceFile.close();
					if(passiveSocket.connected) passiveSocket.close();
					} catch(e:Error){}
					releaseWithError(new InvokeError(evt.response.message));
			}	
		}
		
		override protected function cleanUp ():void
		{			
				clearInterval(interval);
				 sourceFile.close();				
				if(passiveSocket.connected) passiveSocket.close();			
		}
		
		private function handleConnect (evt:Event):void
		{
			if(byteBegin!=0){
				sendCommand(new FTPCommand(Commands.REST, byteBegin.toString()));
			} else {
				sendCommand(new FTPCommand(Commands.STOR, remoteFile));
			}
		}
		
		private function handleIOErr(evt:IOErrorEvent):void
		{
			trace("err")
		}
		
		private function handleClose(evt:Event):void
		{
			trace(getTimer()+" Real socket close")
		}
		
		private function handleData (evt:ProgressEvent):void
		{
			trace("Upload SocketData")
		}
		
		private function handleProgress (evt:ProgressEvent):void
		{
			trace("Progress");
		}
		
		private function startSendingData():void
		{
			trace(getTimer()+" Start sending data! ("+passiveSocket.connected+")");
			startTime = getTimer();
			interval = setInterval(sendData, 0);		
		}

		private function sendData():void
		{		
			if (sourceFile.bytesAvailable <= 0)
			{
				clearInterval(interval);
				passiveSocket.close();
				trace(getTimer()+" SocketClose :"+passiveSocket.connected);				
				return;
			}
			
			if (sourceFile.bytesAvailable < bufferSize)	bufferSize = sourceFile.bytesAvailable;
			
			var ba:ByteArray = new ByteArray();		
			sourceFile.readBytes(ba, 0, bufferSize);
			
			trace(getTimer()+" Bytes to read: "+ba.bytesAvailable+"/"+sourceFile.bytesAvailable);			
			passiveSocket.writeBytes(ba, 0, ba.bytesAvailable);
			passiveSocket.flush();
			var download_progressEvent:FTPEvent = new FTPEvent(FTPEvent.PROGRESS);
			download_progressEvent.bytesTotal = bytesTotal;
			download_progressEvent.bytes=bytesTotal-sourceFile.bytesAvailable;
			download_progressEvent.file = localFile;	
			client.dispatchEvent(download_progressEvent);			
			
			
		}
	}
}