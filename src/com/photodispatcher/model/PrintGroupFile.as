package com.photodispatcher.model{
	import com.photodispatcher.util.StrUtil;

	public class PrintGroupFile extends DBRecord{
		public static const CAPTION_BOOK_NUM_HOLDER:String='~b~';

		//runtime props
		[Bindable]
		public var reprint:Boolean;
		[Bindable]
		public var fullPath:String;
		[Bindable]
		public var showPreview:Boolean;
		[Bindable]
		public var isBroken:Boolean;
		
		//ref props
		public var path:String;
		public var tech_point:int;
		public var tech_point_name:String;
		public var tech_state:int;
		public var tech_state_name:String;
		public var tech_date:Date;

		//database props
		[Bindable]
		public var id:int;
		[Bindable]
		public var print_group:String;
		[Bindable]
		public var file_name:String;
		[Bindable]
		public var prt_qty:int=0;
		
		private var _book_num:int=0;
		[Bindable]
		public function get book_num():int{
			return _book_num;
		}

		public function set book_num(value:int):void{
			if(_book_num==0 && value!=0 && caption){
				//set book num in caption
				caption=caption.replace(CAPTION_BOOK_NUM_HOLDER,StrUtil.lPad(value.toString(),2)); 
			}
			_book_num = value;
		}

		[Bindable]
		public var page_num:int=0;
		public var caption:String;

		public function clone():PrintGroupFile{
			var res:PrintGroupFile=new PrintGroupFile();
			res.file_name=file_name;
			res.prt_qty=prt_qty;
			res.book_num=book_num;
			res.page_num=page_num;
			res.caption=caption;
			return res;
		}

		public function toRaw():Object{
			var raw:Object= new Object;
			raw.print_group=print_group;
			raw.file_name=file_name;
			raw.prt_qty=prt_qty;
			raw.book_num=_book_num;
			raw.page_num=page_num;
			raw.caption=caption;
			
			return raw;
		}
		
		public static function fromRaw(raw:Object):PrintGroupFile{
			if(!raw) return null;
			var pgf:PrintGroupFile= new PrintGroupFile();
			pgf.print_group=raw.print_group;
			pgf.file_name=raw.file_name;
			pgf.prt_qty=raw.prt_qty;
			pgf._book_num=raw.book_num;
			pgf.page_num=raw.page_num;
			pgf.caption=raw.caption;

			return pgf;

		}

	}
}