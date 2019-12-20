package com.photodispatcher.service.web{
	import com.adobe.serialization.json.JSONDecoder;
	import com.photodispatcher.event.WebEvent;
	import com.photodispatcher.factory.OrderBuilder;
	import com.photodispatcher.model.mysql.AsyncLatch;
	import com.photodispatcher.model.mysql.entities.MailPackage;
	import com.photodispatcher.model.mysql.entities.Order;
	import com.photodispatcher.model.mysql.entities.Source;
	import com.photodispatcher.util.JsonUtil;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.HTTPStatusEvent;
	import flash.events.IEventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.net.URLRequestMethod;
	import flash.net.URLVariables;
	
	import spark.formatters.DateTimeFormatter;

	[Event(name="complete", type="flash.events.Event")]
	public class BaseWeb extends EventDispatcher{
		//commands
		protected static const CMD_SYNC:int=1;
		protected static const CMD_CHECK_STATE:int=2;
		protected static const CMD_SET_STATE:int=3;
		protected static const CMD_GET_PACKAGE:int=4;
		protected static const CMD_JOIN_PACKAGE:int=5;
		protected static const CMD_SET_PACKAGE_STATE:int=6;
		
		protected static const CMD_SYNC_LDR:int=7;
		protected static const CMD_GET_ORDER_LDR:int=8;
		protected static const CMD_SET_ORDER_LDR_STATE:int=9;
		protected static const CMD_SYNC_ACTIVE_LDR:int=10;
		//protected static const CMD_SYNC_RESTART_LDR:int=11;

		protected static const CMD_GET_INFO_SYNC:int=11;
		protected static const CMD_GET_INFO_LOADER:int=12;

		[Bindable]
		public var isRunning:Boolean=false;

		public var source:Source;
		//raw orders
		public var orderes:Array;
		
		public var latch:AsyncLatch;

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
		
		protected var errCodes:Array;
		public function hasErrCode(code:int):Boolean{
			if(!errCodes || errCodes.length==0) return false;
			for each(var err:int in errCodes){
				if (err==code) return true;
			}
			return false;
		}
		
		protected var lastPackageId:int;
		protected var lastPackage:MailPackage;
		public function getLastMailPackage():MailPackage{
			return lastPackage;
		}
		
		public function getJoinResultId():int{
			return joinResultId;
		}
		
		protected var client:WebClient;
		protected var baseUrl:String;
		protected var appKey:String;

		public function BaseWeb(source:Source){
			super(null);
			this.source=source;
			if(source && source.webService){
				baseUrl=source.webService.url;
				appKey=source.webService.appkey;
			}
		}

		public function sync():void{
			throw new Error("You need to override sync() in your concrete class");
		}

		public function syncLoad():void{
			throw new Error("You need to override syncLoad() in your concrete class");
		}
		public function getLoaderOrder(order:Order):void{
			throw new Error("You need to override syncLoad() in your concrete class");
		}
		public function setLoaderOrderState(order:Order):void{
			throw new Error("You need to override setLoaderOrderState() in your concrete class");
		}
		public function syncActiveLoader():void{
			throw new Error("You need to override syncActiveLoader() in your concrete class");
		}
		/*
		public function syncRestarLoader():void{
			throw new Error("You need to override syncRestarLoader() in your concrete class");
		}
		*/
		
		public function get lastOrderId():String{
			throw new Error("You need to override lastOrderId() in your concrete class");
		}
		public function getOrder(order:Order):void{
			throw new Error("You need to override getOrder() in your concrete class");
		}
		public function getMailPackage(packageId:int):void{
			throw new Error("You need to override getMailPackage() in your concrete class");
		}
		protected var joinIds:Array;
		protected var joinResultId:int;
		public function joinMailPackages(ids:Array):void{
			throw new Error("You need to override joinMailPackages() in your concrete class");
		}

		protected var packageId:int;
		protected var packageState:int;
		protected var forceState:Boolean;
		public function setMailPackageState(id:int, state:int, force:Boolean):void{
			throw new Error("You need to override setMailPackageState() in your concrete class");
		}
		
		protected function logErr(errMsg:String):void{
			if(!source) return;
			var path:String=source.getWrkFolder();
			var file:File=new File(path);
			if(!file.exists || !file.isDirectory) return;
			file=file.resolvePath('log');
			if(!file.exists) file.createDirectory();
			if(!file.isDirectory) return;
			
			var dt:Date= new Date();
			var fmt:DateTimeFormatter= new DateTimeFormatter();
			fmt.dateTimePattern='yy-MM-dd_HH-mm-ss';
			var fname:String=fmt.format(dt)+'.txt';
			file=file.resolvePath(fname);
			var fs:FileStream = new FileStream();
			try {
				fs.open(file, FileMode.APPEND);
				fs.writeUTFBytes(errMsg + File.lineEnding);
				fs.writeUTFBytes('------------------------------------'+ File.lineEnding);
				if(lastRawData){
					var s:String=(lastRawData as String);
					if(s) fs.writeUTFBytes(s + File.lineEnding);
					fs.writeUTFBytes('------------------------------------'+ File.lineEnding);
				}
				fs.close();
			} catch(e:Error) {
				trace("FATAL:: Unable to write to log file.");
			}
		}
		
		protected function abort(errMsg:String):void{
			_hasError=true;
			_errMesage=errMsg;
			stopListen();
			logErr(errMsg);
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
			//build orders
			orderes=OrderBuilder.build(source,orderes,true);
			dispatchEvent(new Event(Event.COMPLETE));
		}
		protected function endGetOrder():void{
			trace('BaseWeb order loaded.');
			_hasError=false;
			_errMesage='';
			stopListen();
			if (orderes && orderes.length>0){
				var arr:Array=OrderBuilder.build(source,orderes);
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
		protected var lastRawResult:Object;
		protected function parseRaw(raw:Object):Object{
			lastRawData=raw;
			lastRawResult =null;
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
			lastRawResult = result.result;
			return result;
		}
		
		public function get RawResult():Object{
			return lastRawResult; 
		}

		protected function getErr(raw:Object):String{
			errCodes=[];
			var result:String='';
			var key:*;
			var obj:Object;
			if (raw && raw.error){
				if(raw.error is String){
					result=raw.error;
				}else{
					for (key in raw.error){
						if(raw.error[key] is String){
							if(result) result+= '\n';
							result+=raw.error[key];
						}else{
							obj=raw.error[key];
							if(obj.hasOwnProperty('value')) errCodes.push(int(obj.value));
							if(obj.hasOwnProperty('title')){
								if(result) result+= '\n';
								result+=obj.title as String;
							}
						}
					}
				}
			}
			if(!result) result='Ошибка структуры данных';
			return result;
		}

	}
}