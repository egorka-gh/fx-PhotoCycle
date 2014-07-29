package com.photodispatcher.service.web{
	import com.adobe.serialization.json.JSONDecoder;
	import com.photodispatcher.event.WebEvent;
	import com.photodispatcher.factory.OrderBuilder;
	import com.photodispatcher.model.Order;
	import com.photodispatcher.model.mysql.entities.Source;
	import com.photodispatcher.util.JsonUtil;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.HTTPStatusEvent;
	import flash.events.IEventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.net.URLRequestMethod;
	import flash.net.URLVariables;

	[Event(name="complete", type="flash.events.Event")]
	public class BaseWeb extends EventDispatcher{
		//commands
		protected static const CMD_SYNC:int=1;
		protected static const CMD_CHECK_STATE:int=2;
		protected static const CMD_SET_STATE:int=3;

		public var isRunning:Boolean=false;

		public var source:Source;
		//raw orders
		public var orderes:Array;

		protected var cmd:int;
		//last order (from get order) 
		protected var lastOrder:Order;
		public function getLastOrder():Order{
			return lastOrder;
		}

		protected var _hasError:Boolean;
		public function get hasError():Boolean{
			return _hasError;
		}

		protected var _errMesage:String;
		public function get errMesage():String{
			return _errMesage;
		}
		
		protected var client:WebClient;
		protected var baseUrl:String;

		public function BaseWeb(source:Source){
			super(null);
			this.source=source;
			if(source && source.webService) baseUrl=source.webService.url;
		}

		public function sync():void{
			throw new Error("You need to override sync() in your concrete class");
		}

		public function get lastOrderId():String{
			throw new Error("You need to override sync() in your concrete class");
		}
		public function getOrder(order:Order):void{
			throw new Error("You need to override getOrder() in your concrete class");
		}
		
		protected function abort(errMsg:String):void{
			_hasError=true;
			_errMesage=errMsg;
			stopListen();
			dispatchEvent(new Event(Event.COMPLETE));
		}
		protected function startListen():void{
			isRunning=true;
			if(!client) client=new WebClient();
			client.addEventListener(WebEvent.INVOKE_ERROR,handleErr);
			client.addEventListener(WebEvent.LOGGED,handleLogin);
			client.addEventListener(WebEvent.DATA,handleData);
		}
		protected function stopListen():void{
			isRunning=false;
			if(client){
				client.removeEventListener(WebEvent.INVOKE_ERROR,handleErr);
				client.removeEventListener(WebEvent.LOGGED,handleLogin);
				client.removeEventListener(WebEvent.DATA,handleData);
			}
		}

		protected function handleErr(e:WebEvent):void{
			abort(e.error);
		}
		
		protected function handleLogin(e:Event):void{
			throw new Error("You need to override handleLogin() in your concrete class");
		}
		
		protected function handleData(e:WebEvent):void{
			throw new Error("You need to override getOrder() in your concrete class");
		}

		public function isValidLastOrder(forLoad:Boolean=false):Boolean{
			throw new Error("You need to override handleData() in your concrete class");
		}
		
		protected function endSync():void{
			trace('BaseWeb completed. Заказов: '+orderes.length);
			_hasError=false;
			_errMesage='';
			stopListen();
			dispatchEvent(new Event(Event.COMPLETE));
		}
		protected function endGetOrder():void{
			trace('BaseWeb order loaded.');
			_hasError=false;
			_errMesage='';
			stopListen();
			var ob:OrderBuilder= new OrderBuilder();
			if (orderes && orderes.length>0){
				var arr:Array=ob.build(source,orderes);
				if(arr && arr.length>0){
					lastOrder=arr[0];
					trace('BaseWeb loaded order id:'+lastOrder.ftp_folder);
				}else{
					trace('BaseWeb read lock');
					abort('Блокировка чтения (json map)');
					return;
				}
			}else{
				trace('BaseWeb empty respose order id:'+lastOrderId);
			}
			dispatchEvent(new Event(Event.COMPLETE));
		}

		protected var lastRawData:Object;
		protected function parseOrders(raw:Object):Object{
			lastRawData=raw;
			var s:String=(raw as String);
			if(!raw ||!s){
				abort('Ошибка полученных данных');
				return null;
			}
			var result:Object;
			try {
				//result=new JSONDecoder(s,true).getValue();
				result=JsonUtil.decode(s,true);
			} catch (e:Error){
				abort('Ошибка декодирования данных. '+e.message);
				return null;
			}
			return result;
		}

	}
}