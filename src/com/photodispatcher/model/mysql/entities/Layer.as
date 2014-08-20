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
    [RemoteClass(alias="com.photodispatcher.model.mysql.entities.Layer")]
    public class Layer extends LayerBase {
		public static const LAYER_EMPTY:int=0;
		public static const LAYER_SHEET:int=1;
		public static const LAYER_ENDPAPER:int=2;

		public static function gridColumns():ArrayList{
			var result:ArrayList= new ArrayList();
			var col:GridColumn= new GridColumn('id'); col.headerText='ID'; col.visible=false; result.addItem(col);
			col= new GridColumn('name'); col.headerText='Наименование'; result.addItem(col); 
			return result;
		}
		
		public function Layer():void{
			id=-1;
		}
    }
}