package com.photodispatcher.model{
	import flash.globalization.DateTimeStyle;
	
	import mx.collections.ArrayList;
	
	import spark.components.gridClasses.GridColumn;
	import spark.formatters.DateTimeFormatter;

	public class OrderExtraStateKill extends DBRecord{

		//database props
		[Bindable]
		public var id:String;
		[Bindable]
		public var sub_id:String;
		[Bindable]
		public var state:int;
		[Bindable]
		public var start_date:Date;
		[Bindable]
		public var state_date:Date;
		[Bindable]
		public var reported:int;
		//ref
		[Bindable]
		public var state_name:String;
		public var books:int;
		public var books_done:int;

		public static function gridColumnsTech():ArrayList{
			var result:Array= [];
			var col:GridColumn;
			
			col= new GridColumn('id'); col.headerText='id'; col.visible=false; result.push(col);
			col= new GridColumn('state_name'); col.headerText='Статус'; result.push(col);
			var fmt:DateTimeFormatter=new DateTimeFormatter(); fmt.dateStyle=fmt.timeStyle=DateTimeStyle.SHORT;
			col= new GridColumn('start_date'); col.headerText='Начало'; col.formatter=fmt;  col.width=110; result.push(col);
			fmt=new DateTimeFormatter(); fmt.dateStyle=fmt.timeStyle=DateTimeStyle.SHORT;
			col= new GridColumn('state_date'); col.headerText='Конец'; col.formatter=fmt;  col.width=110; result.push(col);
			return new ArrayList(result);
		}

		public static function gridColumnsOTK():ArrayList{
			var result:Array= [];
			var col:GridColumn;
			col= new GridColumn('id'); col.headerText='Заказ';  col.width=150; result.push(col);
			var fmt:DateTimeFormatter=new DateTimeFormatter(); fmt.dateStyle=fmt.timeStyle=DateTimeStyle.SHORT;
			col= new GridColumn('start_date'); col.headerText='Начат'; col.formatter=fmt; col.width=150; result.push(col);
			col= new GridColumn('books'); col.headerText='Всего книг'; col.width=100; result.push(col);
			col= new GridColumn('books_done'); col.headerText='Выполнено'; col.width=100; result.push(col);
			return new ArrayList(result);
		}

	}
}