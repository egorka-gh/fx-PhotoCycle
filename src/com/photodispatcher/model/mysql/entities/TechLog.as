/**
 * Generated by Gas3 v2.3.2 (Granite Data Services).
 *
 * NOTE: this file is only generated if it does not exist. You may safely put
 * your custom code here.
 */

package com.photodispatcher.model.mysql.entities {
	
	import flash.globalization.DateTimeStyle;
	
	import mx.collections.ArrayList;
	
	import spark.components.gridClasses.GridColumn;
	import spark.formatters.DateTimeFormatter;

    [Bindable]
    [RemoteClass(alias="com.photodispatcher.model.mysql.entities.TechLog")]
    public class TechLog extends TechLogBase {
		
		public static function gridColumnsTech():ArrayList{
			var result:Array= [];
			var col:GridColumn;
			var fmt:DateTimeFormatter=new DateTimeFormatter(); fmt.dateStyle=fmt.timeStyle=DateTimeStyle.SHORT;
			col= new GridColumn('log_date'); col.headerText='Дата'; col.formatter=fmt;  col.width=110; result.push(col);
			col= new GridColumn('tech_point_name'); col.headerText='Тех точка'; col.width=150; result.push(col);
			col= new GridColumn('book'); col.headerText='№ Книги'; col.width=100; result.push(col);
			col= new GridColumn('page'); col.headerText='№ Листа'; col.width=100; result.push(col);
			return new ArrayList(result);
		}
		
		/*
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
		*/

		public function setSheet(book:int, page:int):void{
			sheet=book*100+page;
		}

		//calc
		public function get book():int{
			return Math.floor(sheet/100);
		}
		
		public function get page():int{
			return sheet-book*100;
		}

		/*
		//runtime view
		public var book:int;
		public var page:int;
		*/
		
		override public function set sheet(value:int):void{
			super.sheet = value;
			//book=Math.floor(value/100);
			//page=value-book*100;
		}
		override public function get sheet():int{
			return super.sheet;
		}

    }
}