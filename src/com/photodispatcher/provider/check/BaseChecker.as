package com.photodispatcher.provider.check{
	import com.photodispatcher.model.mysql.entities.Order;
	
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	
	[Event(name="complete", type="flash.events.Event")]
	[Event(name="progress", type="flash.events.ProgressEvent")]
	public class BaseChecker extends EventDispatcher{
		
		public var hasError:Boolean;
		public var error:String;
		[Bindable]
		public var progressCaption:String='';

		protected var currOrder:Order;

		public function get currentOrder():Order{
			return currOrder;
		}
		
		protected  var _isBusy:Boolean;
		public function get isBusy():Boolean{
			return _isBusy;
		}

		/*
		init after stop or before first call
		*/
		public function init():void{
			throw new Error("You need to override init() in your concrete class");
		}

		public function check(order:Order):void{
			throw new Error("You need to override start() in your concrete class");
		}

		public function stop():void{
			reset();
			currOrder=null;
			_isBusy=false;
		}
		
		/*
		*reset between iterrations
		*/
		protected function reset():void{
			throw new Error("You need to override reset() in your concrete class");
		}


		public function BaseChecker(){
			super(null);
		}
		
		
	}
}