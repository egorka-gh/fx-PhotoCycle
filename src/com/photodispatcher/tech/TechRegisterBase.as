package com.photodispatcher.tech{
	import com.photodispatcher.event.AsyncSQLEvent;
	import com.photodispatcher.model.mysql.DbLatch;
	import com.photodispatcher.model.mysql.entities.BookSynonym;
	import com.photodispatcher.model.mysql.entities.PrintGroup;
	import com.photodispatcher.model.mysql.entities.PrintGroupReject;
	import com.photodispatcher.model.mysql.entities.TechLog;
	import com.photodispatcher.model.mysql.entities.TechPoint;
	import com.photodispatcher.model.mysql.entities.TechReject;
	import com.photodispatcher.model.mysql.services.OrderService;
	import com.photodispatcher.model.mysql.services.TechService;
	import com.photodispatcher.service.barcode.ValveCom;
	import com.photodispatcher.util.ArrayUtil;
	import com.photodispatcher.util.StrUtil;
	
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.TimerEvent;
	import flash.utils.Timer;
	
	import org.granite.tide.Tide;
	import org.osmf.events.TimeEvent;
	
	[Event(name="complete", type="flash.events.Event")]
	[Event(name="error", type="flash.events.ErrorEvent")]
	public class TechRegisterBase extends EventDispatcher{
		public static const ERROR_SEQUENCE:int=1;
		public static const FLUSH_TIMER_INTERVAL:int=15*1000;//15sek

		public static const TYPE_COMMON:int=1;
		public static const TYPE_FOLDING:int=2;
		public static const TYPE_GLUE:int=3;
		public static const TYPE_PICKER:int=4;
		public static const TYPE_PRINT:int=5;


		public var techPoint:TechPoint;
		[Bindable]
		public var printGroupId:String;
		protected var printGroup:PrintGroup; 
		protected var printGroups:Array; 
		protected var rejects:Array; 
		
		[Bindable]
		public var books:int;
		[Bindable]
		public var sheets:int;
		[Bindable]
		public var revers:Boolean=false;
		public var flap:ValveCom;
		public var inexactBookSequence:Boolean=false;
		public var detectFirstBook:Boolean=false;
		public var hasWrongSequence:Boolean=false;
		
		protected var regArray:Array;
		protected var bookPart:int;
		protected var lastBook:int;
		protected var lastSheet:int;
		[Bindable]
		public var registred:int;
		protected var rejectedCount:int=0;
		
		protected var logOk:Boolean;

		protected var _type:int=TYPE_COMMON;
		public function get type():int{
			return _type;
		}
		
		protected var _canInterrupt:Boolean=false;
		public function get canInterrupt():Boolean{
			return _canInterrupt;
		}
		
		protected var _strictSequence:Boolean=false;
		public function get strictSequence():Boolean{
			return _strictSequence;
		}

		protected var _logSequenceErr:Boolean=true;
		public function get logError():Boolean{
			return _logSequenceErr;
		}
		
		public var calcOnLog:Boolean;
		
		protected var _needFlush:Boolean=false;
		public function get needFlush():Boolean{
			return _needFlush;
		}

		public function  flushData():void{
			if(calcOnLog) return;
			if(!_needFlush || !printGroupId || !techPoint) return;

			//recalc
			var latch:DbLatch=new DbLatch(true);
			var svc:TechService=Tide.getInstance().getContext().byType(TechService,true) as TechService;
			latch.addEventListener(Event.COMPLETE, onCalc);
			latch.addLatch(svc.calcByPg(printGroupId, techPoint.id));
			latch.start();
			_needFlush=false;
		}
		private function onCalc(evt:Event):void{
			var latch:DbLatch=evt.target as DbLatch;
			if(latch) latch.removeEventListener(Event.COMPLETE, onCalc);
			if(latch && !latch.complite){
				logSequeceErr('Ошибка базы данных: '+latch.error);
				_needFlush=true;
			}
		}

		public function TechRegisterBase(printGroup:String, books:int,sheets:int){
			super(null);
			printGroupId=printGroup;
			this.books=books;
			this.sheets=sheets;
			regArray = new Array(books);
			bookPart=BookSynonym.BOOK_PART_ANY;
			registred=0;
			logOk=true;
			calcOnLog=false;
			//complited=false;
			
			if(type==TYPE_PRINT || type==TYPE_PICKER) return;
			//load printgroup & reprints
			var svc:OrderService=Tide.getInstance().getContext().byType(OrderService,true) as OrderService;
			var latchR:DbLatch= new DbLatch(true);
			latchR.addEventListener(Event.COMPLETE,onReprintsLoad);
			latchR.addLatch(svc.loadReprintsByPG(printGroupId));
			latchR.start();
			//load rejects
			var latch:DbLatch= new DbLatch(true);
			latch.addEventListener(Event.COMPLETE,onRejectsLoad);
			latch.addLatch(svc.loadRejects4PG(printGroupId));
			latch.join(latchR);
			latch.start();
		}
		protected function onReprintsLoad(e:Event):void{
			printGroups=null;
			var latch:DbLatch=e.target as DbLatch;
			if(latch){
				latch.removeEventListener(Event.COMPLETE,onReprintsLoad);
				if(latch.complite && latch.lastDataArr.length>0){
					printGroups=latch.lastDataArr;
				}
				if(printGroups && printGroups.length>0){
					//detect bookpart
					//var pg:PrintGroup=printGroups[0] as PrintGroup;
					//if(pg) bookPart=pg.book_part;
					printGroup=ArrayUtil.searchItem('id',printGroupId,printGroups) as PrintGroup;
					if(printGroup){
						bookPart=printGroup.book_part;
					}else{
						//hz
						var pg:PrintGroup=printGroups[0] as PrintGroup;
						if(pg) bookPart=pg.book_part;
					}
				}
			}
		}
		protected function onRejectsLoad(e:Event):void{
			rejects=null;
			rejectedCount=0;
			var latch:DbLatch=e.target as DbLatch;
			if(latch){
				latch.removeEventListener(Event.COMPLETE,onRejectsLoad);
				if(latch.complite && latch.lastDataArr.length>0){
					rejects=latch.lastDataArr;
				}
			}
			if(rejects){
				//count rejected sheets, used in isCompleted  
				for each(var item:PrintGroupReject in rejects){
					if(item){
						if(item.thech_unit==TechReject.UNIT_BLOCK 
							|| item.thech_unit==TechReject.UNIT_BOOK
							|| item.thech_unit==TechReject.UNIT_COVER){
							rejectedCount+=sheets;
						}else{
							rejectedCount++;
						}
					}
				}
			}
		}
		
		public function checkPrintGroup(pgId:String):Boolean{
			if(!pgId || !printGroupId) return false;
			if(pgId==printGroupId) return true;
			if(!printGroups) return false;
			var pg:PrintGroup;
			for each(pg in printGroups){
				if(pg.id==pgId) return true;
			}
			return false;
		}

		public function isReprint(pgId:String):Boolean{
			if(!pgId) return false;
			if(!printGroups) return PrintGroup.getIdxFromId(pgId)>2;
			var pg:PrintGroup;
			for each(pg in printGroups){
				if(pg.id==pgId) return pg.is_reprint;
			}
			return false;
		}
		
		public function getReject(book:int,sheet:int):PrintGroupReject{
			if(printGroup && printGroup.is_reprint) return null;
			if(!rejects || rejects.length==0) return null;
			for each(var item:PrintGroupReject in rejects){
				if(item && item.book==book && (item.sheet==-1 || item.sheet==sheet)){
					return item;
				}
			}
			return null;
		}

		public function register(book:int,sheet:int):void{
			if(bookPart==BookSynonym.BOOK_PART_ANY){
				//first time, init
				if(sheet==0){
					if(sheets>1){
						//can be blockcover in revers order
						bookPart=BookSynonym.BOOK_PART_BLOCKCOVER;
						logMsg('Наверное БлокОбложка');
					}else{
						bookPart=BookSynonym.BOOK_PART_COVER;
					}
				}else{
					bookPart=BookSynonym.BOOK_PART_BLOCK;
					//can be blockcover 
				}
				if(!strictSequence && !lastBook){
					//detect order
					if(!revers){
						if(book==books && 
							((bookPart==BookSynonym.BOOK_PART_COVER && sheet==0) || 
							 (bookPart==BookSynonym.BOOK_PART_BLOCKCOVER && sheet==0) ||	
							 (bookPart==BookSynonym.BOOK_PART_BLOCK && sheet==sheets))){
							logMsg('Переключение на обратный порядок');
							revers=true;
						}
					}else{
						if(book==1 && 
							((bookPart==BookSynonym.BOOK_PART_COVER && sheet==0) ||
							 (bookPart==BookSynonym.BOOK_PART_BLOCKCOVER && sheet==1) ||
						 	 (bookPart==BookSynonym.BOOK_PART_BLOCK && sheet==1))){
							logMsg('Переключение на прямой порядок');
							revers=false;
						}
					}
				}
				if(bookPart==BookSynonym.BOOK_PART_BLOCKCOVER && revers) lastSheet=1;
			}
			
			if(registred==1){
				//second pass - can deted blockcover in revers
				if(bookPart==BookSynonym.BOOK_PART_COVER && lastSheet==0 && lastBook==book && sheet==sheets-1){
					//blockcover in revers order
					bookPart=BookSynonym.BOOK_PART_BLOCKCOVER;
					if(!strictSequence) revers=true;
					logMsg('Наверное БлокОбложка в обратном порядке');
				}
			}
			if(registred==sheets-1){
				//penult pass - can detect blockcover normal order
				if(bookPart==BookSynonym.BOOK_PART_BLOCK && lastSheet==sheets-1 && lastBook==book && sheet==0){
					//blockcover in normal order
					bookPart=BookSynonym.BOOK_PART_BLOCKCOVER;
					if(!strictSequence) revers=false;
					logMsg('Наверное БлокОбложка в прямом порядке');
				}
			}
			
			if(!checkSequece(book,sheet) && strictSequence) return;
			
			//fix data
			var idx:int=book-1;
			lastBook=book;
			lastSheet=sheet;
			var log:Boolean=false;
			if(regArray[idx] == undefined) regArray[idx]=new Array(sheets+1);//+1 for 0
			if(regArray[idx][sheet] == undefined){
				regArray[idx][sheet]=new Date();
				registred++;
				log=true;
			}
			if(log){
				if(!calcOnLog){
					_needFlush=true;
					startFlushTimer();
				}
				logRegistred(book,sheet);
			}
			dispatchEvent(new Event(Event.COMPLETE));
		}
		
		protected function isRegistred(book:int,sheet:int):Boolean{
			if(book<=0 || sheet<0) return false;
			if(!regArray || regArray[book-1]==undefined || regArray[book-1][sheet]==undefined) return false;
			return true;
		}
		
		protected  var flushTimer:Timer;
		
		protected function startFlushTimer():void{
			if(calcOnLog) return;
			if(!flushTimer){
				flushTimer= new Timer(FLUSH_TIMER_INTERVAL,1);
				flushTimer.addEventListener(TimerEvent.TIMER, onFlushTimer);
			}
			flushTimer.reset();
			flushTimer.start();
		}
		protected function onFlushTimer(event:TimeEvent):void{
			flushTimer.removeEventListener(TimerEvent.TIMER, onFlushTimer);
			flushData();
		}
		
		
		protected function logRegistred(book:int,sheet:int):void{
			//log to data base
			var tl:TechLog= new TechLog();
			tl.log_date=new Date();
			tl.setSheet(book,sheet);
			tl.print_group=printGroupId;
			tl.src_id= techPoint.id;
			var latch:DbLatch=new DbLatch(true);
			var svc:TechService=Tide.getInstance().getContext().byType(TechService,true) as TechService;
			//latch.addEventListener(Event.COMPLETE,onLog);
			latch.addLatch(svc.logByPg(tl,calcOnLog?1:0));
			latch.addEventListener(Event.COMPLETE, onLogComplie);
			latch.start();
		}
		private function onLogComplie(evt:Event):void{
			var latch:DbLatch=evt.target as DbLatch;
			if(latch) latch.removeEventListener(Event.COMPLETE, onLogComplie);
			if(latch && !latch.complite){
				logSequeceErr('Ошибка базы данных: '+latch.error);
			}
		}
		
		public function get isBookComplete():Boolean{
			var endSheet:int=0;
			if(bookPart==BookSynonym.BOOK_PART_BLOCK) endSheet=revers?1:sheets;
			return lastSheet==endSheet;
		}
		
		public function get isComplete():Boolean{
			/* detect by registred
			if(inexactBookSequence) return false;//can't detect
			*/
			if(detectFirstBook || inexactBookSequence){
				//check last book & last sheet 
				var endSheet:int=0;
				if(bookPart==BookSynonym.BOOK_PART_BLOCK) endSheet=revers?1:sheets;
				if(lastBook==books && lastSheet==endSheet) return true;
			}
			if((bookPart==BookSynonym.BOOK_PART_BLOCK || bookPart==BookSynonym.BOOK_PART_BLOCKCOVER) && (registred+rejectedCount)==books*sheets){
				return true;
			}
			if(bookPart==BookSynonym.BOOK_PART_COVER && (registred+rejectedCount)==books){//one cover per book
				return true;
			}
			return false;
		}

		protected function get dueBook():int{
			if(!lastBook) return revers?books:1;
			if(bookPart==BookSynonym.BOOK_PART_COVER){
				return revers?(lastBook-1):(lastBook+1);
			}else if(bookPart==BookSynonym.BOOK_PART_BLOCKCOVER){
				if(revers){
					return lastSheet==1?(lastBook-1):lastBook;
				}else{
					return lastSheet==0?(lastBook+1):lastBook;
				}
			}else{
				if(revers){
					return lastSheet==1?(lastBook-1):lastBook;
				}else{
					return lastSheet==sheets?(lastBook+1):lastBook;
				}
			}
		}
		protected function get dueSheet():int{
			if(bookPart==BookSynonym.BOOK_PART_COVER){
				return 0;
			}else if(bookPart==BookSynonym.BOOK_PART_BLOCKCOVER){
				//if(!lastSheet) return revers?0:1;
				if(revers){
					if(lastSheet==1){
						return 0;
					}else if(lastSheet==0){
						return sheets-1;
					}else{
						return lastSheet-1;
					}
				}else{
					if(lastSheet==sheets-1){
						return 0;
					}else if(lastSheet==0){
						return 1;
					}else{
						return lastSheet+1;
					}
				}
			}else{
				if(!lastSheet) return revers?sheets:1;
				if(revers){
					return lastSheet==1?sheets:(lastSheet-1);
				}else{
					return lastSheet==sheets?1:(lastSheet+1);
				}
			}
		}

		public function get currentBook():int{
			return lastBook;
		}
		public function get currentSheet():int{
			return lastSheet;
		}
		public function get currentBookComplited():Boolean{
			if(!lastBook) return false;
			if(bookPart==BookSynonym.BOOK_PART_COVER) return true;
			var endSheet:int=revers?1:sheets;
			return lastSheet==endSheet;
		}
		
		public function finalise():Boolean{
			var result:Boolean=true;
			if (!isComplete && !inexactBookSequence){
				if(canInterrupt){
					if(flap) flap.setOff();
					if(strictSequence) result=false;
				}
				logSequeceErr('Не полная последовательность');
			}else{
				if(logOk) logMsg('Ok');
			}
			flushData();
			return result;
		}

		protected function checkSequece(book:int,sheet:int):Boolean{
			var dBook:int=dueBook;
			var dSheet:int=dueSheet;
			var result:Boolean;
			var reject:PrintGroupReject= getReject(book,sheet);
			if(reject && !isRegistred(book,sheet) && rejectedCount>0) rejectedCount--;
			if(isComplete){
				if(canInterrupt && flap) flap.setOff();
				logSequeceErr('Должен быть следующий заказ: '+ StrUtil.sheetName(book,sheet)+' при завершенной последовательности.' );
				return false;
			}
			if(inexactBookSequence){
				var firstSheet:int=0;
				if(bookPart==BookSynonym.BOOK_PART_BLOCK){
					firstSheet=revers?sheets:1;
				}else if(bookPart==BookSynonym.BOOK_PART_BLOCKCOVER){
					firstSheet=revers?0:1;
				}
				if(dueSheet==firstSheet) dBook=book;
			}else if(detectFirstBook){
				dBook=book;
				detectFirstBook=false;
			}
			
			result=dBook==book && dSheet==sheet;
			//check if rejected
			if(result && printGroup && printGroup.is_pdf && !printGroup.is_reprint && reject){
				logSequeceErr('Не убран брак '+reject.thech_unit_name+' '+ StrUtil.sheetName(book,sheet));
			}
			
			if(!result){
				//TODO check if book,sheet is after reject?
				reject=getReject(dBook,dSheet);
				if(reject){
					//skip reject and recheck
					if(reject.thech_unit==TechReject.UNIT_SHEET || reject.thech_unit==TechReject.UNIT_COVER){
						//skip one sheet
						logMsg('Пропуск брака '+reject.thech_unit_name+' '+ StrUtil.sheetName(dBook,dSheet));
						lastBook=dBook;
						lastSheet=dSheet;
					}else{
						//skip book
						lastBook=dBook;
						//align at the end sheet 
						//cover 
						lastSheet=0;
						if(bookPart==BookSynonym.BOOK_PART_BLOCKCOVER){
							lastSheet=revers?1:0;
						}else if(bookPart==BookSynonym.BOOK_PART_BLOCK){
							lastSheet=revers?1:sheets;
						}
						logMsg('Пропуск брака '+reject.thech_unit_name+' до '+ StrUtil.sheetName(lastBook,lastSheet));
					}
					//prevent posible recursive bug
					if(lastBook<=0 || lastBook>books){
						//out of book sequence
						logSequeceErr('Ошибка пропуска брака '+ StrUtil.sheetName(lastBook,lastSheet));
						return false;
					}
					
					return checkSequece(book,sheet);
				}
			}
			if(!result){
				if(canInterrupt && flap) flap.setOff();
				if(logError){
					logSequeceErr('Не верная последовательность: '+ StrUtil.sheetName(book,sheet)+' вместо '+ StrUtil.sheetName(dBook,dSheet));
				}else{
					if(lastBook==book && lastSheet==sheet){
						logSequeceErr('Повтор последовательности: '+ StrUtil.sheetName(book,sheet));
					}
					if(!hasWrongSequence) logSequeceErr('Не верная последовательность');
				}
				hasWrongSequence=true;
			}
			return result;
		}
		
		protected function logSequeceErr(msg:String):void{
			dispatchEvent( new ErrorEvent(ErrorEvent.ERROR,false,false,'Заказ: '+printGroupId+'. '+msg,ERROR_SEQUENCE));
		}
		protected function logMsg(msg:String):void{
			dispatchEvent( new ErrorEvent(ErrorEvent.ERROR,false,false,'Заказ: '+printGroupId+'. '+msg,0));
		}
		
		protected function get sheetsPerBook():int{
			if(bookPart==BookSynonym.BOOK_PART_COVER){
				return 1;
			}
			return sheets;
		}

	}
}