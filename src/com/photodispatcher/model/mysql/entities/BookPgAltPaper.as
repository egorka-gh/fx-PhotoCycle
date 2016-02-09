/**
 * Generated by Gas3 v3.1.0 (Granite Data Services).
 *
 * NOTE: this file is only generated if it does not exist. You may safely put
 * your custom code here.
 */

package com.photodispatcher.model.mysql.entities {
	import com.photodispatcher.util.GridUtil;
	import com.photodispatcher.view.itemRenderer.CBoxGridItemEditor;
	import com.photodispatcher.view.itemRenderer.CBoxGridItemEditorFullList;
	
	import mx.collections.ArrayList;
	import mx.core.ClassFactory;
	
	import spark.components.gridClasses.GridColumn;

    [Bindable]
    [RemoteClass(alias="com.photodispatcher.model.mysql.entities.BookPgAltPaper")]
    public class BookPgAltPaper extends BookPgAltPaperBase {

		public static function gridColumns():ArrayList{
			var result:ArrayList= new ArrayList();
			var col:GridColumn;
			col= new GridColumn('sh_from'); col.headerText='Разворотов с';  col.width=100; result.addItem(col);
			col= new GridColumn('sh_to'); col.headerText='Разворотов по'; col.width=100; result.addItem(col);
			col= new GridColumn('paper'); col.headerText='Бумага'; col.width=150; col.labelFunction=GridUtil.idToLabel; col.itemEditor=new ClassFactory(CBoxGridItemEditor); result.addItem(col);
			col= new GridColumn('interlayer'); col.headerText='Прослойка'; col.width=150; col.labelFunction=GridUtil.idToLabel; col.itemEditor=new ClassFactory(CBoxGridItemEditorFullList); result.addItem(col);
			return result;
		}

        public function BookPgAltPaper() {
            super();
        }
		
		
    }
}