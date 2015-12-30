/**
 * Generated by Gas3 v3.1.0 (Granite Data Services).
 *
 * NOTE: this file is only generated if it does not exist. You may safely put
 * your custom code here.
 */

package com.photodispatcher.model.mysql.entities {
	import com.photodispatcher.util.GridUtil;
	import com.photodispatcher.view.itemRenderer.BooleanGridItemEditor;
	import com.photodispatcher.view.itemRenderer.BooleanGridRenderer;
	import com.photodispatcher.view.itemRenderer.CBoxGridItemEditor;
	import com.photodispatcher.view.itemRenderer.TimeGridEditor;
	
	import flash.globalization.DateTimeStyle;
	
	import mx.collections.ArrayList;
	import mx.core.ClassFactory;
	
	import spark.components.gridClasses.GridColumn;
	import spark.formatters.DateTimeFormatter;

    [Bindable]
    [RemoteClass(alias="com.photodispatcher.model.mysql.entities.PrnStrategy")]
    public class PrnStrategy extends PrnStrategyBase {

		public static const STRATEGY_MINIMAL:int = 0;
		public static const STRATEGY_BYROLL:int = 1;
		public static const STRATEGY_BYPARTPDF:int = 2;
		
		
		public static function gridColumns():ArrayList{
			var result:ArrayList= new ArrayList();
			var col:GridColumn;
			col= new GridColumn('is_active'); col.headerText='Активна ';  col.labelFunction=GridUtil.booleanToLabel; col.itemEditor=new ClassFactory(BooleanGridItemEditor); col.width=60; result.addItem(col);
			col= new GridColumn('strategy_type'); col.headerText='Тип'; col.labelFunction=GridUtil.idToLabel; col.itemEditor=new ClassFactory(CBoxGridItemEditor); result.addItem(col);
			col= new GridColumn('priority'); col.headerText='Приоритет'; result.addItem(col);
			var fmt:DateTimeFormatter=new DateTimeFormatter(); fmt.dateTimePattern='HH:mm'; fmt.useUTC=false;
			col= new GridColumn('time_start'); col.headerText='Время запуска'; col.formatter=fmt; col.itemEditor=new ClassFactory(TimeGridEditor); col.width=100; result.addItem(col);
			fmt=new DateTimeFormatter(); fmt.dateStyle=fmt.timeStyle=DateTimeStyle.SHORT; 
			col= new GridColumn('last_start'); col.headerText='Последний запуск'; col.formatter=fmt; col.editable=false;  result.addItem(col);

			return result;
		}

		
        public function PrnStrategy() {
            super();
        }
    }
}