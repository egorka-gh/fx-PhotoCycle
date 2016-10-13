package com.photodispatcher.tech{
	import com.photodispatcher.model.mysql.entities.PrintGroup;
	
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
			for (var i:int = 1; i <= printgroup.book_num; i++){
				if(revers){
					book= new TechBook(printgroup.book_num-i+1)
				}else{
					book= new TechBook(i)
				}
				booksAC.addItem(book);
			}
			currIdx=0;
		}

		private function getBook(idx:int):TechBook{
			if(!booksAC || idx<0 || idx>=booksAC.length) return null;
			return booksAC.getItemAt(idx) as TechBook;
		}
		
		private var lastBookNum:int=-1;
		public function register(bookNum:int):void{
			//TODO check rejects
			if(!booksAC || booksAC.length==0) return;
			if(lastBookNum==bookNum) return;
			lastBookNum=bookNum;
			if(bookNum<1 || bookNum>booksAC.length){
				logErr('Не допустимый номер книги ' +bookNum.toString());
				return;
			}
			var book:TechBook=getBook(currIdx);
			if(!book){
				//logErr('Не допустимый номер книги');
				logMsg('Ошибка выполнения нет книги с индексом ' +currIdx.toString());
				return;
			}
			if(book.book!=bookNum){
				logErr('Ошибка последовательности книг в '+(printgroup?printgroup.id:'')+'. '+ bookNum+' вместо '+book.book);
			}
			currIdx++;
		}
		
		protected function logErr(msg:String):void{
			dispatchEvent( new ErrorEvent(ErrorEvent.ERROR,false,false,msg,1));
		}
		protected function logMsg(msg:String):void{
			dispatchEvent( new ErrorEvent(ErrorEvent.ERROR,false,false,msg,0));
		}

	}
}