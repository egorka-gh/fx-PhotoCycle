/**
 * Generated by Gas3 v3.1.0 (Granite Data Services).
 *
 * NOTE: this file is only generated if it does not exist. You may safely put
 * your custom code here.
 */

package com.photodispatcher.model.mysql.entities {
	import com.photodispatcher.util.GridUtil;
	
	import flash.globalization.DateTimeStyle;
	
	import mx.collections.ArrayList;
	
	import spark.components.gridClasses.GridColumn;
	import spark.formatters.DateTimeFormatter;

    [Bindable]
    [RemoteClass(alias="com.photodispatcher.model.mysql.entities.GroupNetprint")]
    public class GroupNetprint extends GroupNetprintBase {

		public static function gridColumns():ArrayList{
			var result:Array= [];
			
			var col:GridColumn= new GridColumn('groupId'); col.headerText='Группа'; col.width=100; result.push(col);
			col= new GridColumn('netprintId'); col.headerText='Нетпринт ID'; col.width=250; result.push(col);
			var fmt:DateTimeFormatter=new DateTimeFormatter(); fmt.dateStyle=fmt.timeStyle=DateTimeStyle.SHORT; 
			col= new GridColumn('created'); col.headerText='Добавлена'; col.formatter=fmt;  col.width=150; result.push(col);
			col= new GridColumn('boxNumber'); col.headerText='№ коробки'; col.width=100; result.push(col);
			col= new GridColumn('isSend'); col.headerText='Отправлена'; col.labelFunction=GridUtil.booleanToLabel; col.width=50; result.push(col);
			return new ArrayList( result);
		}

        public function GroupNetprint() {
            super();
        }
    }
}