package pl.maliboo.ftp.invokers
{	
	import pl.maliboo.ftp.Commands;
	import pl.maliboo.ftp.FTPCommand;
	import pl.maliboo.ftp.Responses;
	import pl.maliboo.ftp.core.FTPClient;
	import pl.maliboo.ftp.core.FTPInvoker;
	import pl.maliboo.ftp.errors.FTPError;
	import pl.maliboo.ftp.errors.InvokeError;
	import pl.maliboo.ftp.events.FTPEvent;

	public class LoginInv extends FTPInvoker
	{
		private var user:String;
		private var pass:String;

		private var passSend:Boolean;
		
		public function LoginInv(client:FTPClient, user:String, pass:String)
		{
			super(client);
			this.user = user;
			this.pass = pass;
		}
		
		override protected function startSequence ():void
		{
			sendCommand(new FTPCommand(Commands.USER, user));
			passSend=false;
		}
		
		override protected function responseHandler(evt:FTPEvent):void
		{
			switch (evt.response.code)
			{
				case Responses.USER_OK:
					if(!passSend){
						passSend=true;
						sendCommand(new FTPCommand(Commands.PASS, pass));
					}
					break;
				case Responses.LOGGED_IN:				
					var logEvent:FTPEvent = new FTPEvent(FTPEvent.LOGGED);
					logEvent.hostname = client.hostname;
					release(logEvent);
				case Responses.SERVICE_READY:
					/* info msg ignore
					if(!passSend){
						passSend=true;
						sendCommand(new FTPCommand(Commands.PASS, pass));
					}
					*/
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