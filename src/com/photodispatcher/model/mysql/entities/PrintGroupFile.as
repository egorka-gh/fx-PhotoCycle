/**
 * Generated by Gas3 v2.3.2 (Granite Data Services).
 *
 * NOTE: this file is only generated if it does not exist. You may safely put
 * your custom code here.
 */

package com.photodispatcher.model.mysql.entities {
	import com.photodispatcher.util.StrUtil;
	
	import mx.collections.ArrayList;
	
	import org.granite.reflect.Field;
	import org.granite.reflect.Type;
	
	import spark.components.gridClasses.GridColumn;

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
		
		public static function gridColumns():ArrayList{
			var result:Array= [];
			var col:GridColumn;
			
			col= new GridColumn('print_group'); col.headerText='Группа печати'; col.width=85; result.push(col);
			col= new GridColumn('path'); col.headerText='Папка'; col.width=110; result.push(col);
			col= new GridColumn('file_name'); col.headerText='Файл'; col.width=250; result.push(col); 
			col= new GridColumn('caption'); col.headerText='Подпись'; col.width=250; result.push(col); 
			col= new GridColumn('book_num'); col.headerText='№ Книги'; result.push(col);
			col= new GridColumn('page_num'); col.headerText='№ Листа'; result.push(col);
			col= new GridColumn('prt_qty'); col.headerText='Кол отпечатков'; result.push(col);
			return new ArrayList(result);
		}

		
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
			/*
			res.file_name=file_name;
			res.prt_qty=prt_qty;
			res.book_num=book_num;
			res.page_num=page_num;
			res.caption=caption;
			res.isCustom=isCustom;
			*/
			var type:Type=Type.forClass(PrintGroupFile);
			var props:Array=type.properties;
			if(!props || props.length==0) return res;
			var prop:Field;
			for each(prop in props){
				res[prop.name]=this[prop.name];
			}

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