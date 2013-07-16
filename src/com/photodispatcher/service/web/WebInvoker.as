package com.photodispatcher.service.web{
	import com.photodispatcher.event.WebEvent;
	
	import flash.events.Event;
	import flash.net.URLRequest;

	public class WebInvoker{
		public static const INVOK_TIMEOUT:int=10;//sek

		protected var client:WebClient;
		
		public var timeout:int=INVOK_TIMEOUT;

		public function WebInvoker(client:WebClient){
			this.client=client;
			client.addEventListener(WebEvent.RESPONSE,responseHandler);
		}

		//virtual methods
		protected function responseHandler(evt:WebEvent):void{
			throw new Error("FTPInvoker virtual method");
		}
		
		protected function startSequence():void{
			throw new Error("FTPInvoker virtual method");
		}
		
		protected function cleanUp ():void{	
			throw new Error("FTPInvoker virtual method");
		}
		
		final internal function execute ():void{
			startSequence();
		}

		/**
		 * Sends request to server
		 */ 
		protected function sendRequest(url:String, postData:Object = null):Boolean{
			return client.sendRequest(url,postData);
		}

		/**
		 * Releases current process from executing sequence
		 */ 
		final protected function release(evt:Event):void{
			finalize();
			client.finalizeCurrentProcess(evt);
		}
		
		/**
		 * Stop current process
		 */ 
		public function stop(evt:WebEvent):void{			
			finalize();
			client.finalizeCurrentProcess(evt);
		}
		
		/**
		 * Releases current process from executing sequence with error
		 */ 
		protected function releaseWithError(err:String):void{
			var evt:WebEvent = new WebEvent(WebEvent.INVOKE_ERROR);
			evt.error = err;
			release(evt);
		}
		
		/**
		 * Finalizes command sequence. Releases invoker from client listening
		 * 
		 */ 
		internal function finalize():void{
			cleanUp();
			client.removeEventListener(WebEvent.RESPONSE, responseHandler);
		}

	}
}