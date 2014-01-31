package com.photodispatcher.tech{
	import com.photodispatcher.model.BookSynonym;
	import com.photodispatcher.model.TechPoint;
	import com.photodispatcher.service.barcode.ValveCom;
	import com.photodispatcher.util.StrUtil;
	
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	
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
			if(regArray[idx] == undefined) regArray[idx]=new Array(sheets+1);//+1 for 0
			if(regArray[idx][sheet] == undefined){
				regArray[idx][sheet]=new Date();
				registred++;
			}
			dispatchEvent(new Event(Event.COMPLETE));
		}
		
		public function get isComplete():Boolean{
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
			if (!isComplete){
				if(canInterrupt){
					if(flap) flap.setOff();
					if(strictSequence) result=false;
				}
				var book:int=revers?1:books;
				var sheet:int=0;
				if (bookPart!=BookSynonym.BOOK_PART_COVER) sheet=revers?1:sheets;
				logSequeceErr('Не верное завершение последовательности: '+ StrUtil.sheetName(lastBook,lastSheet) +' вместо '+ StrUtil.sheetName(book,sheet));
			}else{
				if(logOk) logMsg('Ok');
			}
			return result;
		}

		protected function checkSequece(book:int,sheet:int):Boolean{
			//throw new Error("You need to override checkSequece() in your concrete class");
			var dBook:int=dueBook;
			var dSheet:int=dueSheet;
			var result:Boolean;
			if(isComplete){
				if(canInterrupt && flap) flap.setOff();
				logSequeceErr('Должен быть следующий заказ: '+ StrUtil.sheetName(book,sheet)+' при завершенной последовательности.' );
				return false;
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
	}
}