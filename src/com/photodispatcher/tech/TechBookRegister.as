package com.photodispatcher.tech{
	import com.photodispatcher.model.mysql.entities.PrintGroup;
	import com.photodispatcher.model.mysql.entities.PrintGroupReject;
	
	import flash.events.ErrorEvent;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	
	import mx.collections.ArrayCollection;
	import com.photodispatcher.tech.register.TechBook;
	
	[Event(name="complete", type="flash.events.Event")]
	[Event(name="error", type="flash.events.ErrorEvent")]
	public class TechBookRegister extends EventDispatcher{
		
		public function TechBookRegister(printgroup:PrintGroup, revers:Boolean=false){
			super(null);
			this.printgroup=printgroup;
			this.revers=revers;
			init();
		}
		
		[Bindable]
		public var isStarted:Boolean;
		[Bindable]
		public var printgroup:PrintGroup;
		[Bindable]
		public var booksAC:ArrayCollection;
		[Bindable]
		public var revers:Boolean;
		
		[Bindable]
		public var currBook:TechBook;
		[Bindable]
		public var currIndex:int=-1;
		
		
		private var _currIdx:int=-1;
		protected function get currIdx():int{
			return _currIdx;
		}
		protected function set currIdx(value:int):void{
			_currIdx = value;
			if(booksAC && _currIdx>=0 && _currIdx<booksAC.length){
				currIndex=_currIdx;
				currBook=booksAC.getItemAt(_currIdx) as TechBook;
			}else{
				currIndex=-1;
				currBook=null;
			}
		}

		
		[Bindable]
		public var booksToRegister:int=0;

		
		private function init():void{
			booksAC=new ArrayCollection();
			if(!printgroup || !printgroup.book_num) return;
			var book:TechBook;
			for (var i:int = 1; i <= printgroup.book_num; i++){
				if(revers){
					book= new TechBook(printgroup.book_num-i+1)
				}else{
					book= new TechBook(i)
				}
				book.checkState=PrintGroup.CHECK_STATUS_IN_CHECK;
				booksAC.addItem(book);
			}
			if(!printgroup.is_reprint) booksToRegister=printgroup.book_num;
			if(printgroup.rejects){
				//mark rejectet
				var reject:PrintGroupReject;
				for each(book in booksAC){
					if(!printgroup.is_reprint){
						for each(reject in printgroup.rejects){
							if(reject.book==book.book){
								book.checkState=PrintGroup.CHECK_STATUS_REJECT;
								book.isRejected=true;
								booksToRegister--;
								break;
							}
						}
					}else{
						//reprint, only printgroup rejects in check 
						book.checkState=PrintGroup.CHECK_STATUS_REJECT;
						book.isRejected=true;
						for each(reject in printgroup.rejects){
							if(printgroup.id==reject.print_group && reject.book==book.book){
								book.checkState=PrintGroup.CHECK_STATUS_IN_CHECK;
								book.isRejected=false;
								booksToRegister++;
								break;
							}
						}
					}
				}
			}
			currIdx=0;
			//move to fist valid book
			skipRejected();
		}

		private function getBookByIdx(idx:int):TechBook{
			var book:TechBook;
			if(booksAC && idx>=0 && idx<booksAC.length) book=booksAC.getItemAt(idx) as TechBook;
			if(!book) logMsg('Ошибка выполнения нет книги с индексом ' +idx.toString());
			return book;
		}
		
		private function getBookByNum(bookNum:int):TechBook{
			if(!booksAC || booksAC.length==0) return null;
			var book:TechBook;
			if(revers){
				book=getBookByIdx(booksAC.length-bookNum);
			}else{
				book=getBookByIdx(bookNum-1);
			}
			return book;
		}
		
		public function get isComplited():Boolean{
			return currIdx>=booksAC.length;
		}
		
		public function moveIndex(forward:Boolean=true):void{
			if(!booksAC || booksAC.length==0) return;
			if(forward){
				if(currIdx<(booksAC.length-1)) currIdx=currIdx+1;
			}else{
				if(currIdx>0) currIdx=currIdx-1;
			}
		}
		
		private var lastBookNum:int=-1;
		public function register(bookNum:int):Boolean{
			if(!booksAC || booksAC.length==0) return false;
			if(lastBookNum==bookNum) return true;
			lastBookNum=bookNum;
			if(bookNum<1 || bookNum>booksAC.length){
				logErr('Не допустимый номер книги ' +bookNum.toString());
				return false;
			}
			var book:TechBook;
			
			if(!isReprint){
				//normal print group
				//is rejected?
				book=getBookByNum(bookNum);
				if(book && book.isRejected){
					logErr('Не убран брак '+printgroupCaption+' книга '+bookNum.toString());
					book.checkState=PrintGroup.CHECK_STATUS_ERR;
					return false;
				}
			}

			//try to register
			//is out off sequence?
			if(currIdx>=booksAC.length){
				logErr('Последовательности книг завершена '+printgroupCaption+'. '+ bookNum);
				return false;
			}
			
			//get current
			book=getBookByIdx(currIdx);
			//check
			if(book){
				if(book.book!=bookNum){
					logErr('Ошибка последовательности книг в '+printgroupCaption+'. '+ bookNum+' вместо '+book.book);
					book.checkState=PrintGroup.CHECK_STATUS_ERR;
					return false;
				}else{
					book.checkState=PrintGroup.CHECK_STATUS_OK;
					currIdx=currIdx+1;
					skipRejected();
					return true;
				}
			}
			//never runs
			return false;
		}
		
		private function skipRejected():void{
			if(!booksAC || booksAC.length==0) return;
			var book:TechBook;
			while(currIdx<booksAC.length){
				//get current
				book=getBookByIdx(currIdx);
				if(book && book.isRejected){
					//skip
					logMsg('Пропускаю книгу ' +book.book+ (!isReprint?' Брак':''));
					currIdx=currIdx+1;
				}else{
					break;
				}
			}
		}
		
		protected function get printgroupCaption():String{
			return printgroup?printgroup.id:'';
		}

		protected function get isReprint():Boolean{
			return printgroup && printgroup.is_reprint;
		}

		protected function logErr(msg:String):void{
			dispatchEvent( new ErrorEvent(ErrorEvent.ERROR,false,false,msg,1));
		}
		protected function logMsg(msg:String):void{
			dispatchEvent( new ErrorEvent(ErrorEvent.ERROR,false,false,msg,0));
		}

	}
}