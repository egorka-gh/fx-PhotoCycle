package com.photodispatcher.model{
	import com.photodispatcher.model.dao.LayerAllocationDAO;
	import com.photodispatcher.model.dao.LayerSequenceDAO;
	import com.photodispatcher.util.GridUtil;
	import com.photodispatcher.view.itemRenderer.BooleanGridItemEditor;
	import com.photodispatcher.view.itemRenderer.BooleanGridRenderer;
	import com.photodispatcher.view.itemRenderer.CBoxGridItemEditor;
	
	import mx.collections.ArrayList;
	import mx.core.ClassFactory;
	
	import spark.components.gridClasses.GridColumn;

	public class Layerset extends DBRecord{
		//db fileds
		[Bindable]
		public var id:int=-1;
		[Bindable]
		public var name:String;
		[Bindable]
		public var width:int;
		[Bindable]
		public var len:int;
		[Bindable]
		public var book_type:int;
		[Bindable]
		public var is_pdf:Boolean;
		[Bindable]
		public var endpaper:String;
		[Bindable]
		public var interlayer:String;
		[Bindable]
		public var interlayer_thickness:int;

		//db drived
		[Bindable]
		public var book_type_name:String;
		
		//db childs
		private var _layerAllocation:Array;
		[Bindable]
		public function get layerAllocation():Array{
			return _layerAllocation;
		}
		public function set layerAllocation(value:Array):void{
			_layerAllocation = value;
		}
		public function getLayerAllocation(forEdit:Boolean=false, silent:Boolean=false):Array{
			if(!loaded) return _layerAllocation;
			if(!_layerAllocation){
				var dao:LayerAllocationDAO=new LayerAllocationDAO();
				layerAllocation=dao.getBySet(id,forEdit,silent);
			}
			return _layerAllocation;
		}

		private var _sequence1:Array;
		private var _sequence2:Array;
		private var _sequence3:Array;
		[Bindable]
		public function get sequenceStart():Array{
			return _sequence1;
		}
		public function set sequenceStart(value:Array):void{
			_sequence1 = value;
		}
		[Bindable]
		public function get sequenceMiddle():Array{
			return _sequence2;
		}
		public function set sequenceMiddle(value:Array):void{
			_sequence2 = value;
		}
		[Bindable]
		public function get sequenceEnd():Array{
			return _sequence3;
		}
		public function set sequenceEnd(value:Array):void{
			_sequence3 = value;
		}

		public function loadSequence(silent:Boolean=false):Boolean{
			if(!loaded){
				sequenceStart=[];
				sequenceMiddle=[];
				sequenceEnd=[];
				return true;
			}
			if(!sequenceStart || !sequenceMiddle || !sequenceEnd){
				var dao:LayerSequenceDAO= new LayerSequenceDAO();
				var arr:Array=dao.getBySet(id,silent);
				if(!arr) return false;
				var ag:Array=[[],[],[]];
				var ls:LayerSequence;
				for each(ls in arr){
					if(ls.seqlayer!=0 && ls.layer_group>0) (ag[ls.layer_group-1] as Array).push(ls); 
				}
				//sort
				(ag[0] as Array).sortOn('seqorder',Array.NUMERIC);
				(ag[1] as Array).sortOn('seqorder',Array.NUMERIC);
				(ag[2] as Array).sortOn('seqorder',Array.NUMERIC);
				//set
				sequenceStart=(ag[0] as Array);
				sequenceMiddle=(ag[1] as Array);
				sequenceEnd=(ag[2] as Array);
			}
			return true;
		}

		private var layersMap:Object;
		
		public function prepareTamplate():Boolean{
			if(!loaded) return false;
			if(getLayerAllocation(true,true) && loadSequence(true)){
				layersMap= new Object;
				var la:LayerAllocation;
				var l:Layer;
				for each(la in layerAllocation){
					if(la.layer!=Layer.LAYER_EMPTY){
						l=layersMap['l'+la.layer.toString()] as Layer;
						if(!l){
							l=new Layer();
							l.id=la.layer;
							l.name=la.layer_name;
							layersMap['l'+la.layer.toString()]=l;
						}
						l.addTray(la.tray);
					}
				}
				return true;
			}
			return false;
		}
		
		public function getLayer(id:int):Layer{
			return layersMap?(layersMap['l'+id.toString()] as Layer):null;
		}

		public static function gridColumns():ArrayList{
			var result:ArrayList= new ArrayList();
			var col:GridColumn;
			col= new GridColumn('id'); col.headerText='ID'; col.visible=false; result.addItem(col);
			col= new GridColumn('name'); col.headerText='Наименование'; result.addItem(col); 
			col= new GridColumn('width'); col.headerText='Ширина (мм)'; result.addItem(col); 
			col= new GridColumn('len'); col.headerText='Ширина (мм)'; result.addItem(col);
			col= new GridColumn('book_type'); col.headerText='Тип книги'; col.labelFunction=GridUtil.idToLabel; col.itemEditor=new ClassFactory(CBoxGridItemEditor); result.addItem(col);
			
			col= new GridColumn('is_pdf'); col.headerText='Полиграфия'; col.itemRenderer=new ClassFactory(BooleanGridRenderer); col.editable=false; result.addItem(col);
			
			col= new GridColumn('endpaper'); col.headerText='Форзац'; result.addItem(col); 
			col= new GridColumn('interlayer'); col.headerText='Прослойка'; result.addItem(col); 
			col= new GridColumn('interlayer_thickness'); col.headerText='Толщина прослойки (мм)'; result.addItem(col); 
			return result;
		}

	}
}