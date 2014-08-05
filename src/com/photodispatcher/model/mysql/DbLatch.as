package com.photodispatcher.model.mysql
{
	import com.photodispatcher.model.mysql.entities.DmlResult;
	import com.photodispatcher.model.mysql.entities.SelectResult;
	import com.photodispatcher.model.mysql.entities.SqlResult;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.utils.getTimer;
	
	import mx.collections.ArrayCollection;
	import mx.controls.Alert;
	import mx.rpc.AsyncResponder;
	import mx.rpc.AsyncToken;
	import mx.rpc.events.FaultEvent;
	import mx.rpc.events.ResultEvent;
	
	[Event(name="complete", type="flash.events.Event")]
	public class DbLatch extends AsyncLatch{
		
		public var lastResult:SqlResult;
		public var lastToken:AsyncToken;

		protected var latches:Array;
		
		public function DbLatch(silent:Boolean=false){
			super(silent);
			//no manual release
			//release only by latches & joint 
			thisComplite=true;
			latches=[];
		}
		
		public function addLatch(token:AsyncToken, tag:String=null):void{
			if(hasError ||!token || !latches) return;
			var latch:int=getTimer();
			token.latch=latch;
			if(tag) token.tag=tag;
			latches.push(latch);
			token.addResponder(new AsyncResponder(resultHandler, faultHandler));
		}
		
		override public function release():void{
			//no action
			//super.release(force);
		}
		
		

		override public function releaseError(err:String):void{
			latches=null;
			super.releaseError(err);
		}
		
		override protected function isComplite():Boolean{
			return (!latches || latches.length==0) && super.isComplite();
		}
		
		public function get lastDataAC():ArrayCollection{
			if(lastResult && lastResult is SelectResult && (lastResult as SelectResult).data){
				if ((lastResult as SelectResult).data is ArrayCollection){
					return (lastResult as SelectResult).data as ArrayCollection;
				}else{
					return new ArrayCollection(lastDataArr);
				}
			}
			return null;
		}
		public function get lastDataArr():Array{
			var result:Array=[];
			if(lastResult && lastResult is SelectResult && (lastResult as SelectResult).data){
				result=(lastResult as SelectResult).data.toArray();
			}
			return result;
		}
		public function get lastItem():Object{
			if(lastResult && lastResult is DmlResult){
				return (lastResult as DmlResult).item;
			}
			return null;
		}

		protected function resultHandler(event:ResultEvent, token:AsyncToken=null):void{
			if(!latches) return;
			lastToken=event.token;
			var latch:int=lastToken.latch;
			
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
		
		protected function faultHandler(event:FaultEvent, token:AsyncToken=null):void{
			lastToken=event.token;
			releaseError('DbLatch RPC fault: ' +event.fault.faultString + '\n' + event.fault.faultDetail);
		}
		
	}
}