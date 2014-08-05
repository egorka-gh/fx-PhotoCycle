package com.photodispatcher.model{
	import com.photodispatcher.model.mysql.entities.Roll;
	import com.photodispatcher.view.itemRenderer.BooleanGridItemEditor;
	import com.photodispatcher.view.itemRenderer.BooleanGridRenderer;
	
	import mx.collections.ArrayList;
	import mx.core.ClassFactory;
	
	import spark.components.gridClasses.GridColumn;
	
	public class LabRollKill extends Roll{

		//db fileds
		[Bindable]
		public var lab_device:int;
		[Bindable]
		public var paper:int;
		[Bindable]
		public var len_std:int;
		[Bindable]
		public var len:int;
		
		//run time
		[Bindable]
		public var is_online:Boolean;
		
		//use in device (edit in full list mark)
		[Bindable]
		public var is_used:Boolean;

		//db drived
		[Bindable]
		public var paper_name:String;
		
		//run time
		[Bindable]
		public var printQueueLen:int=0;
		[Bindable]
		public var printQueueTime:int=0;//sec
		public var speed:int=0;//mm/sec
		public var printGroups:Array=[];

		public static function gridColumnsEdit():ArrayList{
			var result:ArrayList= new ArrayList();
			var col:GridColumn;
			col= new GridColumn('is_used'); col.headerText=' '; col.itemRenderer=new ClassFactory(BooleanGridRenderer); col.editable=false; col.width=30; result.addItem(col);
			col= new GridColumn('width'); col.headerText='Ширина'; col.editable=false; result.addItem(col);
			col= new GridColumn('paper_name'); col.headerText='Бумага'; col.editable=false; result.addItem(col);
			col= new GridColumn('len_std'); col.headerText='Стандартная длинна (мм)'; result.addItem(col);
			return result;
		}

		public static function gridColumnsView(brief:Boolean=false):ArrayList{
			var result:ArrayList= new ArrayList();
			var col:GridColumn;
			if(!brief){ col= new GridColumn('is_online'); col.headerText='Активный'; col.itemRenderer=new ClassFactory(BooleanGridRenderer); col.editable=false; col.width=70; result.addItem(col);}
			col= new GridColumn('width'); col.headerText='Ширина'; col.editable=false; result.addItem(col);
			col= new GridColumn('paper_name'); col.headerText='Бумага'; col.editable=false; result.addItem(col);
			col= new GridColumn('len'); col.headerText='Длинна (мм)'; result.addItem(col);
			return result;
		}

		public function clone():LabRoll{
			var result:LabRoll= new LabRoll();
			result.lab_device=lab_device;
			result.paper=paper;
			result.width=width;
			result.speed=speed;
			result.paper_name=paper_name;
			result.len_std=len_std;
			result.len=len;
			result.is_online=is_online;
			return result;
		}
	}
}