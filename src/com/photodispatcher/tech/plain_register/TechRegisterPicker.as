package com.photodispatcher.tech.plain_register{
	
	import com.photodispatcher.model.mysql.entities.BookSynonym;
	import com.photodispatcher.util.StrUtil;
	
	import flash.events.Event;

	public class TechRegisterPicker extends TechRegisterBase{
		
		public function TechRegisterPicker(printGroup:String, books:int, sheets:int){
			_type=TYPE_PICKER;
			super(printGroup, books, sheets);
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
		
		public var noDataBase:Boolean;
		
		override public function register(book:int, sheet:int):void{
			/*
			if(lastSheet==-1){
				//first scan - bookPart unknown, 4 next scans TechPicker w'l set bookPart 
				if(revers){
					//can detect bookPart
					if(sheet==0){
						bookPart=BookSynonym.BOOK_PART_BLOCKCOVER;
					}else{
						bookPart=BookSynonym.BOOK_PART_BLOCK;
					}
				}
				//if !revers still BOOK_PART_ANY
			}
			*/
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
				var firstSheet:int=-1;
				if(bookPart==BookSynonym.BOOK_PART_BLOCK){
					firstSheet=revers?sheets:1;
				}else{
					firstSheet=revers?0:1;
				}
				if(dueSheet==firstSheet) dBook=book;
			}else if(detectFirstBook){
				dBook=book;
				detectFirstBook=false;
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
		override protected function get dueBook():int{
			if(!lastBook) return revers?books:1; //init
			
			if(bookPart==BookSynonym.BOOK_PART_BLOCK){
				//same as base class
				if(revers){
					return lastSheet==1?(lastBook-1):lastBook;
				}else{
					return lastSheet==sheets?(lastBook+1):lastBook;
				}
			}else if(bookPart==BookSynonym.BOOK_PART_BLOCKCOVER){
				if(revers){
					return lastSheet==1?(lastBook-1):lastBook;
				}else{
					//cover is last
					return lastSheet==0?(lastBook+1):lastBook;
				}
			}
			//not first scan & bookPart still unknown
			return -1;
		}
		
		override protected function get dueSheet():int{
			if(lastSheet==-1 && bookPart==BookSynonym.BOOK_PART_ANY){
				//first scan, bookPart unknown
				//not revers so 
				return 1;
			}
			
			if(bookPart==BookSynonym.BOOK_PART_BLOCK){
				//same as base class
				if(lastSheet==-1) return revers?sheets:1; //init
				if(revers){
					return lastSheet==1?sheets:(lastSheet-1);
				}else{
					return lastSheet==sheets?1:(lastSheet+1);
				}
			}else if(bookPart==BookSynonym.BOOK_PART_BLOCKCOVER){
				//cover is last
				if(lastSheet==-1) return revers?0:1; //init
				if(revers){
					if(lastSheet==1){
						//previous book complited
						//next (first) cover
						return 0; 
					}else if(lastSheet==0){
						//cover, next last sheet
						return sheets-1;
					}
					return lastSheet-1;
				}else{
					if(lastSheet==0){
						//previous book complited  
						return 1; 
					}else if(lastSheet==sheets-1){
						//next cover
						return 0;
					}
					return lastSheet+1;
				}
			}
			
			//not first scan & bookPart still unknown
			return -1;
		}
		
		*/
		
		override public function get isComplete():Boolean{
			if(inexactBookSequence) return false;//can't detect
			if(detectFirstBook){
				//check last book & last sheet
				//TODO not sure, it never run !!!!
				var endSheet:int=0;
				if(bookPart==BookSynonym.BOOK_PART_BLOCK){
					endSheet=revers?1:sheets;
				}else if(bookPart==BookSynonym.BOOK_PART_BLOCKCOVER){
					endSheet=revers?1:0;
				}
				if(lastBook==books && lastSheet==endSheet) return true;
			}
			
			//if(bookPart==BookSynonym.BOOK_PART_BLOCK) return registred>=books*sheets;
			if(bookPart==BookSynonym.BOOK_PART_COVER) return registred>=books; //one cover per book
			return registred>=books*sheets;
		}
		
		override public function get currentBookComplited():Boolean{
			if(!lastBook) return false;
			if(bookPart==BookSynonym.BOOK_PART_COVER) return true;
			var endSheet:int=revers?1:sheets;
			if(bookPart==BookSynonym.BOOK_PART_BLOCKCOVER) endSheet=revers?1:0;
			return lastSheet==endSheet;
		}
		
		
	}
}