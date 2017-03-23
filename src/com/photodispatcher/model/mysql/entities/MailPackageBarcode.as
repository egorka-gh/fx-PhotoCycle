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
    [RemoteClass(alias="com.photodispatcher.model.mysql.entities.MailPackageBarcode")]
    public class MailPackageBarcode extends MailPackageBarcodeBase {
		public static const TYPE_SITE:int=1;
		public static const TYPE_SITE_BOX:int=2;

		public static function gridColumns():ArrayList{
			var result:ArrayList= new ArrayList();
			
			var col:GridColumn;
			col= new GridColumn('barcode'); col.headerText='Штрихкод'; result.addItem(col);
			col= new GridColumn('preorder_num'); col.headerText='Предзаказ'; result.addItem(col);
			col= new GridColumn('box_orderNumber'); col.headerText='НетПринт №'; result.addItem(col);
			col= new GridColumn('box_number'); col.headerText='Корбка №'; result.addItem(col);
			col= new GridColumn('box_weight'); col.headerText='Корбка вес'; result.addItem(col);
			
			return result;
		}

        public function MailPackageBarcode() {
            super();
        }
		
		public var preorder_num:String='';
		public var box_id:String='';
		public var box_number:String='';
		public var box_weight:String='';
		public var box_orderId:String='';
		public var box_orderNumber:String='';
    }
}
