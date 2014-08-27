package com.photodispatcher.model{
	import com.photodispatcher.util.GridUtil;
	import com.photodispatcher.view.itemRenderer.CBoxGridItemEditor;
	
	import mx.collections.ArrayList;
	import mx.core.ClassFactory;
	
	import spark.components.gridClasses.GridColumn;

	public class LayerSequenceKill extends DBRecord{
		//db fileds
		[Bindable]
		public var layerset:int;
		[Bindable]
		public var layer_group:int;
		[Bindable]
		public var seqorder:int;
		[Bindable]
		public var seqlayer:int;
		
		//db drived
		[Bindable]
		public var seqlayer_name:String;

		public static function gridColumns():ArrayList{
			var result:ArrayList= new ArrayList();
			var col:GridColumn;
			col= new GridColumn('layerset'); col.headerText='layerset'; col.visible=false; result.addItem(col);
			col= new GridColumn('layer_group'); col.headerText='layer_group'; col.visible=false; result.addItem(col);
			col= new GridColumn('seqorder'); col.headerText='№'; col.editable=false; col.width=50; result.addItem(col); 
			col= new GridColumn('seqlayer'); col.headerText='Слой'; col.labelFunction=GridUtil.idToLabel; col.itemEditor=new ClassFactory(CBoxGridItemEditor); result.addItem(col);
			return result;
		}

	}
}