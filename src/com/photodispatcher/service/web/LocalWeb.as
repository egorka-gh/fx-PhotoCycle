package com.photodispatcher.service.web
{
	import com.adobe.serialization.json.JSONEncoder;
	import com.photodispatcher.context.Context;
	import com.photodispatcher.event.WebEvent;
	
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	
	import spark.formatters.DateTimeFormatter;
	
	
	[Event(name="response", type="com.photodispatcher.event.WebEvent")]
	public class LocalWeb  extends EventDispatcher{
		//public static const ACTION_SCAN:String = 'scans';
		public static const ACTION_GLUE:String = 'glue';
		
		public static const TASK_ORDER_COMPLETE:String = 'item-complete';
		
		public var isRunning:Boolean=false;

		protected var client:WebClient;
		protected var baseUrl:String;
		protected  var queue:Array;
		protected var currentAction:LocalWebAction;

		public function LocalWeb(baseUrl:String=null){
			super(null);
			this.baseUrl=baseUrl;
			queue= new Array();
		}

		
		public function sendOrderComplite(techPointName:String, orderId:String):void{
			//curl -d "action=scans&task=item-complete&data={"batch_item_id":17988121,"order_number":568664}" -X POST http://core.localdev/?r=interface-succession-stage/api
			
			var data:String =new JSONEncoder( {item_id: orderId} ).getString();
			if(!techPointName) techPointName=TASK_ORDER_COMPLETE;
			//var action:LocalWebAction = new LocalWebAction(techPointName, TASK_ORDER_COMPLETE, data);
			var action:LocalWebAction = new LocalWebAction(ACTION_GLUE, techPointName, data);
			queue.push(action);
			startNext();
		}
		
		private function startNext():void{
			if(queue.length==0) return;
			if(isRunning) return;
			currentAction = queue.shift() as LocalWebAction;
			while( !currentAction && queue.length>0) currentAction = queue.shift() as LocalWebAction;
			startListen();
			//trace('LocalWeb sendBookComplite '+currentAction.data);
			client.sendData( new InvokerUrl(baseUrl), currentAction.toPostObject());
		}
		
		protected function startListen():void{
			isRunning=true;
			if(!client) client=new WebClient();
			client.addEventListener(WebEvent.INVOKE_ERROR,handleErr);
			client.addEventListener(WebEvent.DATA,handleData);
		}
		protected function stopListen():void{
			isRunning=false;
			if(client){
				client.removeEventListener(WebEvent.INVOKE_ERROR,handleErr);
				client.removeEventListener(WebEvent.DATA,handleData);
			}
		}
		
		protected function handleErr(e:WebEvent):void{
			stopListen();
			if(currentAction){
				currentAction.hasError=true;
				currentAction.error = e.error;
				currentAction.httpStatus=client.httpStatus;
			}
			var evt:WebEvent = new WebEvent(WebEvent.RESPONSE);
			evt.response=Responses.SERVICE_ERROR;
			evt.error=e.error;
			evt.data=currentAction;
			dispatchEvent(evt);
			logError(e.error);
			startNext();
		}
		
		private function logError(err:String):void{
			var path:String= Context.getAttribute("WebLogPath");
			if(!path) return;
			var folder:File = new File(path);
			if (!folder.exists || !folder.isDirectory) return;
			var df:DateTimeFormatter = new DateTimeFormatter();
			df.dateTimePattern ="yyyy-MM-dd";
			
			folder = folder.resolvePath(df.format(new Date())+'.log');
			df.dateTimePattern="yyyy-MM-dd HH:mm:ss";
			var str:String = df.format(new Date())+': Error:'+ err;
			if(currentAction){
				str=str+'; '+currentAction.toString(); 
			}
			str=str+'\n';
			try
			{
				var fileStream:FileStream = new FileStream();
				fileStream.open(folder, FileMode.APPEND);
				fileStream.writeUTFBytes(str);
				fileStream.close();
			} 
			catch(error:Error) 
			{
				var evt:WebEvent = new WebEvent(WebEvent.RESPONSE);
				evt.response=Responses.SERVICE_ERROR;
				evt.error='Ошибка записи в лог: '+ error.message;
				dispatchEvent(evt);
			}
		}

		protected function handleData(e:WebEvent):void{
			stopListen();
			if(currentAction){
				currentAction.httpStatus=client.httpStatus;
				currentAction.responce = (e.data as String);
			}
			var evt:WebEvent = new  WebEvent(WebEvent.RESPONSE);
			evt.response=Responses.COMPLETE;
			evt.data=currentAction;
			dispatchEvent(evt);
			startNext();
		}

	}
}
