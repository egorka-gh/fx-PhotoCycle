package com.photodispatcher.model{
	public class TechLogLocalKill extends DBRecord{
		
		//database props
		[Bindable]
		public var id:int;
		[Bindable]
		public var print_group:String;
		[Bindable]
		public var src_id:int;
		[Bindable]
		public var log_date:Date;
		
		private var _sheet:int;
		[Bindable]
		public function get sheet():int{
			return _sheet;
		}
		public function set sheet(value:int):void{
			_sheet = value;
			book=Math.floor(_sheet/100);
			page=sheet-book*100;
		}

		public function setSheet(newBook:int, newPage:int):void{
			sheet=newBook*100+newPage;
		}

		//runtime
		[Bindable]
		public var book:int;
		[Bindable]
		public var page:int;
	}
}