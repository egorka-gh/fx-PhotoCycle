package com.photodispatcher.tech{
	import com.photodispatcher.model.mysql.DbLatch;
	import com.photodispatcher.model.mysql.entities.PrintGroup;
	import com.photodispatcher.model.mysql.services.PrnStrategyService;
	import com.photodispatcher.util.ArrayUtil;
	
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	
	import org.granite.tide.Tide;
	
	[Event(name="complete", type="flash.events.Event")]
	[Event(name="error", type="flash.events.ErrorEvent")]
	public class TechQueueRegister extends EventDispatcher{
		
		private var pgQueue:Array;
		private var queue:Array;
		private var queueMap:Object;
		private var queueId:int;
		private var currIdx:int;
		private var currPgId:String;
		private var isLoading:Boolean;
		private var isStarted:Boolean;
		
		public function TechQueueRegister(){
			super(null);
			pgQueue=[];
			isStarted=false;
			
			currIdx=-1;
			isLoading=false;
			queueId=0;
			queueMap=null;
		}

		public function get currentQueueIndex():int{
			return currIdx+1;
		}

		
		public function register(pgId:String):void{
			isStarted=true;
			if(!pgId) return;
			//is in check
			if(currPgId==pgId) return;
			//is in check queue
			if(pgQueue.length>0){
				var idx:int=pgQueue.indexOf(pgId);
				if(idx>-1) return;
			}
			pgQueue.push(pgId);
			checkNext();
		}
		
		public function stop():void{
			pgQueue=[];
			isStarted=false;
			
			currIdx=-1;
			isLoading=false;
			queueId=0;
			queue=null;
			queueMap=null;
		}
		
		private function checkNext():void{
			if(isLoading) return;
			if(!queue){
				loadQueue();
				return;
			}
				
			if(currIdx==-1){
				//starting
			}
		}

		private function isQueueComplete():Boolean{
			//TODO implement
			return false;
		}

		private function loadQueue():void{
			if(!isStarted) return;
			if(!pgQueue || pgQueue.length==0) return;
			var pgId:String=pgQueue[0];
			isLoading=true;
			queue=null;
			currIdx=-1;
			queueMap=null;
			queueId=0;
			var svc:PrnStrategyService=Tide.getInstance().getContext().byType(PrnStrategyService,true) as PrnStrategyService;
			var latchR:DbLatch= new DbLatch(true);
			latchR.addEventListener(Event.COMPLETE,onloadQueue);
			latchR.addLatch(svc.loadQueueItemsByPG(pgId),pgId);
			latchR.start();
		}
		protected function onloadQueue(e:Event):void{
			var latch:DbLatch=e.target as DbLatch;
			if(!latch) return;
			var pgId:String='';
			var idx:int;
			latch.removeEventListener(Event.COMPLETE,onloadQueue);
			if(!isStarted) return;

			pgId=latch.lastTag;
			if(!pgQueue || pgQueue.length==0){
				logMsg('Ошибка выполнения: пустой стек');
				isLoading=false;
				return;
			}
			if(pgQueue[0]!=pgId){
				logMsg('Ошибка выполнения: вершина стека: '+pgQueue[0]+'; ожидалось: ' +pgId+'.');
				isLoading=false;
				checkNext();
				return;
			}
			if(latch.complite) queue=latch.lastDataArr;
			if(!queue || queue.length==0){
				logMsg('Ошибка определения партии для : '+pgId+'. '+latch.lastError);
				queue=null;
				pgQueue.shift();
				isLoading=false;
				checkNext();
				return;
			}
			//build map
			var pg:PrintGroup=queue[0] as PrintGroup;
			queueId=pg.prn_queue;
			queueMap=new Object();
			idx=0;
			for each(pg in queue){
				queueMap[pg.id]=idx;
				idx++;
			}
			isLoading=false;
			checkNext();
			
			///remove
			var idx:int=ArrayUtil.searchItemIdx('id',currPgId, queue);
			if(idx==-1){
				logErr('Ошибка определения партии для : '+currPgId+'.');
				return;
			}
			currIdx=idx;
			if(idx!=0){
				logErr('Ошибка последовательности в партии: '+currPgId+'. '+currIdx.toString()+' вместо 1.');
			}
		}

		protected function logErr(msg:String):void{
			dispatchEvent( new ErrorEvent(ErrorEvent.ERROR,false,false,msg,1));
		}
		protected function logMsg(msg:String):void{
			dispatchEvent( new ErrorEvent(ErrorEvent.ERROR,false,false,msg,0));
		}

	}
}