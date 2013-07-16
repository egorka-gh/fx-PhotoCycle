package pl.maliboo.ftp.core
{
	import flash.events.Event;
	import flash.events.TimerEvent;
	import flash.utils.Timer;
	
	import pl.maliboo.ftp.Commands;
	import pl.maliboo.ftp.FTPCommand;
	import pl.maliboo.ftp.errors.FTPError;
	import pl.maliboo.ftp.errors.InvokeError;
	import pl.maliboo.ftp.errors.InvokeTimeoutError;
	import pl.maliboo.ftp.events.FTPEvent;
	
	/**
	 * Base class for all server actions (command sequences)
	 */ 
	public class FTPInvoker{
		
		public static const DEFAULT_TIMEOUT:int=30000;
		
		protected var client:FTPClient;
		
		protected var timeoutTimer:Timer;
		
		public function FTPInvoker (client:FTPClient)
		{
			this.client = client;
			client.addEventListener(FTPEvent.RESPONSE, responseHandler);
			//CursorManager.setBusyCursor();
		}
		
		/**
		 * Sends command to server
		 */ 
		protected function sendCommand(command:FTPCommand):Boolean
		{
			return client.sendPartCommand(command);
		}
		
		/**
		 * Response event handler
		 */ 
		protected function responseHandler(evt:FTPEvent):void
		{
			throw new Error("FTPInvoker virtual method");
		}
		
		/**
		 * Starts command sequence executing
		 */ 
		final internal function execute ():void
		{
			startSequence();
		}
		
		/**
		 * Pseudo virtual method to override. Starts command sequense for subclasses
		 */ 
		protected function startSequence():void
		{
			throw new Error("FTPInvoker virtual method");
		}
		
		/**
		 * Make final clean up
		 * 
		 */ 
		protected function cleanUp ():void
		{	
			throw new Error("FTPInvoker virtual method");
		}

		protected var aborted:Boolean=false;
		/**
		 * invoker aborted
		 * release lockal resourses
		 * 
		 */ 
		public function abort():void{
			aborted=true;
			//throw new Error("FTPInvoker virtual method");
		}

		/**
		 * Releases current process from executing sequence
		 */ 
		final protected function release(evt:Event):void
		{
			finalize();
			//CursorManager.removeBusyCursor();
			client.finalizeCurrentProcess(evt);
			
		}
		
		/**
		 * Stop current process
		 */ 
		public function stop(evt:FTPEvent):void
		{			
			finalize();
			//CursorManager.removeBusyCursor();
			client.finalizeCurrentProcess(evt);
			
		}
		
		/**
		 * Releases current process from executing sequence with error
		 */ 
		protected function releaseWithError(err:FTPError):void
		{
			var evt:FTPEvent = new FTPEvent(FTPEvent.INVOKE_ERROR);
			evt.error = err;
			release(evt);
		}
		
		/**
		 * Finalizes command sequence. Releases invoker from client listening
		 * 
		 */ 
		internal function finalize():void
		{
			stopTimeoutTimer();
			cleanUp();
			client.removeEventListener(FTPEvent.RESPONSE, responseHandler);
		}
		
		protected function startTimeoutTimer(timeout:int=DEFAULT_TIMEOUT):void{
			if(timeoutTimer){
				timeoutTimer.removeEventListener(TimerEvent.TIMER, onTimer);
			}
			timeoutTimer= new Timer(timeout,1);
			timeoutTimer.addEventListener(TimerEvent.TIMER, onTimer);
			timeoutTimer.start();
		}
		protected function resetTimeoutTimer():void{
			if(timeoutTimer && timeoutTimer.running){
				timeoutTimer.reset();
				timeoutTimer.start();
			}
		}
		protected function stopTimeoutTimer():void{
			if(timeoutTimer){
				if(timeoutTimer.running) timeoutTimer.reset();
				timeoutTimer.removeEventListener(TimerEvent.TIMER, onTimer);
				timeoutTimer=null;
			}
		}
		
		protected function onTimer(e:TimerEvent):void{
			releaseWithError(new InvokeTimeoutError('Timeout операции'));
		}
	}
}