package com.photodispatcher.model.mysql
{
	import com.photodispatcher.model.mysql.entities.SqlResult;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.utils.getTimer;
	
	import mx.rpc.AsyncResponder;
	import mx.rpc.AsyncToken;
	import mx.rpc.events.FaultEvent;
	import mx.rpc.events.ResultEvent;
	
	[Event(name="complete", type="flash.events.Event")]
	public class DbLatch extends EventDispatcher{
		
		public var complite:Boolean=false;
		public var lastResult:SqlResult;
		public var hasError:Boolean=false;
		public var error:String;

		private var latches:Array;
		private var joint:Array;
		private var started:Boolean=false;
		
		public function DbLatch(){
			super(null);
			latches=[];
			joint=[];
		}
		
		public function addLatch(token:AsyncToken):void{
			if(hasError ||!token || !latches) return;
			var latch:int=getTimer();
			token.latch=latch;
			latches.push(latch);
			token.addResponder(new AsyncResponder(resultHandler, faultHandler));
		}

		public function join(latch:DbLatch):void{
			if(hasError || !latch || !joint) return;
			if(latch.complite) return;
			if(latch.hasError){
				releaseError(latch.error);
				return;
			}
			joint.push(latch);
			latch.addEventListener(Event.COMPLETE,onJoinComplite);
		}

		public function start():void{
			/*
			if(joint && joint.length>0){
				var latch:DbLatch;
				for each(latch in joint){
					if(!latch.isStarted) latch.start();
				}
			}
			*/
			started=true;
			checkComplite();
		}
		
		public function get isStarted():Boolean{
			return started;
		}

		public function releaseError(err:String):void{
			complite=false;
			hasError=true;
			error=err;
			trace(error);
			latches=null;
			if(joint && joint.length>0){
				var latch:DbLatch;
				for each(latch in joint) latch.removeEventListener(Event.COMPLETE,onJoinComplite);
				joint=null;
			}
			if(started) dispatchEvent(new Event(Event.COMPLETE));
	
		}
		
		public function checkComplite():void{
			if(!started) return;
			if(hasError){
				dispatchEvent(new Event(Event.COMPLETE));
			}else if((!latches || latches.length==0) && (!joint || joint.length==0)){
				complite=true;
				dispatchEvent(new Event(Event.COMPLETE));
			}
		}
		
		private function onJoinComplite(event:Event):void{
			var latch:DbLatch=event.target as DbLatch;
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
		
		private function resultHandler(event:ResultEvent, token:AsyncToken=null):void{
			if(!latches) return;
			var latch:int=event.token.latch;
			
			//check for sql error
			lastResult=event.result.result as SqlResult;
			if(lastResult){
				if(!lastResult.complete){
					releaseError('DbLatch SQL error: code-' +lastResult.errCode.toString() + '; ' + lastResult.errMesage+ '\n' +lastResult.sql);
					return;
				}
			}
			//remove latch
			var idx:int=latches.indexOf(latch);
			if(idx!=-1) latches.splice(idx,1);

			// reDispatch?
			//event.token.dispatchEvent(event);
			
			checkComplite();
		}
		
		private function faultHandler(event:FaultEvent, token:AsyncToken=null):void{
			releaseError('DbLatch RPC fault: ' +event.fault.faultString + '\n' + event.fault.faultDetail);
		}
		
	}
}