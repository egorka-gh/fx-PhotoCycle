/**
 * Generated by Gas3 v3.1.0 (Granite Data Services).
 *
 * NOTE: this file is only generated if it does not exist. You may safely put
 * your custom code here.
 */

package com.photodispatcher.model.mysql.entities {
	import mx.collections.ArrayList;
	
	import spark.components.gridClasses.GridColumn;

    [Bindable]
    [RemoteClass(alias="com.photodispatcher.model.mysql.entities.Rack")]
    public class Rack extends RackBase {

		public static function gridColumns():ArrayList{
			var result:Array= [];
			var col:GridColumn;
			
			col= new GridColumn('name'); col.headerText='Наименование'; result.push(col);
			return new ArrayList(result);
		}

        public function Rack() {
            super();
        }
    }
}