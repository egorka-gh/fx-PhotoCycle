/**
 * Generated by Gas3 v2.3.2 (Granite Data Services).
 *
 * NOTE: this file is only generated if it does not exist. You may safely put
 * your custom code here.
 */

package com.photodispatcher.model.mysql.entities {
	import mx.collections.ArrayList;
	
	import spark.components.gridClasses.GridColumn;

    [Bindable]
    [RemoteClass(alias="com.photodispatcher.model.mysql.entities.ContentFilter")]
    public class ContentFilter extends ContentFilterBase {
	
		public function ContentFilter(){
			super();
			hasAutoId=true;
		}
		
		public static function gridColumns():ArrayList{
			var result:ArrayList= new ArrayList();
			var col:GridColumn;
			col= new GridColumn('id'); col.headerText='ID'; col.visible=false; result.addItem(col);
			col= new GridColumn('name'); col.headerText='Наименование'; result.addItem(col);
			return result;
		}

    }

}