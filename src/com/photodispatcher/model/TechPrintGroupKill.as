package com.photodispatcher.model{
	import flash.globalization.DateTimeStyle;
	
	import mx.collections.ArrayList;
	
	import spark.components.gridClasses.GridColumn;
	import spark.formatters.DateTimeFormatter;

	public class TechPrintGroupKill extends DBRecord{

		//db fileds
		[Bindable]
		public var id:String
		[Bindable]
		public var tech_type:int;
		[Bindable]
		public var start_date:Date;
		[Bindable]
		public var end_date:Date;
		[Bindable]
		public var books:int;
		[Bindable]
		public var sheets:int;
		[Bindable]
		public var start_loged:int;
		[Bindable]
		public var done:int;
		
		public function get isComplite():Boolean{
			return done==books*sheets;
		}

	}
}