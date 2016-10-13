package com.photodispatcher.tech{
	import com.photodispatcher.model.mysql.DbLatch;
	import com.photodispatcher.model.mysql.entities.PrintGroup;
	import com.photodispatcher.model.mysql.entities.PrnQueue;
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

		/*
		private var _queue:Array;
		private function get queueArr():Array{
			return _queue;
		}
		private function set queueArr(value:Array):void{
			_queue = value;
			if(_queue){
				queueAC=new ArrayCollection(_queue);
			}else{
				queueAC=null;
			}
		}
		*/
		
		protected var regArray:Array;
		
		public var revers:Boolean=false;
		public var loadRejects:Boolean=false;
		[Bindable]
		public var isStarted:Boolean;
		[Bindable]
		public var queue:PrnQueue;
		public function get queueId():int{
			if(!queue) return 0;
			return queue.id;
		}
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
			queue=null;
			queueMap=null;
		}

		private function indexCaption(idx:int):String{
			return (idx+1).toString();
		}
		private function pgCaption(idx:int):String{
			if(!queueAC || idx<0 || idx>=queueAC.length) return '-';
			var pg:PrintGroup=queueAC.getItemAt(idx) as PrintGroup;
			if(pg) return pg.id;
			return '-';
		}
		
		private function getPg(idx:int):PrintGroup{
			if(!queueAC || idx<0 || idx>=queueAC.length) return null;
			return queueAC.getItemAt(idx) as PrintGroup; 
		}
		
		public function start():void{
			isStarted=true;
			pgQueue=[];
			currIdx=-1;
			isLoading=false;
			queue=null;
			queueAC=null;
			queueMap=null;
		}

		public function stop():void{
			isStarted=false;
			isLoading=false;
		}

		public function register(pgId:String):void{
			if(!isStarted) return;
			if(!pgId) return;
			if(pgQueue.length>0 && pgId==pgQueue[0]) return;
			/*
			//is in check queue
			if(pgQueue.length>0){
				var idx:int=pgQueue.indexOf(pgId);
				if(idx>-1) return;
			}
			*/
			pgQueue.push(pgId);
			checkNext();
		}
		
		protected function get dueIndex():int{
			if(!queueAC) return -1;
			if(currIdx==-1){
				//start queue
				if(revers) return queueAC.length-1;
				return 0;
			}
			var idx:int=currIdx;
			if(revers){
				idx--;
			}else{
				idx++;
			}
			if(idx<0 || idx>=queueAC.length) idx=-1;
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
					if(registred<queueAC.length){
						logErr('Партия '+queueId.toString() +' не завершена: '+registred.toString() +' из '+queueAC.length.toString());
					}
					break;
				}
				idx=queueMap[currId];
				//check index
				//TODO check if currentQueueIndex out of Queue lenght 
				if(idx!=dueIndex && idx!=currIdx){
					logErr('Ошибка последовательности в партии: '+queueId.toString()+'. '+ indexCaption(idx)+' вместо '+indexCaption(dueIndex));
					logMsg(currId+' вместо '+pgCaption(dueIndex));
					//mark pg
					if(getPg(idx)) getPg(idx).checkStatus=PrintGroup.CHECK_STATUS_ERR; 
				}else{
					//mark pg
					if(getPg(idx)) getPg(idx).checkStatus=PrintGroup.CHECK_STATUS_IN_CHECK;
				}
				//register
				if(regArray[idx] == undefined){
					registred++;
					regArray[idx]=new Date();
				}
				//mark previouse pg
				var pg:PrintGroup=getPg(currIdx);
				if(pg && pg.checkStatus==PrintGroup.CHECK_STATUS_IN_CHECK) pg.checkStatus=PrintGroup.CHECK_STATUS_OK;
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
			currIdx=-1;
			queueMap=null;
			queue=null;
			queueAC=null;
			regArray=null;
			registred=0;
			
			var svc:PrnStrategyService=Tide.getInstance().getContext().byType(PrnStrategyService,true) as PrnStrategyService;
			var latchR:DbLatch= new DbLatch(true);
			latchR.addEventListener(Event.COMPLETE,onloadQueue);
			//TODO load Queue vs items
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
			if(latch.complite) queue=latch.lastDataItem as PrnQueue;
			if(!queue || queue.printGroups.length==0){
				logMsg('Ошибка определения партии для : '+pgId+'. '+latch.lastError);
				pgQueue.shift();
				isLoading=false;
				checkNext();
				return;
			}
			queueAC=queue.printGroups;
			//init regArray
			regArray=new Array(queueAC.length);
			//build map
			queueMap=new Object();
			var pg:PrintGroup;
			for (idx= 0; idx< queueAC.length; idx++){
				pg=queueAC.getItemAt(idx) as PrintGroup;
				if(pg && pg.id) queueMap[pg.id]=idx;
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