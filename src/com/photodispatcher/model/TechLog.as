package com.photodispatcher.model{
	import flash.globalization.DateTimeStyle;
	
	import mx.collections.ArrayList;
	
	import spark.components.gridClasses.GridColumn;
	import spark.formatters.DateTimeFormatter;
	
	public class TechLog extends DBRecord{
		//database props
		public var id:int;
		public var print_group:String;
		public var sheet:int;
		public var src_id:int;
		public var log_date:Date;
		
		//ref props
		public var tech_point_name:String;
		public var tech_state:int;
		public var tech_state_name:String;
		public var complite_date:Date;
		
		//calc
		public function get book_num():int{
			return Math.floor(sheet/100);
		}
		
		public function get page_num():int{
			return sheet-book_num*100;
		}

		public function setSheet(book:int, page:int):void{
			sheet=book*100+page;
		}

		public static function gridColumnsTech():ArrayList{
			var result:Array= [];
			var col:GridColumn;
			/*
			col= new GridColumn('print_group'); col.headerText='Группа печати'; col.width=85; result.push(col);
			col= new GridColumn('book_num'); col.headerText='№ Книги'; result.push(col);
			col= new GridColumn('page_num'); col.headerText='№ Листа'; result.push(col);
			var fmt:DateTimeFormatter=new DateTimeFormatter(); fmt.dateStyle=fmt.timeStyle=DateTimeStyle.SHORT;
			col= new GridColumn('log_date'); col.headerText='Дата'; col.formatter=fmt;  col.width=110; result.push(col);
			col= new GridColumn('tech_point_name'); col.headerText='Тех точка'; result.push(col);
			col= new GridColumn('tech_state_name'); col.headerText='Статус'; result.push(col);
			*/
			var fmt:DateTimeFormatter=new DateTimeFormatter(); fmt.dateStyle=fmt.timeStyle=DateTimeStyle.SHORT;
			col= new GridColumn('log_date'); col.headerText='Дата'; col.formatter=fmt;  col.width=110; result.push(col);
			col= new GridColumn('tech_point_name'); col.headerText='Тех точка'; col.width=150; result.push(col);
			col= new GridColumn('book_num'); col.headerText='№ Книги'; col.width=100; result.push(col);
			col= new GridColumn('page_num'); col.headerText='№ Листа'; col.width=100; result.push(col);
			return new ArrayList(result);
		}

		public static function gridColumnsTechAgg():ArrayList{
			var result:Array= [];
			var col:GridColumn;
			
			col= new GridColumn('print_group'); col.headerText='Группа печати'; col.width=85; result.push(col);
			col= new GridColumn('tech_point_name'); col.headerText='Тех точка'; col.width=100; result.push(col);
			col= new GridColumn('tech_state_name'); col.headerText='Статус'; col.width=100; result.push(col);
			var fmt:DateTimeFormatter=new DateTimeFormatter(); fmt.dateStyle=fmt.timeStyle=DateTimeStyle.SHORT;
			col= new GridColumn('log_date'); col.headerText='Начало'; col.formatter=fmt;  col.width=110; result.push(col);
			col= new GridColumn('complite_date'); col.headerText='Завершено'; col.formatter=fmt;  col.width=110; result.push(col);
			return new ArrayList(result);
		}

	}
}