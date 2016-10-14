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

		protected var regArray:Array;
		
		public var revers:Boolean=false;
		public var loadRejects:Boolean=true;
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
		[Bindable]
		public var bookRegister:TechBookRegister;

		private var strictMode:Boolean;
		
		/*
		*strictMode - manual mode, strict queue sequence vs book checking 
		*/
		public function TechQueueRegister(strictMode:Boolean=true){
			
			super(null);
			this.strictMode=strictMode;
			
			pgQueue=[];
			isStarted=false;
			
			currIdx=0;
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
			currIdx=0;
			isLoading=false;
			queue=null;
			queueAC=null;
			queueMap=null;
			lastId='';
		}

		public function stop():void{
			isStarted=false;
			isLoading=false;
		}

		public function register(pgId:String, book:int=0):void{
			if(!isStarted) return;
			if(!pgId) return;
			var techBook:TechBook= new TechBook(book,pgId);
			/*
			//is in check queue
			if(pgQueue.length>0){
				var idx:int=pgQueue.indexOf(pgId);
				if(idx>-1) return;
			}
			*/
			pgQueue.push(techBook);
			checkNext();
		}
		
		/*
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
		*/
		
		private var lastId:String;
		
		private function checkNext():void{
			if(isLoading) return;
			if(!queue){
				loadQueue();
				return;
			}
				
			var idx:int;
			var currBook:TechBook;
			
			while(pgQueue.length>0){
				currBook=pgQueue[0] as TechBook;
				
				while(currBook.printGroupId==lastId){
					if(strictMode){
						if(!bookRegister || bookRegister.printgroup.id!=currBook.printGroupId) createBookRegister();
						if(!bookRegister.register(currBook.book)){
							//stop on current
							pgQueue=[];
							return; 
						}
					}
					pgQueue.shift();
					continue;
				}
				lastId=currBook.printGroupId;

				//TODO bookRegister Complited ??

				//new queue? 
				if(!queueMap.hasOwnProperty(currBook.printGroupId)){
					//check if queue complited
					//TODO check by index?  
					//check by registred
					if(registred<queueAC.length){
						logErr('Партия '+queueId.toString() +' не завершена: '+registred.toString() +' из '+queueAC.length.toString());
						//TODO bookRegister Complited ??
					}
					break;
				}
				
				idx=queueMap[currBook.printGroupId];
				var pg:PrintGroup=getPg(currIdx);
				var checkPg:PrintGroup;
				//check index
				if(idx!=currIdx){
					logErr('Ошибка последовательности в партии: '+queueId.toString()+'. '+ indexCaption(idx)+' вместо '+indexCaption(currIdx));
					logMsg(currBook.printGroupId+' вместо '+pgCaption(currIdx));
					//mark pg
					if(pg) pg.checkStatus=PrintGroup.CHECK_STATUS_ERR;
					checkPg=getPg(idx);
					if(checkPg) checkPg.checkStatus=PrintGroup.CHECK_STATUS_ERR;
					if(strictMode){
						//stop on current ???
						pgQueue=[];
						return; 
					}
				}else{
					//mark pg
					if(pg){
						pg.checkStatus=strictMode?PrintGroup.CHECK_STATUS_IN_CHECK:PrintGroup.CHECK_STATUS_OK;
						//check reprint in strict mode
						if(strictMode && pg.is_reprint && !queue.is_reprint){
							logErr('Перепечатка: '+pg.id);
						}
					}
					//register print group
					if(regArray[currIdx] == undefined){
						registred++;
						regArray[currIdx]=new Date();
					}
					if(strictMode){
						//register book
						if(!bookRegister || bookRegister.printgroup.id!=currBook.printGroupId) createBookRegister();
						if(!bookRegister.register(currBook.book)){
							//stop on current
							pgQueue=[];
							return; 
						}
						//check next
						//TODO if bookRegister.register complited??????
						//??????????? currIdx++;
					}else{
						//move index && check next
						currIdx=idx;
					}
				}
				if(strictMode){
					//mark previouse pg
					pg=getPg(currIdx-1);
					if(pg && pg.checkStatus==PrintGroup.CHECK_STATUS_IN_CHECK) pg.checkStatus=PrintGroup.CHECK_STATUS_OK;
				}

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
			lastId='';
			registred=0;
			destroyBookRegister();
			
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
			
			var pg:PrintGroup;
			queueAC=new ArrayCollection();
			for (idx= 0; idx< queue.printGroups.length; idx++){
				if(revers){
					pg=queue.printGroups(queue.printGroups.length-idx-1) as PrintGroup;
				}else{
					pg=queue.printGroups.getItemAt(idx) as PrintGroup;
				}					
				if(pg) pg.checkOrder=idx+1;
				queueAC.addItem(pg);
			}
			
			//init regArray
			regArray=new Array(queueAC.length);
			
			//build map
			queueMap=new Object();
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