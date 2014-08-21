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
    [RemoteClass(alias="com.photodispatcher.model.mysql.entities.OrderExtraState")]
    public class OrderExtraState extends OrderExtraStateBase {
		
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