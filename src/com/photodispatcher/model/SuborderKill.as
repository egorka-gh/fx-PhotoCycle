package com.photodispatcher.model{
	import com.photodispatcher.model.mysql.entities.OrderState;
	import com.photodispatcher.provider.fbook.FBookProject;
	
	import flash.filesystem.File;
	
	import mx.collections.ArrayList;
	
	import spark.components.gridClasses.GridColumn;

	public class SuborderKill extends Order{
		
		public function SuborderKill(){
			super();
			state=OrderState.FTP_WAITE_SUBORDER;
		}
		//database props
		[Bindable]
		public var order_id:String;
		[Bindable]
		public var src_type:int;
		
		
		public function get sub_id():int{
			return int(src_id);
		}
		public function set sub_id(value:int):void{
			src_id=value.toString();
			fillId();
		}

		[Bindable]
		public var proj_type:int=1;
		
		[Bindable]
		public var prt_qty:int=1;
		
		//ref
		[Bindable]
		public var src_type_name:String;
		[Bindable]
		public var proj_type_name:String;
		
		public function clone():Suborder{
			var result:Suborder= new Suborder;
			result.ftp_folder=ftp_folder;
			result.order_id=order_id;
			result.src_type=src_type;
			result.src_type_name=src_type_name;
			result.proj_type=proj_type;
			result.proj_type_name=proj_type_name;
			//extra
			result.calc_type=calc_type;
			result.corner_type=corner_type;
			result.cover=cover;
			result.endpaper=endpaper;
			result.format=format;
			result.interlayer=interlayer;
			result.kaptal=kaptal;
			return result;
		}

		private function fillId():void{
			id=order_id+'.'+src_id;
			ftp_folder='fb'+src_id;
		}

		/*
		public function fillFolder():void{
			ftp_folder=ftp_folder+File.separator+src_id;
		}
		*/

		//runtime
		public  var project:FBookProject;
		
		
		override public function toRaw():Object{
			//serialize props 4 build only 
			var raw:Object= new Object;
			raw.id=id;
			raw.order_id=order_id;
			raw.src_type=src_type;
			raw.sub_id=sub_id;
			raw.proj_type=proj_type;
			raw.prt_qty=prt_qty;
			//extra
			raw.calc_type=calc_type;
			raw.corner_type=corner_type;
			raw.cover=cover;
			raw.endpaper=endpaper;
			raw.format=format;
			raw.interlayer=interlayer;
			raw.kaptal=kaptal;

			if(project) raw.project=project.toRaw();

			return raw;
		}

		public static function fromRaw(raw:Object):Suborder{
			if(!raw) return null;
			var suborder:Suborder= new Suborder();
			suborder.id=raw.id;
			suborder.order_id=raw.order_id;
			suborder.src_type=raw.src_type;
			suborder.sub_id=raw.sub_id;
			suborder.proj_type=raw.proj_type;
			suborder.prt_qty=raw.prt_qty;
			//extra
			suborder.calc_type=raw.calc_type;
			suborder.corner_type=raw.corner_type;
			suborder.cover=raw.cover;
			suborder.endpaper=raw.endpaper;
			suborder.format=raw.format;
			suborder.interlayer=raw.interlayer;
			suborder.kaptal=raw.kaptal;

			suborder.project=FBookProject.fromRaw(raw.project);
			return suborder;
		}
		
		public static function gridColumns():ArrayList{
			var result:Array= [];
			var col:GridColumn;
			
			col= new GridColumn('src_type_name'); col.headerText='Тип источника'; result.push(col);
			col= new GridColumn('src_id'); col.headerText='ID'; col.width=80; result.push(col);
			col= new GridColumn('proj_type_name'); col.headerText='Тип книги'; result.push(col);
			col= new GridColumn('ftp_folder'); col.headerText='Папка'; result.push(col);
			col= new GridColumn('prt_qty'); col.headerText='Кол-во'; result.push(col);
			col= new GridColumn('calc_type'); col.headerText='Тип'; result.push(col);
			col= new GridColumn('cover'); col.headerText='Обложка'; result.push(col);
			col= new GridColumn('format'); col.headerText='Формат'; result.push(col);
			col= new GridColumn('endpaper'); col.headerText='Форзац'; result.push(col);
			col= new GridColumn('interlayer'); col.headerText='Прослойка'; result.push(col);
			col= new GridColumn('corner_type'); col.headerText='Углы'; result.push(col);
			col= new GridColumn('kaptal'); col.headerText='Каптал'; result.push(col);

			return new ArrayList(result);
		}
	}
}