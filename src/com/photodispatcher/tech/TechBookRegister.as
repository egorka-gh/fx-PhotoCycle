package com.photodispatcher.tech{
	import com.photodispatcher.model.mysql.entities.PrintGroup;
	import com.photodispatcher.model.mysql.entities.PrintGroupReject;
	
	import flash.events.ErrorEvent;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	
	import mx.collections.ArrayCollection;
	
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
		public var revers:Boolean;
		[Bindable]
		public var currIdx:int;

		
		private function init():void{
			booksAC=new ArrayCollection();
			if(!printgroup || !printgroup.book_num) return;
			var book:TechBook;
			book.checkState=PrintGroup.CHECK_STATUS_IN_CHECK;
			for (var i:int = 1; i <= printgroup.book_num; i++){
				if(revers){
					book= new TechBook(printgroup.book_num-i+1)
				}else{
					book= new TechBook(i)
				}
				booksAC.addItem(book);
			}
			if(printgroup.rejects){
				//mark rejectet
				var reject:PrintGroupReject;
				for each(book in booksAC){
					for each(reject in printgroup.rejects){
						if(reject.book==book.book){
							book.checkState=PrintGroup.CHECK_STATUS_REJECT;
							book.isRejected=true;
							break;
						}
					}
				}
			}
			currIdx=0;
		}

		private function getBook(idx:int):TechBook{
			var book:TechBook;
			if(booksAC && idx>=0 && idx<booksAC.length) book=booksAC.getItemAt(idx) as TechBook;
			if(!book) logMsg('Ошибка выполнения нет книги с индексом ' +idx.toString());
			return book;
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
				
				//is rejected
				book=getBook(bookNum-1);
				if(book && book.isRejected){
					logErr('Не убран брак '+printgroupCaption+' книга '+bookNum.toString());
					book.checkState=PrintGroup.CHECK_STATUS_ERR;
					return false;
				}

				//try to register
				//is out off sequence?
				if(currIdx>=booksAC.length){
					logErr('Последовательности книг завершена '+printgroupCaption+'. '+ bookNum);
					return false;
				}
				//get current
				book=getBook(currIdx);
				//skip rejects
				while(book && book.isRejected){
					currIdx++;
					if(currIdx<booksAC.length){
						book=getBook(currIdx);
					}else{
						book=null;
					}
				}
				//is out off sequence?
				if(currIdx>=booksAC.length){
					logErr('Последовательности книг завершена '+printgroupCaption+'. '+ bookNum);
					return false;
				}
				//check
				if(book){
					if(book.book!=bookNum){
						logErr('Ошибка последовательности книг в '+printgroupCaption+'. '+ bookNum+' вместо '+book.book);
						book.checkState=PrintGroup.CHECK_STATUS_ERR;
						return false;
					}else{
						book.checkState=PrintGroup.CHECK_STATUS_OK;
						currIdx++;
						return true;
					}
				}
			}else{
				//reprint
				//TODO implement
				return true;
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