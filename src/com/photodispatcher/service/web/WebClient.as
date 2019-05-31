package com.photodispatcher.service.web{
	import com.photodispatcher.event.WebEvent;
	import com.photodispatcher.model.mysql.entities.Source;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.HTTPStatusEvent;
	import flash.events.IEventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.TimerEvent;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.net.URLRequestMethod;
	import flash.net.URLVariables;
	import flash.utils.Timer;
	
	[Event(name="response", type="com.photodispatcher.event.WebEvent")]
	[Event(name="invokeError", type="com.photodispatcher.event.WebEvent")]
	[Event(name="logged", type="com.photodispatcher.event.WebEvent")]
	public class WebClient extends EventDispatcher{
		
		//raw orders
		public var orderes:Array;
		public var httpStatus:int; //not correct? last http status if adobe can get it

		private var urlLoader:URLLoader;

		private var processing:Boolean = false;
		private var currentProcess:WebInvoker;

		public function WebClient(){
			urlLoader= new URLLoader();
			urlLoader.addEventListener(IOErrorEvent.IO_ERROR,handleErr);
			urlLoader.addEventListener(SecurityErrorEvent.SECURITY_ERROR,handleSecErr);
			urlLoader.addEventListener(HTTPStatusEvent.HTTP_RESPONSE_STATUS, handleResponceStatus);
			urlLoader.addEventListener(Event.COMPLETE,handleComplete);
		}

		private function handleErr(e:IOErrorEvent):void{
			//abort(e.text);
			processing = false;
			stopTimer();
			trace('WebClient IOError: '+e.text)
			var ev:WebEvent=new WebEvent(WebEvent.RESPONSE);
			ev.response=Responses.SERVICE_ERROR;
			ev.error=e.text;
			dispatchEvent(ev);
			return;
		}
		private function handleSecErr(e:SecurityErrorEvent):void{
			//abort(e.text);
			processing = false;
			stopTimer();
			trace('WebClient SecurityError: '+e.text)
			var ev:WebEvent=new WebEvent(WebEvent.RESPONSE);
			ev.response=Responses.SERVICE_ERROR;
			ev.error=e.text;
			dispatchEvent(ev);
			return;
		}
		private function handleResponceStatus(e:HTTPStatusEvent):void{
			httpStatus=e.status;
			var ev:WebEvent=new WebEvent(WebEvent.RESPONSE);
			ev.response=Responses.HTTP_STATUS;
			ev.responseURL=e.responseURL;
			dispatchEvent(ev);
		}
		private function handleComplete(e:Event):void{
			processing = false;
			stopTimer();
			var ev:WebEvent=new WebEvent(WebEvent.RESPONSE);
			ev.response=Responses.COMPLETE;
			ev.data=urlLoader.data;
			dispatchEvent(ev);
		}
		private function onTimer(e:TimerEvent):void{
			//abort(e.text);
			stopTimer();
			processing = false;
			var ev:WebEvent=new WebEvent(WebEvent.RESPONSE);
			ev.response=Responses.TIMEOUT_ERROR;
			trace('WebClient timeout.')
			ev.error='Таймаут веб запроса';
			dispatchEvent(ev);
			return;
		}
		private function stopTimer():void{
			if(timer){
				if(timer.running) timer.stop();
				timer.removeEventListener(TimerEvent.TIMER, onTimer);
				timer=null;
			}
		}

		private var timer:Timer;

		private function invoke (invoker:WebInvoker):void{
			if (currentProcess) return;
			httpStatus=0;
			currentProcess = invoker;
			if (currentProcess.timeout>0){
				timer= new Timer(currentProcess.timeout*1000,1);
				timer.addEventListener(TimerEvent.TIMER, onTimer);
				timer.start();
			}
			invoker.execute();
		}

		
		internal function finalizeCurrentProcess(evt:Event):void{
			processing = false;
			currentProcess = null;
			stopTimer();
			if (evt != null){
				dispatchEvent(evt);			
			}
		}

		internal function sendRequest(url:String, postData:Object = null):Boolean{
			if (processing) return false;
			processing = true;

			var urlRequest : URLRequest = new URLRequest(url);
			var urlVariables:URLVariables = new URLVariables();
			if(postData){
				for (var vars:* in postData){
					urlVariables[vars] = postData[vars];
				}
			}
			urlRequest.method = URLRequestMethod.POST
			urlRequest.data = urlVariables;
			urlLoader.load(urlRequest);

			return true;
		}

		public function login(url:InvokerUrl, post:Object):void{
			invoke(new LoginInv(this,url,post));
		}

		public function getData(url:InvokerUrl, post:Object):void{
			invoke(new DataInv(this,url,post,60));//imeout - 60s 
		}

		public function sendData(url:InvokerUrl, post:Object):void{
			invoke(new DataInv(this,url,post,10));//imeout - 10s 
		}

	}
}