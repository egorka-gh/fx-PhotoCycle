package com.photodispatcher.model.mysql{
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.TimerEvent;
	import flash.utils.Timer;
	
	import mx.controls.Alert;
	
	import spark.formatters.DateTimeFormatter;
	
	[Event(name="complete", type="flash.events.Event")]
	[Event(name="cancel", type="flash.events.Event")]
	public class AsyncLatch extends EventDispatcher{
		public var complite:Boolean=false;
		public var hasError:Boolean=false;
		public var error:String;
		public var callContext:Object;

		public var debugName:String;
		public var silent:Boolean=true;
		public var lastTag:String;
		
		protected var thisComplite:Boolean=false;
		protected var joint:Array;
		protected var started:Boolean=false;

		public function AsyncLatch(silent:Boolean=false){
			super(null);
			this.silent=silent;
			joint=[];
		}
		
		protected var _timeout:int=0;
		public function set timeout(value:int):void{
			if(value>100){
				_timeout=value;
			}else{
				_timeout=0;
			}
		}
		
		public function join(latch:AsyncLatch):void{
			if(hasError || !latch || !joint) return;
			if(latch.complite) return;
			if(latch.hasError){
				releaseError(latch.error);
				return;
			}
			latch.silent=true;
			joint.push(latch);
			latch.addEventListener(Event.COMPLETE,onJoinComplite);
			latch.addEventListener(Event.CANCEL,onJoinCancel);
		}
		
		public function start():void{
			started=true;
			startTimer();
			checkComplite();
		}
		
		private var timer:Timer;
		protected function startTimer():void{
			if(_timeout<=0) return;
			if(!timer){
				timer= new Timer(_timeout,1);
				timer.addEventListener(TimerEvent.TIMER_COMPLETE, onTimeOut);
			}
			timer.reset();
			timer.start();
		}
		protected function stopTimer():void{
			if(timer) timer.reset();
		}
		protected function onTimeOut(event:TimerEvent):void{
			releaseError('Timeout');
		}
		
		public function get isStarted():Boolean{
			return started;
		}

		public function release():void{
			thisComplite=true;
			checkComplite();
		}

		public function stop():void{
			stopTimer();
			started=false;
		}

		public function reset():void{
			stopTimer();
			started=false;
			lastTag='';
			callContext=null;
			thisComplite=false;
			complite=false;
			hasError=false;
			error='';
			destroyJoint();
			dispatchEvent(new Event(Event.CANCEL));
		}

		public function releaseError(err:String):void{
			stopTimer();
			complite=false;
			hasError=true;
			error=err;
			trace((debugName?'Latch '+debugName+' error: ':'')+ error);
			destroyJoint();
			/*
			if(joint && joint.length>0){
				var latch:AsyncLatch;
				for each(latch in joint) latch.removeEventListener(Event.COMPLETE,onJoinComplite);
				joint=null;
			}
			*/
			if(started){
				dispatchEvent(new Event(Event.COMPLETE));
				if(!silent) showError();
			}
		}
		
		public function showError():void{
			var dtFmt:DateTimeFormatter= new DateTimeFormatter;
			dtFmt.dateTimePattern='dd.MM.yy HH:mm';
			var dtStr:String=dtFmt.format(new Date());
			dtStr=dtStr+': '+error;
			if(hasError) Alert.show(dtStr);
		}
		
		public function checkComplite():void{
			if(!started) return;
			if(hasError){
				stopTimer();
				started=false;
				dispatchEvent(new Event(Event.COMPLETE));
				if(!silent) showError();
				return;
			}
			complite=isComplite();
			if(complite){
				stopTimer();
				started=false;
				if(debugName) trace('Latch '+debugName+' complited. state' +(hasError?'error':'complite'));
				dispatchEvent(new Event(Event.COMPLETE));
			}
		}
		
		protected function isComplite():Boolean{
			return thisComplite && (!joint || joint.length==0);
		}
		
		protected function onJoinComplite(event:Event):void{
			var latch:AsyncLatch=event.target as AsyncLatch;
			if(latch){
				latch.removeEventListener(Event.COMPLETE,onJoinComplite);
				latch.removeEventListener(Event.COMPLETE,onJoinCancel);
				if(joint){
					var idx:int=joint.indexOf(latch);
					if(idx!=-1) joint.splice(idx,1);
				}
				if(latch.hasError){
					releaseError(latch.error);
				}else{
					checkComplite();
				}
			}
		}
		protected function onJoinCancel(event:Event):void{
			var latch:AsyncLatch=event.target as AsyncLatch;
			if(latch){
				latch.removeEventListener(Event.COMPLETE,onJoinComplite);
				latch.removeEventListener(Event.COMPLETE,onJoinCancel);
				if(joint){
					var idx:int=joint.indexOf(latch);
					if(idx!=-1) joint.splice(idx,1);
				}
				checkComplite();
			}
		}
		
		protected function destroyJoint():void{
			if(joint && joint.length>0){
				var latch:AsyncLatch;
				for each(latch in joint){
					latch.destroyJoint();
					latch.removeEventListener(Event.COMPLETE,onJoinComplite);
					latch.removeEventListener(Event.COMPLETE,onJoinCancel);
				}
				joint=null;
			}
		}
		
	}
}