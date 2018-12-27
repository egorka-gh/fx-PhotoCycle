/**
 * Generated by Gas3 v3.1.0 (Granite Data Services).
 *
 * NOTE: this file is only generated if it does not exist. You may safely put
 * your custom code here.
 */

package com.photodispatcher.model.mysql.entities {
	import com.photodispatcher.util.GridUtil;
	import com.photodispatcher.view.itemRenderer.BooleanGridItemEditor;
	
	import mx.collections.ArrayList;
	import mx.core.ClassFactory;
	
	import spark.components.gridClasses.GridColumn;

    [Bindable]
    [RemoteClass(alias="com.photodispatcher.model.mysql.entities.Staff")]
    public class Staff extends StaffBase {

		public static function gridColumns():ArrayList{
			var result:Array= [];
			var col:GridColumn;
			
			col= new GridColumn('name'); col.headerText='ФИО'; result.push(col);
			col= new GridColumn('active'); col.headerText='Активен ';  col.labelFunction=GridUtil.booleanToLabel; col.itemEditor=new ClassFactory(BooleanGridItemEditor); col.width=60; result.push(col);

			return new ArrayList(result);
		}

        public function Staff() {
            super();
			this.staff_group=1;
			this.active=true;
        }
    }
}