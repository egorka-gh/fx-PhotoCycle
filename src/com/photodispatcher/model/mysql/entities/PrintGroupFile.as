/**
 * Generated by Gas3 v2.3.2 (Granite Data Services).
 *
 * NOTE: this file is only generated if it does not exist. You may safely put
 * your custom code here.
 */

package com.photodispatcher.model.mysql.entities {
	import com.photodispatcher.util.StrUtil;

    [Bindable]
    [RemoteClass(alias="com.photodispatcher.model.mysql.entities.PrintGroupFile")]
    public class PrintGroupFile extends PrintGroupFileBase {
		public static const CAPTION_BOOK_NUM_HOLDER:String='~b~';
		
		//runtime props
		public var reprint:Boolean;
		public var fullPath:String;
		public var showPreview:Boolean;
		public var isBroken:Boolean;
		public var isCustom:Boolean;
		
		override public function set book_num(value:int):void{
			if(super.book_num==0 && value!=0 && caption){
				//set book num in caption
				caption=caption.replace(CAPTION_BOOK_NUM_HOLDER,StrUtil.lPad(value.toString(),2)); 
			}
			super.book_num = value;
		}
		override public function get book_num():int{
			return super.book_num;
		}
		
		public function clone():PrintGroupFile{
			var res:PrintGroupFile=new PrintGroupFile();
			res.file_name=file_name;
			res.prt_qty=prt_qty;
			res.book_num=book_num;
			res.page_num=page_num;
			res.caption=caption;
			res.isCustom=isCustom;
			return res;
		}
		
		public function toRaw():Object{
			var raw:Object= new Object;
			raw.print_group=print_group;
			raw.file_name=file_name;
			raw.prt_qty=prt_qty;
			raw.book_num=book_num;
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
			pgf.book_num=raw.book_num;
			pgf.page_num=raw.page_num;
			pgf.caption=raw.caption;
			
			return pgf;
			
		}

		

    }
}