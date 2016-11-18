package com.photodispatcher.tech.register{
	
	public class RegisterItem{
		
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
		
		public function RegisterItem(book:int, sheet:int, pgId:String='', isRejected:Boolean=false){
			this.book=book;
			this.sheet=sheet;
			this.pgId=pgId;
			this.isRejected=isRejected;
		}
		
		public function isEqual(to.RegisterItem):Boolean{
			return to && (!to.pgId || !pgId || to.pgId==pgId) && to.book==book && to.sheet==sheet;
		}
	}
}