package com.photodispatcher.model{
	import flash.globalization.DateTimeStyle;
	
	import mx.collections.ArrayList;
	
	import spark.components.gridClasses.GridColumn;
	import spark.formatters.DateTimeFormatter;

	public class TechPrintGroup extends DBRecord{

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

		public static function gridColumnsTech():ArrayList{
			var result:Array= [];
			var col:GridColumn;
			col= new GridColumn('id'); col.headerText='Заказ';  col.width=150; result.push(col);
			var fmt:DateTimeFormatter=new DateTimeFormatter(); fmt.dateStyle=fmt.timeStyle=DateTimeStyle.SHORT;
			col= new GridColumn('start_date'); col.headerText='Начат'; col.formatter=fmt; col.width=150; result.push(col);
			col= new GridColumn('books'); col.headerText='Всего книг'; col.width=100; result.push(col);
			col= new GridColumn('done'); col.headerText='Выполнено'; col.width=100; result.push(col);
			return new ArrayList(result);
		}

	}
}