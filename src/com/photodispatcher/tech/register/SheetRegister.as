package com.photodispatcher.tech.register{
	import com.photodispatcher.model.mysql.entities.PrintGroup;
	
	public class SheetRegister{
		
		public static function fromBarcode(barcode:String):SheetRegister{
			var sTmp:String=PrintGroup.digitIdFromTechBarcode(barcode);
			if(!sTmp) return null;
			return new SheetRegister(PrintGroup.bookFromTechBarcode(barcode),PrintGroup.sheetFromTechBarcode(barcode),PrintGroup.idFromDigitId(sTmp)); 
		}
		
		public var pgId:String;
		public var book:int;
		public var sheet:int;

		public var isRejected:Boolean;
		public var hasError:Boolean;
		
		private var _isRegistered:Boolean;
		public function get isRegistered():Boolean{
			return _isRegistered;
		}
		public function set isRegistered(value:Boolean):void{
			_isRegistered = value;
			if(_isRegistered){
				regTime=new Date();
			}else{
				regTime=null;
			}
		}

		public var regTime:Date;
		
		public function SheetRegister(book:int, sheet:int, pgId:String='', isRejected:Boolean=false){
			this.book=book;
			this.sheet=sheet;
			this.pgId=pgId;
			this.isRejected=isRejected;
		}
		
		public function isEqual(to:SheetRegister):Boolean{
			return to && (!to.pgId || !pgId || to.pgId==pgId) && to.book==book && to.sheet==sheet;
		}
	}
}