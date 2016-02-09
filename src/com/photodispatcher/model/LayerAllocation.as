package com.photodispatcher.model{
	import com.photodispatcher.service.barcode.FeederController;
	import com.photodispatcher.util.GridUtil;
	import com.photodispatcher.view.itemRenderer.CBoxGridItemEditor;
	
	import mx.collections.ArrayList;
	import mx.core.ClassFactory;
	
	import spark.components.gridClasses.GridColumn;

	public class LayerAllocation extends DBRecord{
		//db fileds
		/*
		[Bindable]
		public var layerset:int;
		*/
		[Bindable]
		public var tray:int;
		[Bindable]
		public var layer:int;
		
		[Bindable]
		public var controller:FeederController;
		
		//db drived
		[Bindable]
		public var layer_name:String;
		
		/*
		public static function gridColumns__():ArrayList{
			var result:ArrayList= new ArrayList();
			var col:GridColumn;
			col= new GridColumn('layerset'); col.headerText='layerset'; col.visible=false; result.addItem(col);
			col= new GridColumn('tray'); col.headerText='Лоток'; col.editable=false; col.width=50; result.addItem(col); 
			col= new GridColumn('layer'); col.headerText='Слой'; col.labelFunction=GridUtil.idToLabel; col.itemEditor=new ClassFactory(CBoxGridItemEditor); result.addItem(col);
			return result;
		}
		*/

		public static function gridColumns():ArrayList{
			var result:ArrayList= new ArrayList();
			var col:GridColumn;
			//col= new GridColumn('tray'); col.headerText='Лоток'; col.editable=false; col.itemRenderer=new ClassFactory(RowNumGridRenderer);  col.width=50; result.addItem(col); 
			col= new GridColumn('tray'); col.headerText='Лоток'; col.editable=false; col.labelFunction=LayerAllocation.trayToLabel; col.width=50; result.addItem(col);
			col= new GridColumn('layer'); col.headerText='Слой'; col.labelFunction=GridUtil.idToLabel; col.itemEditor=new ClassFactory(CBoxGridItemEditor); result.addItem(col);
			return result;
		}

		public static function trayToLabel(item:Object, column:GridColumn):String{
			return item[column.dataField]+1;
		}

	}
}