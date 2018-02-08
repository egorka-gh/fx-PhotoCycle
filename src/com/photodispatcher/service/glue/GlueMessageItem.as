package com.photodispatcher.service.glue{
	
	[Bindable]
	public class GlueMessageItem{
		public var parentKey:String='';
		public var type:int;
		public var key:String='';
		public var value:String='';
		public var isOk:Boolean;
	}
}