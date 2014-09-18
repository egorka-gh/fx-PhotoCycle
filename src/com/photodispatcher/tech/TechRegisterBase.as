package com.photodispatcher.tech{
	import com.photodispatcher.event.AsyncSQLEvent;
	import com.photodispatcher.model.mysql.DbLatch;
	import com.photodispatcher.model.mysql.entities.BookSynonym;
	import com.photodispatcher.model.mysql.entities.TechLog;
	import com.photodispatcher.model.mysql.entities.TechPoint;
	import com.photodispatcher.model.mysql.services.TechService;
	import com.photodispatcher.service.barcode.ValveCom;
	import com.photodispatcher.util.ArrayUtil;
	import com.photodispatcher.util.StrUtil;
	
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	
	import org.granite.tide.Tide;
	
	[Event(name="complete", type="flash.events.Event")]
	[Event(name="error", type="flash.events.ErrorEvent")]
	public class TechRegisterBase extends EventDispatcher{
		public static const ERROR_SEQUENCE:int=1;

		public var techPoint:TechPoint;
		public var printGroupId:String;
		public var books:int;
		public var sheets:int;
		public var revers:Boolean=false;
		public var flap:ValveCom;
		public var inexactBookSequence:Boolean=false;
		public var detectFirstBook:Boolean=false;
		
		private var regArray:Array;
		private var bookPart:int;
		private var lastBook:int;
		private var lastSheet:int;
		private var registred:int;
		
		protected var logOk:Boolean;
		
		public function TechRegisterBase(printGroup:String, books:int,sheets:int){
			super(null);
			printGroupId=printGroup;
			this.books=books;
			this.sheets=sheets;
			regArray = new Array(books);
			bookPart=BookSynonym.BOOK_PART_ANY;
			registred=0;
			logOk=true;
			//complited=false;
		}
		
		public function register(book:int,sheet:int):void{
			if(bookPart==BookSynonym.BOOK_PART_ANY){
				if(sheet==0){
					bookPart=BookSynonym.BOOK_PART_COVER;
				}else{
					bookPart=BookSynonym.BOOK_PART_BLOCK;
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
			if(log) logRegistred(book,sheet);
			dispatchEvent(new Event(Event.COMPLETE));
		}
		
		protected function logRegistred(book:int,sheet:int):void{
			//log to data base
			var tl:TechLog= new TechLog();
			tl.log_date=new Date();
			tl.setSheet(book,sheet);
			tl.print_group=printGroupId;
			tl.src_id= techPoint.id;
			var latch:DbLatch=new DbLatch();
			var svc:TechService=Tide.getInstance().getContext().byType(TechService,true) as TechService;
			//latch.addEventListener(Event.COMPLETE,onLog);
			latch.addLatch(svc.logByPg(tl));
			latch.start();
		}
		
		public function get isComplete():Boolean{
			if(inexactBookSequence) return false;//can't detect
			if(detectFirstBook){
				//check last book & last sheet 
				var endSheet:int=0;
				if(bookPart==BookSynonym.BOOK_PART_BLOCK) endSheet=revers?1:sheets;
				if(lastBook==books && lastSheet==endSheet) return true;
			}
			if(bookPart==BookSynonym.BOOK_PART_BLOCK && registred==books*sheets){
				return true;
			}
			if(bookPart==BookSynonym.BOOK_PART_COVER && registred==books){//one cover per book
				return true;
			}
			return false;
		}

		protected function get dueBook():int{
			if(!lastBook) return revers?books:1;
			if(bookPart==BookSynonym.BOOK_PART_COVER){
				return revers?(lastBook-1):(lastBook+1);
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

		protected var _canInterrupt:Boolean=false;
		public function get canInterrupt():Boolean{
			return _canInterrupt;
		}

		protected var _strictSequence:Boolean=false;
		public function get strictSequence():Boolean{
			return _strictSequence;
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
			return result;
		}

		protected function checkSequece(book:int,sheet:int):Boolean{
			var dBook:int=dueBook;
			var dSheet:int=dueSheet;
			var result:Boolean;
			if(isComplete){
				if(canInterrupt && flap) flap.setOff();
				logSequeceErr('Должен быть следующий заказ: '+ StrUtil.sheetName(book,sheet)+' при завершенной последовательности.' );
				return false;
			}
			if(inexactBookSequence){
				var firstSheet:int=0;
				if(bookPart==BookSynonym.BOOK_PART_BLOCK) firstSheet=revers?sheets:1;
				if(dueSheet==firstSheet) dBook=book;
			}else if(detectFirstBook){
				dBook=book;
				detectFirstBook=false;
			}
			
			result=dBook==book && dSheet==sheet;
			if(!result){
				if(canInterrupt && flap) flap.setOff();
				logSequeceErr('Не верная последовательность: '+ StrUtil.sheetName(book,sheet) +' вместо '+ StrUtil.sheetName(dBook,dSheet));
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
		
		/*************** local data base ************************/
		/*
		protected var complited:Array=[];
		protected var isWriting:Boolean;
		
		protected function checkComplited():void{
			var lDao:TechPrintGroupDAO= new TechPrintGroupDAO();
			var arr:Array=lDao.finde4Transfer();
			var pg:TechPrintGroup;
			if(arr){
				for each(pg in arr){
					if(ArrayUtil.searchItemIdx('id',pg.id,complited)==-1) complited.push(pg);
				}
			}
			if(!isWriting) writeNext();
		}
		
		protected function writeNext():TechPrintGroup{
			if(complited.length==0){
				isWriting=false;
				return null;
			}
			isWriting=true;
			var pg:TechPrintGroup= complited[0] as TechPrintGroup;
			if(!pg){
				complited.shift();
				return writeNext();
			}
			return pg;
			// implement concret dao call
			//var pdao:PrintGroupDAO=new PrintGroupDAO();
			//pdao.execOnItem=pg.id;
			//pdao.addEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT, onExtraWrite);
			//pdao.setExtraStateByTech(pg.id, pg.src_id);
		}
		protected function onExtraWrite(evt:AsyncSQLEvent):void{
			var pdao:BaseDAO= evt.target as BaseDAO;
			if(pdao) pdao.removeEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT, onExtraWrite);
			//var pgId:String=evt.item as String;
			var pg:TechPrintGroup=evt.item as TechPrintGroup;
			if (evt.result==AsyncSQLEvent.RESULT_COMLETED){
				if(pg){
					var lDao:TechPrintGroupDAO= new TechPrintGroupDAO();
					if(pg.isComplite){
						lDao.remove(pg.id);
					}else{
						lDao.startLoged(pg.id);
					}
				}
				complited.shift();
				writeNext();
			}else{
				//database locked
				complited=[];
				isWriting=false;
			}
		}
		*/

	}
}