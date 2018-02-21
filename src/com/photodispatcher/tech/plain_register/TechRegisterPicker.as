package com.photodispatcher.tech.plain_register{
	
	import com.photodispatcher.model.mysql.entities.BookSynonym;
	import com.photodispatcher.util.StrUtil;
	
	import flash.events.Event;

	public class TechRegisterPicker extends TechRegisterBase{
		
		public function TechRegisterPicker(printGroup:String, books:int, sheets:int, disconnected:Boolean=false){
			_type=TYPE_PICKER;
			super(printGroup, books, sheets, disconnected);
			logOk=false;
			bookPart=BookSynonym.BOOK_PART_ANY;
			//lastSheet=-1;
			_strictSequence=true;
		}
		
		override public function get strictSequence():Boolean{
			return true;
		}
		
		public function setBookPart(value:int):void{
			bookPart=value;
		}
		
		
		/*
		override public function register(book:int, sheet:int):void{
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
			if(log && !noDataBase){
				if(!calcOnLog){
					_needFlush=true;
					startFlushTimer();
				}
				logRegistred(book,sheet);
			}
			dispatchEvent(new Event(Event.COMPLETE));
		}
		*/
		
		override protected function checkSequece(book:int, sheet:int):Boolean{
			var dBook:int=dueBook;
			var dSheet:int=dueSheet;
			var result:Boolean;
			if(isComplete){
				if(canInterrupt && flap) flap.setOff();
				logSequeceErr('Должен быть следующий заказ: '+ StrUtil.sheetName(book,sheet)+' при завершенной последовательности.' );
				return false;
			}
			if(inexactBookSequence){
				if(dSheet==assumeFirstSheet) dBook=book;
			}else if(detectFirstBook && !lastBook){
				dBook=book;
				//detectFirstBook=false;
			}
			
			result=dBook==book && dSheet==sheet;
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
		
		/*
		override public function finalise():Boolean{
			var result:Boolean=false;
			if(inexactBookSequence || detectFirstBook){
				result=currentBookComplited;
			}else{
				result=isComplete;
			}
			if (!result){
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
		*/
		
		/*
		override public function get isComplete():Boolean{
			if(inexactBookSequence || detectFirstBook) return false;//can't detect
			
			if(bookPart==BookSynonym.BOOK_PART_COVER) return registred>=books; //one cover per book
			return registred>=books*sheets;
		}
		
		override public function get currentBookComplited():Boolean{
			if(!lastBook) return false;
			if(bookPart==BookSynonym.BOOK_PART_COVER) return true;
			return lastSheet==assumeEndSheet;
		}
		*/
		
	}
}