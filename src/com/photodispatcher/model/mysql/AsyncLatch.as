package com.photodispatcher.model.mysql{
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	
	import mx.controls.Alert;
	
	[Event(name="complete", type="flash.events.Event")]
	public class AsyncLatch extends EventDispatcher{
		public var complite:Boolean=false;
		public var hasError:Boolean=false;
		public var error:String;
		
		public var debugName:String;
		public var silent:Boolean=true;
		
		protected var thisComplite:Boolean=false;
		protected var joint:Array;
		protected var started:Boolean=false;

		public function AsyncLatch(silent:Boolean=false){
			super(null);
			this.silent=silent;
			joint=[];
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
		}
		
		public function start():void{
			started=true;
			checkComplite();
		}
		
		public function get isStarted():Boolean{
			return started;
		}

		public function release():void{
			thisComplite=true;
			checkComplite();
		}

		public function releaseError(err:String):void{
			complite=false;
			hasError=true;
			error=err;
			trace((debugName?'Latch '+debugName+' error: ':'')+ error);
			if(joint && joint.length>0){
				var latch:AsyncLatch;
				for each(latch in joint) latch.removeEventListener(Event.COMPLETE,onJoinComplite);
				joint=null;
			}
			if(started){
				dispatchEvent(new Event(Event.COMPLETE));
				if(!silent) showError();
			}
		}
		
		public function showError():void{
			if(hasError) Alert.show(error);
		}
		
		public function checkComplite():void{
			if(!started) return;
			if(hasError){
				dispatchEvent(new Event(Event.COMPLETE));
				if(!silent) showError();
				return;
			}
			complite=isComplite();
			if(complite){
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
				var idx:int=joint.indexOf(latch);
				if(idx!=-1) joint.splice(idx,1);
				if(latch.hasError){
					releaseError(latch.error);
				}else{
					checkComplite();
				}
			}
		}
		
	}
}