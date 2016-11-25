package com.photodispatcher.tech.picker{
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.TimerEvent;
	import flash.utils.Timer;

	[Event(name="complete", type="flash.events.Event")]
	[Event(name="error", type="flash.events.ErrorEvent")]
	public class PickerLatch extends EventDispatcher{
		public static const TYPE_ACL:int			=0;
		public static const TYPE_LAYER_IN:int		=1;
		public static const TYPE_LAYER_OUT:int		=2;
		public static const TYPE_BARCODE:int		=3;
		public static const TYPE_REGISTER:int		=4;
		public static const TYPE_BD:int				=5;
		public static const TYPE_PRESSOFF:int		=6;

		
		[Bindable]
		public var caption:String='';
		[Bindable]
		public var label:String='';

		private var _isOn:Boolean;
		[Bindable(event="isOnChange")]
		public function get isOn():Boolean{
			return _isOn;
		}

		private var _type:int;
		private var steps:int;
		private var _step:int;
		public function get step():int{
			return _step;
		}
		private var defaultCaption:String;
		private var timeout:int;
		private var timer:Timer;

		public var layer:int;
		public var startingTray:int;
		

		
		public function PickerLatch(type:int, steps:int=1, label:String='', defaultCaption:String='', timeout:int=100){
			super(null);
			_type=type;
			this.steps=steps;
			this.defaultCaption=defaultCaption;
			this.timeout=timeout;
			this.label=label;
			_isOn=false;
			_step=0;
		}
		
		public function get type():int{
			return _type;
		}
		
		public function setTimeout(value:int):void{
			timeout=value;
			if(timeout<=0){
				if(timer){
					timer.stop();
					timer.removeEventListener(TimerEvent.TIMER, onTimer);
					timer=null;
				}
			}else{
				if(!timer){
					timer= new Timer(timeout,0);
					timer.addEventListener(TimerEvent.TIMER, onTimer);
				}else{
					timer.delay=timeout;
				}
			}
		}
		
		public function getTimeout():int{
			return timeout;
		}
		
		public function setOn():void{
			_step=0;
			caption=defaultCaption;
			_isOn=true;
			dispatchEvent( new Event('isOnChange'));
			if(timeout>0){
				if(!timer){
					timer= new Timer(timeout,0);
					timer.addEventListener(TimerEvent.TIMER, onTimer);
				}else{
					timer.reset();//?
				}
				timer.start();
			}
		}

		public function forward(stateCaption:String=''):void{
			if(!isOn) return;
			caption=stateCaption;
			_step++;
			if(step>=steps){
				timer.reset();
				caption='';
				_isOn=false;
				dispatchEvent( new Event(Event.COMPLETE));
				dispatchEvent( new Event('isOnChange'));
			}
		}

		public function reset():void{
			if(timer) timer.reset();
			_step=0;
			caption='';
			_isOn=false;
			dispatchEvent( new Event('isOnChange'));
		}

		public function onTimer(evt:TimerEvent):void{
			dispatchEvent(new ErrorEvent(ErrorEvent.ERROR,false,false,'timeout'));
		}
	}
}