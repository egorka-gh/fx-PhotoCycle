package com.photodispatcher.model{
	public class ContentFilterAlias extends DBRecord{

		//database props
		[Bindable]
		public var filter:int;
		[Bindable]
		public var alias:int;

		//ref
		[Bindable]
		public var alias_name:String;
		
		
	}
}