package com.photodispatcher.model{
	import flash.globalization.DateTimeStyle;
	
	import mx.collections.ArrayList;
	
	import spark.components.gridClasses.GridColumn;
	import spark.formatters.DateTimeFormatter;

	public class OrderExtraStateProlongKill extends DBRecord{

		//database props
		[Bindable]
		public var id:String;
		[Bindable]
		public var sub_id:String;
		[Bindable]
		public var state:int;
		[Bindable]
		public var state_date:Date;
		[Bindable]
		public var comment:String;
		//ref
		[Bindable]
		public var state_name:String;
		
		public static function gridColumnsTech():ArrayList{
			var result:Array= [];
			var col:GridColumn;
			
			col= new GridColumn('id'); col.headerText='id'; col.visible=false; result.push(col);
			col= new GridColumn('state_name'); col.headerText='Статус'; result.push(col);
			var fmt:DateTimeFormatter=new DateTimeFormatter(); fmt.dateStyle=fmt.timeStyle=DateTimeStyle.SHORT;
			col= new GridColumn('state_date'); col.headerText='Дата'; col.formatter=fmt;  col.width=110; result.push(col);
			col= new GridColumn('comment'); col.headerText='Примечание'; result.push(col);
			return new ArrayList(result);
		}

	}
}