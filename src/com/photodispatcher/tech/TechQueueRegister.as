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
	
	[Event(name="clear", type="flash.events.Event")]
	[Event(name="complete", type="flash.events.Event")]
	[Event(name="error", type="flash.events.ErrorEvent")]
	
	public class TechQueueRegister extends EventDispatcher{
		
		private var pgQueue:Array;
		private var queueMap:Object;
		private var isLoading:Boolean;

		protected var regArray:Array;
		
		[Bindable]
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
		public var currIndex:int=-1;

		
		private var _currIdx:int;
		protected function get currIdx():int{
			return _currIdx;
		}
		protected function set currIdx(value:int):void{
			_currIdx = value;
			if(queueAC && _currIdx>=0 && _currIdx<queueAC.length){
				currIndex=_currIdx;
			}else{
				currIndex=-1;
			}
		}


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
		
		public function get isComplited():Boolean{
			if(!queue || !queueAC || queueAC.length==0) return true;
			if(strictMode) return currIdx>=queueAC.length && (!bookRegister || bookRegister.isComplited);
			return registred>=queueAC.length;
		}

		public function moveIndex(forward:Boolean=true):void{
			if(!queueAC || queueAC.length==0) return;
			if(forward){
				if(currIdx<(queueAC.length-1)) currIdx=currIdx+1;
			}else{
				if(currIdx>0) currIdx=currIdx-1;
			}
			//create book register
			if(strictMode){
				var pg:PrintGroup=getPg(currIdx);
				if(pg){
					createBookRegister(pg);
				}else{
					destroyBookRegister();
				}
			}
		}
		
		public function start():void{
			isStarted=true;
			pgQueue=[];
			currIdx=-1;
			isLoading=false;
			queue=null;
			queueAC=null;
			queueMap=null;
			lastId='';
			destroyBookRegister();
		}

		public function stop():void{
			isStarted=false;
			isLoading=false;
		}

		public function load(pgId:String):void{
			if(isLoading) return;
			//reset
			start();
			var techBook:TechBook= new TechBook(-1,pgId);
			pgQueue.push(techBook);
			loadQueue();
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
				
				if(currBook.printGroupId==lastId){
					if(strictMode){
						//register book
						if(bookRegister && currBook.book!=0 && !bookRegister.register(currBook.book)){
							//stop on current
							pgQueue=[];
							return; 
						}
						if(bookRegister && bookRegister.isComplited){
							lastId='';
							//next pg
							currIdx++;
						}
					}
					//book - ok, check next
					pgQueue.shift();
					continue;
				}else{
					if(strictMode){
						//bookRegister Complited ??
						if(bookRegister && !bookRegister.isComplited){
							logErr('Последовательности книг не завершена '+bookRegister.printgroup.id+'. ');
							//stop on current
							pgQueue=[];
							return; 
						}
						//createBookRegister();
					}
				}

				lastId=currBook.printGroupId;


				//new queue? 
				if(!queueMap.hasOwnProperty(currBook.printGroupId)){
					//check if queue complited
					//TODO check by index?  
					//check by registred
					if(!isComplited){
						if(strictMode){
							logErr('Партия '+queueId.toString() +' не завершена: '+indexCaption(currIdx)+' из '+queueAC.length.toString());
							//stop on current
							pgQueue=[];
							return; 
						}else{
							logErr('Партия '+queueId.toString() +' не завершена: '+registred.toString() +' из '+queueAC.length.toString());
						}
					}
					//load new queue
					break;
				}
				///TODO check if currIdx out of sequence
				idx=queueMap[currBook.printGroupId];
				var pg:PrintGroup=getPg(currIdx);
				//check index
				if(idx!=currIdx){
					logErr('Ошибка последовательности в партии: '+queueId.toString()+'. '+ indexCaption(idx)+' вместо '+indexCaption(currIdx));
					logMsg(currBook.printGroupId+' вместо '+pgCaption(currIdx));
					//mark pg
					if(pg) pg.checkStatus=PrintGroup.CHECK_STATUS_ERR;
					if(strictMode){
						//stop on current ???
						pgQueue=[];
						return; 
					}
				}else{
					//register print group
					if(regArray[currIdx] == undefined){
						registred++;
						regArray[currIdx]=new Date();
					}
					//mark pg
					if(pg){
						if(strictMode){
							pg.checkStatus=PrintGroup.CHECK_STATUS_IN_CHECK;
							//check reprint in strict mode
							if(pg.is_reprint && !queue.is_reprint){
								logErr('Перепечатка: '+pg.id);
							}
							//register book
							createBookRegister(pg);
							if(currBook.book!=0 && !bookRegister.register(currBook.book)){
								//stop on current
								pgQueue=[];
								return; 
							}
						}else{
							pg.checkStatus=PrintGroup.CHECK_STATUS_OK;
						}
					}
					if(strictMode){
						//check next
						if(bookRegister && bookRegister.isComplited){
							lastId='';
							//must be next pg
							currIdx++;
						}
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
				if(isComplited) dispatchEvent(new Event(Event.COMPLETE));
			}
			
			if(pgQueue.length>0) loadQueue(); 
		}

		private function createBookRegister(pg:PrintGroup):void{
			if(!pg) return;
			destroyBookRegister();
			bookRegister= new TechBookRegister(pg,revers);
			bookRegister.addEventListener(ErrorEvent.ERROR, onBookRegisterErr);
		}
		private function onBookRegisterErr(event:ErrorEvent):void{
			dispatchEvent(event.clone());
		}
		private function destroyBookRegister():void{
			if(!bookRegister) return;
			bookRegister.removeEventListener(ErrorEvent.ERROR, onBookRegisterErr);
			bookRegister=null;
		}
		
		private function loadQueue():void{
			if(!isStarted) return;
			if(!pgQueue || pgQueue.length==0) return;
			var pgId:String=(pgQueue[0] as TechBook).printGroupId;
			if(!pgId) return;
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
			//signal previose complited
			dispatchEvent(new Event(Event.CLEAR));
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
			var tBook:TechBook=pgQueue[0] as TechBook;
			if(tBook.printGroupId!=pgId){
				logMsg('Ошибка выполнения: вершина стека: '+tBook.printGroupId+'; ожидалось: ' +pgId+'.');
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
					pg=queue.printGroups.getItemAt(queue.printGroups.length-idx-1) as PrintGroup;
				}else{
					pg=queue.printGroups.getItemAt(idx) as PrintGroup;
				}					
				if(pg){
					if(pg.is_reprint && !queue.is_reprint) pg.checkStatus=PrintGroup.CHECK_STATUS_REPRINT;
					pg.checkOrder=idx+1;
				}
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
			currIdx=0;
			isLoading=false;
			if(tBook.book==-1){
				//just load & stop
				pg=queueAC.getItemAt(0) as PrintGroup;
				createBookRegister(pg);
				pgQueue=[];
			}else{
				checkNext();
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