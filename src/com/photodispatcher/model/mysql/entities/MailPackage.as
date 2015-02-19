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
    [RemoteClass(alias="com.photodispatcher.model.mysql.entities.MailPackage")]
    public class MailPackage extends MailPackageBase {

        public function MailPackage() {
            super();
			state=OrderState.TECH_OTK;
        }
		
		override public function set state(value:int):void{
			super.state = value;
			if(super.state != value){
				state_name= OrderState.getStateName(value);
				state_date= new Date();
			}
		}
		
		override public function get state():int{
			return super.state;
		}
		
		
		
		public static function inQueueColumns():ArrayList{
			var result:ArrayList= new ArrayList();
			
			var col:GridColumn;
			col= new GridColumn('source_name'); col.headerText='Источник'; result.addItem(col);
			col= new GridColumn('source_code'); col.headerText='Код'; col.width=25; result.addItem(col); 
			col= new GridColumn('id'); col.headerText='Группа'; result.addItem(col); 
			col= new GridColumn('client_id'); col.headerText='Клиент'; result.addItem(col); 
			col= new GridColumn('state_name'); col.headerText='Макс статус'; result.addItem(col); 
			col= new GridColumn('min_ord_state_name'); col.headerText='Мин статус'; result.addItem(col); 
			var fmt:DateTimeFormatter=new DateTimeFormatter(); fmt.dateStyle=fmt.timeStyle=DateTimeStyle.SHORT; 
			col= new GridColumn('state_date'); col.headerText='Дата статуса'; col.formatter=fmt;  result.addItem(col);
			col= new GridColumn('orders_num'); col.headerText='Кол заказов'; result.addItem(col); 
			
			/*
			col= new GridColumn('id'); result.addItem(col);
			var fmt:DateTimeFormatter=new DateTimeFormatter(); fmt.dateStyle=fmt.timeStyle=DateTimeStyle.SHORT; 
			col= new GridColumn('src_date'); col.headerText='Размещен'; col.formatter=fmt;  result.addItem(col);
			fmt=new DateTimeFormatter(); fmt.dateStyle=fmt.timeStyle=DateTimeStyle.SHORT; 
			col= new GridColumn('state_date'); col.headerText='Дата статуса'; col.formatter=fmt;  result.addItem(col);
			col= new GridColumn('ftp_folder'); col.headerText='Ftp Папка'; result.addItem(col);
			col= new GridColumn('fotos_num'); col.headerText='Кол фото'; result.addItem(col);
			*/
			return result;
		}

    }
}