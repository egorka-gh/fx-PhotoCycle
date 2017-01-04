package com.photodispatcher.tech.register{
	import com.photodispatcher.model.mysql.entities.BookSynonym;
	import com.photodispatcher.model.mysql.entities.PrintGroup;
	import com.photodispatcher.model.mysql.entities.PrintGroupReject;
	import com.photodispatcher.util.StrUtil;
	
	import flash.events.ErrorEvent;
	import flash.events.EventDispatcher;
	
	[Event(name="complete", type="flash.events.Event")]
	[Event(name="error", type="flash.events.ErrorEvent")]
	public class PGRegister extends EventDispatcher{
		public static const DIRECTION_DETECT:int=0;
		public static const DIRECTION_NORMAL:int=1;
		public static const DIRECTION_REVERS:int=-1;

		public var printgroup:PrintGroup;
		public var strictMode:Boolean;
		public var disallowRejects:Boolean;

		public var booksRejected:int;
		public var booksRegistred:int;

		private var _direction:int;
		public function get direction():int{
			return _direction;
		}

		//private var regItems:Array;
		private var toRegisterNum:int;
		private var rejectedNum:int;
		
		private var registered:int;
		
		
		private var books:Array;
		private var bookIndex:int;
		
		
		public function PGRegister(printgroup:PrintGroup, direction:int=DIRECTION_DETECT){
			super(null);
			this.printgroup=printgroup;
			this._direction=direction;
			init();
			bookIndex=0;
		}
		
		private function init():void{
			if(!printgroup) return;
			//fill books & items in normal direction
			books=[];
			var i:int;
			var j:int;
			var rbook:BookRegister;
			var item:SheetRegister;
			if(!isReprint){
				//normal pg
				printgroup.compactRejects();
				for (i = 1; i <= printgroup.book_num; i++){
					rbook= new BookRegister(i,printgroup.id);
					rbook.strictMode=strictMode;
					rbook.disallowRejects=disallowRejects;
					if(printgroup.book_part==BookSynonym.BOOK_PART_COVER){
						item=new SheetRegister(i,0,printgroup.id, printgroup.isSheetRejected(i,0));
						if(item.isRejected) rejectedNum++; else toRegisterNum++;
						rbook.addSheet(item);
					}else{
						//block items
						for (j = 1; j <= printgroup.sheet_num; j++){
							item=new SheetRegister(i,j,printgroup.id, printgroup.isSheetRejected(i,j));
							if(item.isRejected) rejectedNum++; else toRegisterNum++;
							if(j == printgroup.sheet_num && printgroup.book_part==BookSynonym.BOOK_PART_BLOCKCOVER) item.sheet=0;
							rbook.addSheet(item);
						}
					}
					books.push(rbook);
				}
			}else{
				//reprint
				var reject:PrintGroupReject;
				var rejectsArr:Array=[];
				//look for rejects
				for each(reject in printgroup.rejects){
					if(reject && reject.print_group==printgroup.id){
						if(reject.sheet=0 && printgroup.book_part==BookSynonym.BOOK_PART_BLOCKCOVER) reject.sheet=1000000; //4 correct sorting 
						rejectsArr.push(reject);
					}
				}
				//reorder rejects
				if(rejectsArr.length>1) rejectsArr.sortOn(['book','sheet'],[Array.NUMERIC,Array.NUMERIC]); 

				rbook=null;
				for each(reject in rejectsArr){
					if(!rbook || rbook.book!=reject.book){
						if(rbook) books.push(rbook);
						rbook= new BookRegister(reject.book,printgroup.id);
						rbook.strictMode=strictMode;
						rbook.disallowRejects=disallowRejects;
					}
					if(reject.sheet==1000000) reject.sheet=0;
					if(reject.sheet==-1){
						//add whole book
						if(printgroup.book_part==BookSynonym.BOOK_PART_COVER){
							item=new SheetRegister(reject.book,0,printgroup.id);
							toRegisterNum++;
							rbook.addSheet(item);
						}else{
							for (j = 1; j <= printgroup.sheet_num; j++){
								item=new SheetRegister(reject.book,j,printgroup.id);
								toRegisterNum++;
								if(j == printgroup.sheet_num && printgroup.book_part==BookSynonym.BOOK_PART_BLOCKCOVER) item.sheet=0;
								rbook.addSheet(item);
							}
						}
					}else{
						item=new SheetRegister(reject.book,reject.sheet,printgroup.id);
						toRegisterNum++;
						rbook.addSheet(item);
					}
				}
				//add last rbook
				if(rbook) books.push(rbook);
			}
			if(direction==DIRECTION_REVERS) reorderRegItems();
		}

		public function get booksTotal():int{
			if(books)
				return books.length;
			else
				return 0;
		}
		
		public function get complited():Boolean{
			if(!books) return false;
			return booksTotal==booksRegistred || 
				(!rejectRegistred  && sheetsTotal==(sheetsRegistred+sheetsRejected));
		}

		private var prevItem:SheetRegister;
		
		public function register(regItem:SheetRegister):int{
			if(!regItem){
				logMsg('Ошибка выполнения (null regItem).');
				return RegisterResult.ALLREADY_REGISTRED;
			}
			if(!printgroup){
				logMsg('Ошибка инициализации (null printgroup).');
				return RegisterResult.ERR_NOT_FOUND;
			}
			if(!regItem.pgId || regItem.pgId!=printgroup.id) return RegisterResult.ERR_NOT_MY;
			
			if(regItem.book<1 || regItem.book>printgroup.book_num || regItem.sheet<0 || regItem.sheet>printgroup.sheet_num){
				logErr('Ошибка. Не допустимый лист: '+StrUtil.sheetName(regItem.book,regItem.sheet));
				return RegisterResult.ERR_NOT_FOUND;
			}
			if(!books || books.length==0){
				logErr('Ошибка инициализации, пустой массив книг.');
				return RegisterResult.ERR_NOT_FOUND;
			}

			var res:int;
			if(direction==DIRECTION_NORMAL || direction==DIRECTION_DETECT){
				res=registerInternal(regItem,DIRECTION_NORMAL);
				if(direction==DIRECTION_DETECT){
					if(res>0){
						_direction=DIRECTION_NORMAL;
					}else{
						//try in revers order 
						bookIndex=0;
						reorderRegItems();
						res=registerInternal(regItem,DIRECTION_REVERS);
						if(res>0){
							_direction=DIRECTION_REVERS;
						}else{
							bookIndex=0;
							_direction=DIRECTION_NORMAL;
							reorderRegItems();
							res=registerInternal(regItem,DIRECTION_REVERS);
						}
					}
				}
			}else{
				res=registerInternal(regItem,DIRECTION_REVERS);
			}
			if(res>0){
				prevItem=regItem;
				return res;
			}
			var msg:String=RegisterResult.getCaption(res)+'. '+ regItem.caption;
			if(prevItem) msg=msg+' после '+prevItem.caption;
			logErr(msg);
			if(strictMode) return res;
			prevItem=regItem;
			//look up book & register
			
			
		}
		
		private function registerInternal(regItem:SheetRegister, regDir:int):int{
			var res:int;
			var idx:int;
			var currBook:BookRegister=getBook(bookIndex);
			var canMove:Boolean;
			if(currBook){
				res=currBook.register(regItem);
				if(res>0 || regItem.book==currBook.book) return res;
				canMove=res==RegisterResult.ERR_NOT_MY && currBook.complited()
					&& ((regDir==DIRECTION_NORMAL && regItem.book>currBook.book) || (regDir==DIRECTION_REVERS && regItem.book<currBook.book))
					&& bookIndex<(books.length-1) ;
				if(canMove){
					bookIndex++;
					return registerInternal(regItem);
				}
			}
			return RegisterResult.ERR_WRONG_SEQ;
		}
		
		public function reset():void{
			if(registered>0){
				
			}
			registered=0;
		}
		
		
		public function getBook(idx:int):BookRegister{
			if(!books  || idx>=books.length) return null;
			if(idx==-1){
				//get last
				return books[books.length-1] as BookRegister;  
			}
			return books[idx] as BookRegister;  
		}

		
		private function reorderRegItems():void{
			if(!books) return;
			books.reverse();
			var rbook:BookRegister;
			for each(rbook in books) rbook.setRevers(!rbook.isRevers);
		}

		
		/*
		private function getItemIndex(item:SheetRegister){
			if(!item || !regItems || regItems.length==0) return -1;
			var idx:int = -1;
			regItems.some(function (element:Object, index:int, arr:Array):Boolean {
				var it:SheetRegister=element as SheetRegister;
				var res:Boolean = it && it.book==item.book && it.sheet==item.sheet;
				if(res) idx = index;
				return res;
			});
			return idx;
		}
		
		private function currentItem():SheetRegister{
			if(!regItems || lastIndex>=regItems.length || lastIndex<0) return null;
			return regItems[lastIndex] as SheetRegister;
		}

		private function getNextItem(skipRejects:Boolean=true, revers:Boolean=false):SheetRegister{
			if(!regItems) return null;
			var item:SheetRegister;
			var startIdx:int=lastIndex;
			var offset:int=1;
			if(revers){
				if(lastIndex==-1) startIdx=regItems.length-1;
				offset=-1;
			}
			while(skipRejects && (startIdx+offset)<regItems.length && (startIdx+offset)>=0){
				item=regItems[startIdx+offset] as SheetRegister;
				if(item && !item.isRejected) break;
				if(revers){
					offset--;	
				}else{
					offset++;
				}
			}
			if((startIdx+offset)<regItems.length && (startIdx+offset)>=0) item=regItems[startIdx+offset] as SheetRegister;
			return item;
		}
		
		*/
		
		public function get isReprint():Boolean{
			return printgroup && printgroup.is_reprint;
		}

		protected function logErr(msg:String):void{
			if(printgroup) msg=printgroup.id+' '+msg;
			dispatchEvent( new ErrorEvent(ErrorEvent.ERROR,false,false,msg,1));
		}
		protected function logMsg(msg:String):void{
			if(printgroup) msg=printgroup.id+' '+msg;
			dispatchEvent( new ErrorEvent(ErrorEvent.ERROR,false,false,msg,0));
		}

	}
}