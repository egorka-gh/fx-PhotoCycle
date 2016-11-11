package com.photodispatcher.tech.register{
	import com.photodispatcher.model.mysql.entities.BookSynonym;
	import com.photodispatcher.model.mysql.entities.PrintGroup;
	import com.photodispatcher.model.mysql.entities.PrintGroupReject;
	
	import flash.events.ErrorEvent;
	import flash.events.EventDispatcher;
	
	[Event(name="complete", type="flash.events.Event")]
	[Event(name="error", type="flash.events.ErrorEvent")]
	public class PGRegister extends EventDispatcher{
		public static const DIRECTION_DETECT:int=0;
		public static const DIRECTION_NORMAL:int=1;
		public static const DIRECTION_REVERS:int=-1;

		public var printgroup:PrintGroup;

		private var _direction:int;
		public function get direction():int{
			return _direction;
		}

		private var regItems:Array;
		private var toRegisterNum:int;
		private var rejectedNum:int;
		
		private var registered:int;
		private var lastIndex:int;
		
		
		
		public function PGRegister(printgroup:PrintGroup, direction:int=DIRECTION_DETECT){
			super(null);
			this.printgroup=printgroup;
			this._direction=direction;
			init();
			lastIndex=-1;
		}
		
		private function init():void{
			if(!printgroup) return;
			//fill items
			regItems=[];
			var i:int;
			var j:int;
			var item:RegisterItem;
			if(!isReprint){
				//normal pg
				printgroup.compactRejects();
				for (i = 1; i <= printgroup.book_num; i++){
					if(printgroup.book_part==BookSynonym.BOOK_PART_COVER){
						item=new RegisterItem(i,0,printgroup.id, printgroup.isSheetRejected(i,0));
						if(item.isRejected) rejectedNum++; else toRegisterNum++;
						regItems.push(item); 
					}else{
						//block items
						for (j = 1; j <= printgroup.sheet_num; j++){
							item=new RegisterItem(i,j,printgroup.id, printgroup.isSheetRejected(i,j));
							if(item.isRejected) rejectedNum++; else toRegisterNum++;
							if(j == printgroup.sheet_num && printgroup.book_part==BookSynonym.BOOK_PART_BLOCKCOVER) item.sheet=0;
							regItems.push(item);
						}
					}
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
				
				for each(reject in rejectsArr){
					if(reject.sheet==1000000) reject.sheet=0;
					if(reject.sheet==-1){
						//add whole book
						if(printgroup.book_part==BookSynonym.BOOK_PART_COVER){
							item=new RegisterItem(reject.book,0,printgroup.id);
							toRegisterNum++;
							regItems.push(item);
						}else{
							for (j = 1; j <= printgroup.sheet_num; j++){
								item=new RegisterItem(reject.book,j,printgroup.id);
								toRegisterNum++;
								if(j == printgroup.sheet_num && printgroup.book_part==BookSynonym.BOOK_PART_BLOCKCOVER) item.sheet=0;
								regItems.push(item);
							}
						}
					}else{
						item=new RegisterItem(reject.book,reject.sheet,printgroup.id);
						toRegisterNum++;
						regItems.push(item);
					}
				}
			}
			if(direction==DIRECTION_REVERS) reorderRegItems();
		}

		public function register(regItem:RegisterItem):Boolean{
			if(!regItem){
				logErr('Ошибка выполнения null regItem');
				return false;
			}
			
		}
		
		
		private function getItemIndex(item:RegisterItem){
			if(!item || !regItems || regItems.length==0) return -1;
			var idx:int = -1;
			regItems.some(function (element:Object, index:int, arr:Array):Boolean {
				var it:RegisterItem=element as RegisterItem;
				var res:Boolean = it && it.book==item.book && it.sheet==item.sheet;
				if(res) idx = index;
				return res;
			});
			return idx;
		}
		
		private function currentItem():RegisterItem{
			if(!regItems || lastIndex>=regItems.length || lastIndex<0) return null;
			return regItems[lastIndex] as RegisterItem;
		}

		private function nextItem(skipRejects:Boolean=true, revers:Boolean=false):RegisterItem{
			if(!regItems) return null;
			var item:RegisterItem;
			var startIdx:int=lastIndex;
			var offset:int=1;
			if(revers){
				if(lastIndex==-1) startIdx=regItems.length-1;
				offset=-1;
			}
			while(skipRejects && (startIdx+offset)<regItems.length && (startIdx+offset)>=0){
				item=regItems[startIdx+offset] as RegisterItem;
				if(item && !item.isRejected) break;
				if(revers){
					offset--;	
				}else{
					offset++;
				}
			}
			if((startIdx+offset)<regItems.length && (startIdx+offset)>=0) item=regItems[startIdx+offset] as RegisterItem;
			return item;
		}
		
		private function reorderRegItems():void{
			if(!regItems) return;
			regItems.reverse();
		}
		
		public function get isReprint():Boolean{
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