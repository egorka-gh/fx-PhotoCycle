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

	public class CreateInv extends FTPInvoker
	{		
	
		private var dir_name:String;
		
		public function CreateInv(client:FTPClient, dir_name:String)
		{
			super(client);
			this.dir_name = dir_name;
		}
		
		override protected function startSequence ():void
		{
			try{		
			sendCommand(new FTPCommand(Commands.MKD, dir_name));				
			} catch(e:Error){
				releaseWithError(new InvokeError(e.message));
			}
		}
		
		override protected function responseHandler(evt:FTPEvent):void
		{
			switch (evt.response.code)
			{		
				case Responses.PATHNAME_CREATED:
					var createEvent:FTPEvent = new FTPEvent(FTPEvent.CREATE_DIR);
					release(createEvent);
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