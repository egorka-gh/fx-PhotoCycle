package pl.maliboo.ftp.invokers
{
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	
	//import mx.controls.Alert;
	
	import pl.maliboo.ftp.Commands;
	import pl.maliboo.ftp.FTPCommand;
	import pl.maliboo.ftp.Responses;
	import pl.maliboo.ftp.core.FTPClient;
	import pl.maliboo.ftp.core.FTPInvoker;
	import pl.maliboo.ftp.errors.InvokeError;
	import pl.maliboo.ftp.events.FTPEvent;


	public class DeleteInv extends FTPInvoker
	{
		
		private var remoteFile:String;	
		private var isDir:Boolean;
		
		public function DeleteInv(client:FTPClient, remoteFile:String, isDir:Boolean)
		{
			super(client);
			this.remoteFile = remoteFile;	
			this.isDir=isDir;
		}
		
		override protected function startSequence ():void
		{
			try{	
			if(!isDir){
			sendCommand(new FTPCommand(Commands.DELETE_FILE, remoteFile));
			} else {
				sendCommand(new FTPCommand(Commands.DELETE_DIR, remoteFile));	
			}
			} catch(e:Error){
				releaseWithError(new InvokeError(e.message));
			}
		}
		
		override protected function responseHandler(evt:FTPEvent):void
		{
			switch (evt.response.code)
			{
				case Responses.FILE_ACTION_OK:
					var deleteEvent:FTPEvent = new FTPEvent(FTPEvent.DELETE_FILE);
					release(deleteEvent);
					break;				
				default:
					releaseWithError(new InvokeError(evt.response.message));
			}	
		}		
	
		
		override protected function cleanUp ():void
		{
		}
		
	}
}