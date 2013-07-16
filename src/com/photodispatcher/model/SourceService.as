package com.photodispatcher.model{

	[Bindable]
	public class SourceService extends DBRecord{

		public static const WEB_SERVICE:int=1;
		public static const FTP_SERVICE:int=4;
		public static const FBOOK_SERVICE:int=5;
		public static const HOT_FOLDER:int=10;
		
		//database props
		public var src_id:int;
		public var srvc_id:int;
		public var url:String;
		public var user:String;
		public var pass:String;
		public var loc_type:int;
		public var connections:int;
		
		//drived
		public var type_name:String;
	}
}