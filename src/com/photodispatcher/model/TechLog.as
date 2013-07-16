package com.photodispatcher.model{
	
	public class TechLog extends DBRecord{
		//database props
		public var id:int;
		public var pgfile_id:int;
		public var src_id:int;
		public var log_date:Date;
		
		//temp table fields
		public var print_group:String;
		public var book_num:int;
		public var page_num:int;
		
	}
}