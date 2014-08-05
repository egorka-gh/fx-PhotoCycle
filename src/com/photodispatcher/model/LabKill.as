package com.photodispatcher.model{
	
	import com.photodispatcher.model.dao.LabDeviceDAO;
	
	import mx.collections.ArrayList;
	
	import spark.components.gridClasses.GridColumn;
	
	public class LabKill extends DBRecord{
		
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
		//false - out of use (insted of del)
		[Bindable]
		public var is_active:Boolean;
		//can auto post
		[Bindable]
		public var is_managed:Boolean;
		
		
		//db drived
		[Bindable]
		public var src_type_name:String;

		//db childs
		protected var _devices:Array;

		[Bindable]
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

		public function cloneTo(lab:Lab):void{
			if(!lab) return;
			lab.id=this.id;
			lab.src_type=this.src_type;
			lab.name=this.name;
			lab.hot=this.hot;
			lab.hot_nfs=this.hot_nfs;
			lab.queue_limit=this.queue_limit;
			lab.is_active=this.is_active;
			lab.is_managed=this.is_managed;
			lab.src_type_name=this.src_type_name;
			lab._devices=this._devices;
			lab.isSelected=this.isSelected;
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
			col= new GridColumn('is_managed'); col.headerText='Автораспределение'; result.addItem(col); 
			col= new GridColumn('queue_limit'); col.headerText='Очередь печати (мин)'; result.addItem(col); 
			col= new GridColumn('is_managed'); col.headerText='Автопечать'; result.addItem(col); 
			col= new GridColumn('is_active'); col.headerText='Активна'; result.addItem(col); 
			return result;
		}

	}
}