/**
 * Generated by Gas3 v3.1.0 (Granite Data Services).
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
    [RemoteClass(alias="com.photodispatcher.model.mysql.entities.MailPackageBoxItem")]
    public class MailPackageBoxItem extends MailPackageBoxItemBase {

        public function MailPackageBoxItem() {
            super();
        }
		
		public static function columns():ArrayList{
			var result:ArrayList= new ArrayList();
			var i : MailPackageBoxItem;
			var col:GridColumn;
			col= new GridColumn('state_name'); col.headerText='Статус'; col.width=140; result.addItem(col);
			col= new GridColumn('orderID'); col.headerText='Заказ'; col.width=70; result.addItem(col);
			col= new GridColumn('bookTypeName'); col.headerText='Тип'; col.width=70; result.addItem(col); 
			col= new GridColumn('itemFrom'); col.headerText='C'; col.width=45; result.addItem(col); 
			col= new GridColumn('itemTo'); col.headerText='По'; col.width=45; result.addItem(col); 
			col= new GridColumn('alias'); col.headerText='Алиас'; result.addItem(col); 
			/*
			col= new GridColumn('state_name'); col.headerText='Cтатус'; result.addItem(col); 
			var fmt:DateTimeFormatter=new DateTimeFormatter(); fmt.dateStyle=fmt.timeStyle=DateTimeStyle.SHORT; 
			col= new GridColumn('state_date'); col.headerText='Дата статуса'; col.formatter=fmt;  result.addItem(col);
			*/
			return result;
		}
		
    }
}