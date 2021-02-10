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
	
	import org.granite.tide.rpc.ComponentResponder;
	
	[Event(name="complete", type="flash.events.Event")]
	public class DbLatch extends AsyncLatch{
		
		//public var lastResult:SqlResult;
		public var lastToken:AsyncToken;
		
		public var resultCode:int;
		public var lastErrCode:int;
		public var lastError:String;
		
		private var lastItem:Object;
		private var lastData:Array;
		
		protected var latches:Array;
		
		public function DbLatch(silent:Boolean=false){
			super(silent);
			//no manual release
			//release only by latches & joint 
			thisComplite=true;
			latches=[];
		}
		
		override public function start():void{
			lastToken=null;
			lastTag=null;
			resultCode=0;
			lastErrCode=0;
			lastError=null;
			lastItem=null;
			lastData=null;
			super.start();
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
		
		public function get lastDataItem():Object{
			/*
			if(lastResult && lastResult is SelectResult && (lastResult as SelectResult).data && (lastResult as SelectResult).data.length>0){
			return (lastResult as SelectResult).data[0];
			}
			*/
			if(lastData && lastData.length>0) return lastData[0];
			return null;
		}
		
		public function get lastDataAC():ArrayCollection{
			/*
			if(lastResult && lastResult is SelectResult && (lastResult as SelectResult).data){
			if ((lastResult as SelectResult).data is ArrayCollection){
			return (lastResult as SelectResult).data as ArrayCollection;
			}else{
			return new ArrayCollection(lastDataArr);
			}
			}
			*/
			if(lastData) return new ArrayCollection(lastData); 
			return null;
		}
		public function get lastDataArr():Array{
			/*
			var result:Array=[];
			if(lastResult && lastResult is SelectResult && (lastResult as SelectResult).data){
			result=(lastResult as SelectResult).data.toArray();
			}
			*/
			return lastData?lastData:[];
		}
		public function get lastDMLItem():Object{
			/*
			if(lastResult && lastResult is DmlResult){
			return (lastResult as DmlResult).item;
			}
			return null;
			*/
			return lastItem;
		}
		
		protected function resultHandler(event:ResultEvent, token:AsyncToken=null):void{
			if(!latches) return;
			lastToken=event.token;
			lastTag=lastToken.tag?lastToken.tag:'';
			var latch:int=lastToken.latch;
			
			//remove latch
			var idx:int=latches.indexOf(latch);
			if(idx!=-1) latches.splice(idx,1);
			
			processResult(event.result.result as SqlResult);
			/*
			//check for sql error
			lastResult=event.result.result as SqlResult;
			if(lastResult){
			if(!lastResult.complete){
			var errMsg:String=lastResult.errMesage;
			if(lastResult.errCode==1062){
			errMsg=errMsg.replace('Duplicate entry','Повтор уникального значения');
			}
			releaseError('DbLatch SQL error: code-' +lastResult.errCode.toString() + '; '+errMsg+'\n' +lastResult.sql);
			return;
			}
			}
			*/
			checkComplite();
		}
		
		private function processResult(result:SqlResult):void{
			if(!result) return;
			//check for sql error
			if(!result.complete){
				lastError=result.errMesage;
				lastErrCode=result.errCode;
				if(lastErrCode==1062){
					lastError=lastError.replace('Duplicate entry','Повтор уникального значения');
				}
				releaseError('DbLatch SQL error: code-' +lastErrCode.toString() + '; '+lastError+'\n' +result.sql);
				return;
			}
			resultCode=result.resultCode;
			if(result && result is SelectResult && (result as SelectResult).data){
				var selResult:SelectResult=result as SelectResult;
				lastData=selResult.data.toArray().concat();
				selResult.data=null;
			}
			if(result && result is DmlResult){
				var dResult:DmlResult= result as DmlResult;
				lastItem=dResult.item;
				dResult.item=null;
			}
			
		}
		
		protected function faultHandler(event:FaultEvent, token:AsyncToken=null):void{
			lastToken=event.token;
			lastTag=lastToken.tag?lastToken.tag:'';
			lastError=event.fault.faultString;
			//get source
			var cr:ComponentResponder;
			for each(var r:Object in lastToken.responders){
				cr = r as ComponentResponder;
				if(cr) break;
			}
			if(cr){
				lastError = cr.component.meta_name+'.'+cr.op+' : '+lastError;
			}
			releaseError('DbLatch RPC fault: ' +lastError + '\n' + event.fault.faultDetail);
		}
		
	}
}