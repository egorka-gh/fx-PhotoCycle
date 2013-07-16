package pl.maliboo.ftp.core
{
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.net.Socket;
	import flash.utils.describeType;
	
	import mx.controls.Alert;
	
	import pl.maliboo.ftp.Commands;
	import pl.maliboo.ftp.FTPCommand;
	import pl.maliboo.ftp.FTPResponse;
	import pl.maliboo.ftp.errors.FTPError;
	import pl.maliboo.ftp.events.FTPEvent;
	import pl.maliboo.ftp.invokers.ChangeDirInv;
	import pl.maliboo.ftp.invokers.CreateInv;
	import pl.maliboo.ftp.invokers.DeleteInv;
	import pl.maliboo.ftp.invokers.DownloadInv;
	import pl.maliboo.ftp.invokers.ListInv;
	import pl.maliboo.ftp.invokers.LoginInv;
	import pl.maliboo.ftp.invokers.RenameInv;
	import pl.maliboo.ftp.invokers.UploadInv;
	import pl.maliboo.ftp.invokers.WelcomeInv;
	
	[Event(name="connected", 	type="pl.maliboo.ftp.FTPEvent")]
	[Event(name="disconnected", type="pl.maliboo.ftp.FTPEvent")]
	[Event(name="logged", 		type="pl.maliboo.ftp.FTPEvent")]
	[Event(name="command", 		type="pl.maliboo.ftp.FTPEvent")]
	[Event(name="changeDir", 	type="pl.maliboo.ftp.FTPEvent")]
	[Event(name="createDir", 	type="pl.maliboo.ftp.FTPEvent")]
	[Event(name="deleteDir", 	type="pl.maliboo.ftp.FTPEvent")]
	[Event(name="deleteFile", 	type="pl.maliboo.ftp.FTPEvent")]
	[Event(name="download", 	type="pl.maliboo.ftp.FTPEvent")]
	[Event(name="listing", 		type="pl.maliboo.ftp.FTPEvent")]
	[Event(name="progress", 	type="pl.maliboo.ftp.FTPEvent")]
	[Event(name="renameFile", 	type="pl.maliboo.ftp.FTPEvent")]
	[Event(name="response", 	type="pl.maliboo.ftp.FTPEvent")]
	[Event(name="upload", 		type="pl.maliboo.ftp.FTPEvent")]
	[Event(name="invokeError", 	type="pl.maliboo.ftp.FTPEvent")]
	[Event(name="pause", 		type="pl.maliboo.ftp.FTPEvent")]
	[Event(name="stop", 		type="pl.maliboo.ftp.FTPEvent")]
	
	public class FTPClient extends EventDispatcher
	{
		private var host:String;
		private var port:int;
		
		private var user:String;
		private var pass:String;
		
		private var ctrlSocket:Socket;
		private var dataSocket:Socket;
		
		private var processing:Boolean = false;
		private var currentProcess:FTPInvoker;
		
		private var _workingDirectory:String="/";
		
		public var passiveInfo:String='';
		
		public function FTPClient (host:String="", port:int=21)
		{
			this.host = host;
			this.port = port;
			ctrlSocket = new Socket();
			ctrlSocket.addEventListener(IOErrorEvent.IO_ERROR, handleIOError);
			ctrlSocket.addEventListener(Event.CONNECT, handleConnect);

			ctrlSocket.addEventListener(Event.CLOSE, handleClose);
			ctrlSocket.addEventListener(ProgressEvent.SOCKET_DATA, handleData);
			
			/**
			 * Own events:
			 * Own events must use highest priority, so they can be fired first!
			 */ 
			addEventListener(FTPEvent.CHANGE_DIR, handleChangeDir, false, 0xFFFFFF);
		}
		
		private function destroy():void{
			if(ctrlSocket){
				ctrlSocket.removeEventListener(Event.CONNECT, handleConnect);
				ctrlSocket.removeEventListener(IOErrorEvent.IO_ERROR, handleIOError);
				ctrlSocket.removeEventListener(Event.CLOSE, handleClose);
				ctrlSocket.removeEventListener(ProgressEvent.SOCKET_DATA, handleData);
				removeEventListener(FTPEvent.CHANGE_DIR, handleChangeDir);
				ctrlSocket=null;
			}
		}
		
		/**
		 * 
		 * 
		 * 
		*/
		internal function sendPartCommand (command:FTPCommand):Boolean{
			
			if (!isConnected || processing) return false;
			//if(!ctrlSocket || !ctrlSocket.connected) return false;
			processing = true;
			//trace("\t"+command.toExecuteString().replace(/PASS .+/gi, "PASS *****"));
			ctrlSocket.writeUTFBytes(command.toExecuteString()+"\n");
			ctrlSocket.flush();
			var evt:FTPEvent = new FTPEvent(FTPEvent.COMMAND);
			evt.command = command;
			dispatchEvent(evt);
			return true;
		}
		
		public function get isBusy():Boolean{
			if (currentProcess) return true;
			return false;
		}

		public function get isConnected():Boolean{
			if(ctrlSocket && ctrlSocket.connected) return true;
			return false;
		}
		
		internal function invoke (invoker:FTPInvoker):void{
			if (currentProcess) return;
			currentProcess = invoker;
			if (ctrlSocket.connected)
			{
				invoker.execute();
			}
			else
			{
				ctrlSocket.addEventListener(FTPEvent.CONNECTED, waitForConnectBeforeInvoke);
				connect(host, port);
			}
		}
		
		private function waitForConnectBeforeInvoke (evt:Event):void
		{
			ctrlSocket.removeEventListener(evt.type, arguments.callee);
			currentProcess.execute();
		}
		
		internal function finalizeCurrentProcess(evt:Event):void{
			currentProcess = null;
			if (evt) dispatchEvent(evt);
		}
		
		
		/**
		 * ctrlSocket listeners
		 */
		private function handleConnect (evt:Event):void{
			invoke(new WelcomeInv(this));
		}

		private function handleClose (evt:Event):void{		
			finalizeCurrentProcess(null);
			//dispatchEvent(new Event(Event.CLOSE));
			var event:FTPEvent=new FTPEvent(FTPEvent.DISCONNECTED);
			event.hostname=passiveInfo;
			dispatchEvent(event);
			destroy();
		}
		
		private function handleIOError (evt:IOErrorEvent):void{		
			//Alert.show("Socket Error #"+evt.errorID.toString(), "Error");
			var e:FTPEvent=new FTPEvent(FTPEvent.INVOKE_ERROR);
			e.error=new FTPError('Socket Error: '+ evt.text);
			dispatchEvent(e);
		}
		
		private function handleData (pEvt:ProgressEvent):void
		{
			processing = false;
			var response:String = ctrlSocket.readUTFBytes(ctrlSocket.bytesAvailable);
			var evt:FTPEvent = new FTPEvent(FTPEvent.RESPONSE);
			evt.response = FTPResponse.parseResponse(response);
			//trace(evt.response.code+" "+evt.response.message);				
			dispatchEvent(evt);			
		}
		
		/**
		 * Own listeners
		 */ 
		private function handleChangeDir (evt:FTPEvent):void
		{
			_workingDirectory = evt.directory;
		}
		
		
		[Bindable("changeDir")]
		public function get workingDirectory ():String
		{
			return _workingDirectory;
		}
		public function set workingDirectory (s:String):void
		{
			_workingDirectory=s;
		}
		
		
		public function get hostname ():String
		{
			return host;
		}
		
		
		public function connect (host:String, port:int=21):void
		{
			this.host = host;
			this.port = port;
			ctrlSocket.connect(host, port);
		}
				
		public function close ():void{
			if(isConnected){
				stop();
				ctrlSocket.close();			
			}//else{
				handleClose(null);
			//}
		}

		public function abort():void{
			sendDirectCommand(new FTPCommand(Commands.ABOR));
			if(currentProcess) currentProcess.abort();
		}

		
		public function sendCommand (command:FTPCommand):Boolean{			
			if (processing || currentProcess) return false;
			return sendPartCommand(command);
		}
		
		public function sendDirectCommand (command:FTPCommand):Boolean{			
			return sendPartCommand(command);
		}
		
		
		
		/**
		 * Protocol commands
		 */ 
		public function stop():void{
			var StopEvent:FTPEvent = new FTPEvent(FTPEvent.STOP);
			if(currentProcess!=null){currentProcess.stop(StopEvent);}
			else{
				dispatchEvent(StopEvent);				
			}
		}
		
		public function list (directory:String=""):void{
			if(isConnected) invoke(new ListInv(this, directory));
		}
		
		public function login (user:String, pass:String):void{
			if(isConnected) invoke(new LoginInv(this, user, pass));
		}
		
		public function cwd (newDir:String):void{
			if(isConnected) invoke(new ChangeDirInv(this, newDir));
		}
		
		public function getFile (remoteFile:String, remoteFileSize:int, localFile:String, byteBegin:uint):void{
			if(isConnected) invoke(new DownloadInv(this, remoteFile, remoteFileSize, localFile, byteBegin));
		}
		
		public function putFile (localFile:String, remoteFile:String, byteBegin:uint):void{	
			if(isConnected) invoke(new UploadInv(this, localFile, remoteFile, byteBegin));
		}
		
		public function deleteFile (remoteFile:String, isDir:Boolean):void{			
			if(isConnected) invoke(new DeleteInv(this, remoteFile, isDir));
		}
		public function renameFile (remoteFile:String, new_name:String):void{			
			if(isConnected) invoke(new RenameInv(this, remoteFile, new_name));
		}
		public function createDir (dir_name:String):void{			
			if(isConnected) invoke(new CreateInv(this, dir_name));
		}
	}
}