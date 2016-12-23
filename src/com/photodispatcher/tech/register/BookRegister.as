package com.photodispatcher.tech.register{
	import com.photodispatcher.util.ArrayUtil;
	
	import flash.text.ReturnKeyLabel;

	public class BookRegister{
		
		public var pgId:String;
		public var book:int;

		public var isRejected:Boolean;
		public var hasRejects:Boolean;
		public var hasError:Boolean;
		public var disallowRejects:Boolean;
		public var strictMode:Boolean;

		public var sheetsDeclared:int;
		//public var sheetsTotal:int;
		public var sheetsRejected:int;
		public var sheetsRegistred:int;
		
		private var currIdx:int=0;
		private var sheets:Array;
		//зареген хоть один reject 
		private var rejectRegistred:Boolean;
		
		private var revers:Boolean;
		public function get isRevers():Boolean{
			return revers;
		}
		
		public function get sheetsTotal():int{
			if(sheets)
				return sheets.length;
			else
				return 0;
		}

		public function get complited():Boolean{
			if(!sheets) return false;
			return sheetsTotal==sheetsRegistred || 
				(!rejectRegistred  && sheetsTotal==(sheetsRegistred+sheetsRejected));
		}

		public function setRevers(value:Boolean):void{
			if(revers!=value && sheets){
				//revers items
				sheets.reverse();
			}
			revers=value;
		}


		public function BookRegister(book:int, pgId:String='', isRejected:Boolean=false){
			this.book=book;
			this.pgId=pgId;
			this.isRejected=isRejected;

		}
		
		public function addSheet(sheet:SheetRegister):void{
			if(!sheet) return;
			if(!sheet.pgId || sheet.pgId!=pgId || sheet.book!=book) return;
			//check if exists
			var idx:int=ArrayUtil.searchItemIdx('sheet',sheet.sheet,sheets);
			if(idx!=-1) return;
			if(!sheets) sheets=[];
			sheets.push(sheet);
			if(sheet.isRejected){
				hasRejects=true;
				sheetsRejected++;
			}
			if(sheets.length==sheetsRejected) isRejected=true;
		}
		
		public function register(sheet:SheetRegister):int{
			if(!sheet) return RegisterResult.ALLREADY_REGISTRED;
			if(!sheet.pgId || sheet.pgId!=pgId || sheet.book!=book) return RegisterResult.ERR_NOT_MY;
			if(!sheets) return RegisterResult.ERR_NOT_FOUND;
			var res:int;
			//check next in sequence
			var nextSheet:SheetRegister=getSheet(currIdx);
			if(nextSheet && nextSheet.isEqual(sheet)){
				//ok 
				res=RegisterResult.REGISTRED;
				if(nextSheet.isRegistered){
					res=RegisterResult.ALLREADY_REGISTRED;
				}else{
					if(nextSheet.isRejected){
						if(disallowRejects){
							res=RegisterResult.ERR_REJECTED;
						}else{
							res=RegisterResult.REGISTRED_REJECT;
						}
						rejectRegistred=true;
					}
					sheetsRegistred++;
					nextSheet.isRegistered=true;
				}
				currIdx++;
				return res;
			}
			
			res=RegisterResult.ERR_WRONG_SEQ;
			//try to skip rejected
			if(nextSheet && nextSheet.isRejected){
				var i:int=currIdx+1;
				while(i<sheets.length){
					nextSheet=getSheet(i);
					if(!nextSheet || !nextSheet.isRejected){
						nextSheet=null;
						break;
					}
					if(nextSheet.isEqual(sheet)){
						currIdx=i;
						return register(sheet);
					}
					i++;
				}
			}
			
			if(!strictMode){
				//move index
				var idx:int=ArrayUtil.searchItemIdx('sheet',sheet.sheet,sheets);
				if(idx!=-1){
					//register
					nextSheet=sheets[idx] as SheetRegister;
					if(!nextSheet.isRegistered){
						if(nextSheet.isRejected){
							if(disallowRejects) res=RegisterResult.ERR_REJECTED;
							rejectRegistred=true;
						}
						sheetsRegistred++;
						nextSheet.isRegistered=true;
					}
					currIdx=idx+1;
				}else{
					res=RegisterResult.ERR_NOT_FOUND;
				}
			}
			return res;
		}
		
		public function getSheet(idx:int):SheetRegister{
			if(!sheets || idx>=sheets.length) return null;
			if(idx==-1){
				//get last
				return sheets[sheets.length-1] as SheetRegister;  
			}
			return sheets[idx] as SheetRegister;  
		}
		
		
		public function isEqual(to:BookRegister):Boolean{
			return to && (!to.pgId || !pgId || to.pgId==pgId) && to.book==book;
		}

	}
}