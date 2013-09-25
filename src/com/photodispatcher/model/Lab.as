package com.photodispatcher.model{
	
	import com.photodispatcher.model.dao.LabDeviceDAO;
	
	import mx.collections.ArrayList;
	
	import spark.components.gridClasses.GridColumn;
	
	public class Lab extends DBRecord{
		
		//db fileds
		[Bindable]
		public var id:int;
		[Bindable]
		public var src_type:int;
		[Bindable]
		public var name:String;
		[Bindable]
		public var hot:String;
		[Bindable]
		public var hot_nfs:String;
		[Bindable]
		public var queue_limit:int;
		[Bindable]
		public var is_active:Boolean;
		
		//db drived
		[Bindable]
		public var src_type_name:String;

		//db childs
		private var _devices:Array;

		public function get devices():Array{
			return _devices;
		}
		public function set devices(value:Array):void{
			_devices = value;
		}
		public function getDevices(silent:Boolean=false):Array{
			//load from db
			if(!loaded) return _devices;
			var dao:LabDeviceDAO=new LabDeviceDAO();
			_devices=dao.getByLab(id,silent);
			return _devices;
		}


		//runtime, 4 Laboratory config
		[Bindable]
		public var isSelected:Boolean;

		public static function gridColumns():ArrayList{
			var result:ArrayList= new ArrayList();
			var col:GridColumn= new GridColumn('id'); col.headerText='ID'; result.addItem(col);
			col= new GridColumn('src_type_name'); col.headerText='Тип'; result.addItem(col); 
			col= new GridColumn('name'); col.headerText='Наименование'; result.addItem(col); 
			col= new GridColumn('hot'); col.headerText='Hot folder'; result.addItem(col); 
			col= new GridColumn('hot_nfs'); col.headerText='Hot folder NHF'; result.addItem(col); 
			col= new GridColumn('queue_limit'); col.headerText='Очередь печати (мин)'; result.addItem(col); 
			col= new GridColumn('is_active'); col.headerText='Активна'; result.addItem(col); 
			return result;
		}

	}
}