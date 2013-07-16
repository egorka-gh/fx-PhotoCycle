package com.photodispatcher.model{
	public class PrintGroupSynonymUnUsed extends DBRecord{
		//database props
		[Bindable]
		public var id:int;
		[Bindable]
		public var src_type:int;
		[Bindable]
		public var synonym:String;
		[Bindable]
		public var width:int;
		[Bindable]
		public var height:int;
		[Bindable]
		public var paper:int=0;
		[Bindable]
		public var frame:int=0;
		[Bindable]
		public var correction:int=0;
		[Bindable]
		public var cutting:int=0;
		[Bindable]
		public var cover:int=0;
		[Bindable]
		public var pdf:int=0;
		[Bindable]
		public var is_book:Boolean=true;
		[Bindable]
		public var is_cover:Boolean=false;

		//ref
		[Bindable]
		public var src_type_name:String;
		[Bindable]
		public var paper_name:String;
		[Bindable]
		public var frame_name:String;
		[Bindable]
		public var correction_name:String;
		[Bindable]
		public var cutting_name:String;
		[Bindable]
		public var cover_name:String;
		[Bindable]
		public var pdf_name:String;

	}
}