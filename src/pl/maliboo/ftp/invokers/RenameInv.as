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

	public class RenameInv extends FTPInvoker
	{
		
		private var remoteFile:String;	
		private var new_name:String;
		
		public function RenameInv(client:FTPClient, remoteFile:String, new_name:String)
		{
			super(client);
			this.remoteFile = remoteFile;			
			this.new_name = new_name;
		}
		
		override protected function startSequence ():void
		{
			try{		
			sendCommand(new FTPCommand(Commands.RENAME_FROM, remoteFile));				
			} catch(e:Error){
				releaseWithError(new InvokeError(e.message));
			}
		}
		
		override protected function responseHandler(evt:FTPEvent):void
		{
			switch (evt.response.code)
			{
				case Responses.MORE_INFO:
					sendCommand(new FTPCommand(Commands.RENAME_TO, new_name));
					break;
				case Responses.FILE_ACTION_OK:
					var renameEvent:FTPEvent = new FTPEvent(FTPEvent.RENAME_FILE);
					release(renameEvent);
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