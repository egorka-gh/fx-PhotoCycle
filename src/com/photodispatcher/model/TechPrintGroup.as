package com.photodispatcher.model{
	public class TechPrintGroup extends DBRecord{

		//db fileds
		public var id:String
		public var tech_type:int;
		public var start_date:Date;
		public var end_date:Date;
		public var books:int;
		public var sheets:int;
		public var start_loged:int;
		public var done:int;
		
		public function get isComplite():Boolean{
			return done==books*sheets;
		}

	}
}