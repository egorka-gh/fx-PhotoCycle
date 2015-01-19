/**
 * Generated by Gas3 v2.3.2 (Granite Data Services).
 *
 * NOTE: this file is only generated if it does not exist. You may safely put
 * your custom code here.
 */

package com.photodispatcher.model.mysql.entities {
	import com.photodispatcher.view.itemRenderer.BooleanGridRenderer;
	import com.photodispatcher.view.itemRenderer.TimeGridEditor;
	
	import mx.collections.ArrayList;
	import mx.core.ClassFactory;
	
	import spark.components.gridClasses.GridColumn;
	import spark.formatters.DateTimeFormatter;
	
	[Bindable]
	[RemoteClass(alias="com.photodispatcher.model.mysql.entities.LabTimetable")]
	public class LabTimetable extends LabTimetableBase {
		
		/**
		 * возвращает актуальное расписание относительно определенной даты
		 */
		public function createCurrent(date:Date):LabTimetable {
			
			var tt:LabTimetable = new LabTimetable;
			tt.day_id = this.day_id;
			tt.day_id_name = this.day_id_name;
			tt.lab_device = this.lab_device;
			tt.is_online = this.is_online;
			
			tt.time_from = new Date(this.time_from.time);
			tt.time_to = new Date(this.time_to.time);
			
			tt.time_from.date=1; tt.time_from.fullYear=date.fullYear; tt.time_from.month=date.month; tt.time_from.date=date.date;
			tt.time_to.date=1; tt.time_to.fullYear=date.fullYear; tt.time_to.month=date.month; tt.time_to.date=date.date;
			
			return tt;
			
		}
		
		public static function gridColumns():ArrayList{
			var result:ArrayList= new ArrayList();
			var col:GridColumn;
			col= new GridColumn('is_online'); col.headerText=' '; col.itemRenderer=new ClassFactory(BooleanGridRenderer); col.editable=false;  col.width=30; result.addItem(col);
			col= new GridColumn('day_id_name'); col.headerText='День недели'; col.editable=false; result.addItem(col);
			var fmt:DateTimeFormatter=new DateTimeFormatter(); fmt.dateTimePattern='HH:mm'; fmt.useUTC=false;
			col= new GridColumn('time_from'); col.headerText='С'; col.formatter=fmt; col.itemEditor=new ClassFactory(TimeGridEditor); col.width=100; result.addItem(col);
			col= new GridColumn('time_to'); col.headerText='До'; col.formatter=fmt; col.itemEditor=new ClassFactory(TimeGridEditor);  col.width=100; result.addItem(col);
			return result;
		}
		
	}
}