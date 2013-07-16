package com.photodispatcher.event{
	import flash.events.Event;
	
	public class WebEvent extends Event{
		public static const RESPONSE:String 	= "response";
		public static const INVOKE_ERROR:String = "invokeError";
		public static const SERVICE_ERROR:String = "serviceError";
		public static const LOGGED:String 		= "logged";
		public static const DATA:String 		= "data";

		public var response:int;
		public var responseURL:String;
		public var data:Object;
		public var error:String;
		
		public function WebEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false){
			super(type, bubbles, cancelable);
		}

		override public function clone():Event{
			var e:WebEvent = new WebEvent(type, bubbles, cancelable);
			e.response=response;
			e.responseURL=responseURL;
			e.data=data;
			return e as Event;
		}

	}
}