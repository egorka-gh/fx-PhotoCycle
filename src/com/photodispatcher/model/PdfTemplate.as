package com.photodispatcher.model{
	public class PdfTemplate extends DBRecord{
		
		//database props
		[Bindable]
		public var id:int;
		[Bindable]
		public var name:String;
		[Bindable]
		public var width:int;
		[Bindable]
		public var height:int;
		[Bindable]
		public var blocks:int;
		[Bindable]
		public var block_width:int;
		[Bindable]
		public var block_height:int;
		[Bindable]
		public var fill_order:int;
		
		//ref
		[Bindable]
		public var fill_order_name:String;

	}
}