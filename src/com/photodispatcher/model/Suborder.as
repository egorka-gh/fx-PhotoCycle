package com.photodispatcher.model{
	import com.photodispatcher.model.dao.OrderStateDAO;
	import com.photodispatcher.provider.fbook.FBookProject;
	
	import flash.filesystem.File;

	public class Suborder extends Order{
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
		}

		
		[Bindable]
		public var prt_qty:int=1;
		
		//ref
		[Bindable]
		public var src_type_name:String;
		
		public function clone():Suborder{
			var result:Suborder= new Suborder;
			result.ftp_folder=ftp_folder;
			result.order_id=order_id;
			result.src_type=src_type;
			result.src_type_name=src_type_name;
			return result;
		}

		public function fillId():void{
			id=order_id+'.'+src_id;
		}

		/*
		public function fillFolder():void{
			ftp_folder=ftp_folder+File.separator+src_id;
		}
		*/

		//runtime
		public  var project:FBookProject;
	}
}