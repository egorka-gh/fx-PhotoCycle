package com.photodispatcher.tech{
	import com.photodispatcher.model.mysql.DbLatch;
	import com.photodispatcher.model.mysql.entities.PrintGroup;
	import com.photodispatcher.model.mysql.services.PrnStrategyService;
	import com.photodispatcher.util.ArrayUtil;
	
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	
	import mx.collections.ArrayCollection;
	
	import org.granite.tide.Tide;
	
	[Event(name="complete", type="flash.events.Event")]
	[Event(name="error", type="flash.events.ErrorEvent")]
	public class TechQueueRegister extends EventDispatcher{
		
		private var pgQueue:Array;
		private var queueMap:Object;
		private var isLoading:Boolean;
		private var isStarted:Boolean;

		private var _queue:Array;
		private function get queue():Array{
			return _queue;
		}
		private function set queue(value:Array):void{
			_queue = value;
			if(_queue){
				queueAC=new ArrayCollection(_queue);
			}else{
				queueAC=null;
			}
		}
		
		protected var regArray:Array;
		
		public var revers:Boolean=false;
		public var loadRejects:Boolean=false;
		[Bindable]
		public var queueId:int;
		[Bindable]
		public var queueAC:ArrayCollection;
		[Bindable]
		public var currIdx:int;
		[Bindable]
		public var registred:int;

		
		public function TechQueueRegister(){
			super(null);
			pgQueue=[];
			isStarted=false;
			
			currIdx=-1;
			isLoading=false;
			queueId=0;
			queueMap=null;
		}

		private function indexCaption(idx:int):String{
			return (idx+1).toString();
		}
		private function pgCaption(idx:int):String{
			if(!queue || idx<0 || idx>=queue.length) return '-';
			var pg:PrintGroup=queue[idx] as PrintGroup;
			if(pg) return pg.id;
			return '-';
		}
		
		public function register(pgId:String):void{
			isStarted=true;
			if(!pgId) return;
			//is in check
			//if(currPgId==pgId) return;
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
		
		protected function get dueIndex():int{
			if(!queue) return -1;
			if(currIdx==-1){
				//start queue
				if(revers) return queue.length-1;
				return 0;
			}
			var idx:int=currIdx;
			if(revers){
				idx--;
			}else{
				idx++;
			}
			if(idx<0 || idx>=queue.length) idx=-1;
			return idx;
		}
		
		private function checkNext():void{
			if(isLoading) return;
			if(!queue){
				loadQueue();
				return;
			}
				
			var idx:int;
			var currId:String;
			
			while(pgQueue.length>0){
				currId=pgQueue[0];
				if(!queueMap.hasOwnProperty(currId)){
					//check if queue complited
					//TODO check by registred, index can be wrong (wrong seq)
					if(registred<queue.length){
						logErr('Партия '+queueId.toString() +' не завершена: '+registred.toString() +' из '+queue.length.toString());
					}
					break;
				}
				idx=queueMap[currId];
				//check index
				//TODO check if currentQueueIndex out of Queue lenght 
				if(idx!=dueIndex){
					logErr('Ошибка последовательности в партии: '+queueId.toString()+'. '+ indexCaption(idx)+' вместо '+indexCaption(dueIndex));
					logMsg(currId+' вместо '+pgCaption(dueIndex));
				}
				//register
				if(regArray[idx] == undefined){
					registred++;
					regArray[idx]=new Date();
				}
				currIdx=idx;
				pgQueue.shift();
			}
			
			if(pgQueue.length>0) loadQueue(); 
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
			regArray=null;
			registred=0;
			
			var svc:PrnStrategyService=Tide.getInstance().getContext().byType(PrnStrategyService,true) as PrnStrategyService;
			var latchR:DbLatch= new DbLatch(true);
			latchR.addEventListener(Event.COMPLETE,onloadQueue);
			latchR.addLatch(svc.loadQueueItemsByPG(pgId, loadRejects),pgId);
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
			//init regArray
			regArray=new Array(queue.length);
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
			
		}

		protected function logErr(msg:String):void{
			dispatchEvent( new ErrorEvent(ErrorEvent.ERROR,false,false,msg,1));
		}
		protected function logMsg(msg:String):void{
			dispatchEvent( new ErrorEvent(ErrorEvent.ERROR,false,false,msg,0));
		}

	}
}