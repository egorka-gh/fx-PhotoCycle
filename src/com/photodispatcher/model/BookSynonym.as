package com.photodispatcher.model{
	import com.photodispatcher.model.dao.BookPgTemplateDAO;
	
	import mx.collections.ArrayCollection;

	public class BookSynonym extends DBRecord{
		public static const BOOK_TYPE_BOOK:int=1;
		public static const BOOK_TYPE_JOURNAL:int=2;
		public static const BOOK_TYPE_LEATHER:int=3;
		public static const BOOK_TYPE_CALENDAR:int=4;
		public static const BOOK_TYPE_MAGNET:int=5;

		public static const BOOK_PART_COVER:int=1;
		public static const BOOK_PART_BLOCK:int=2;
		public static const BOOK_PART_INSERT:int=3;
		public static const BOOK_PART_AU_INSERT:int=4;

		//database props
		[Bindable]
		public var id:int;
		[Bindable]
		public var src_type:int;
		[Bindable]
		public var synonym:String;
		[Bindable]
		public var book_type:int;
		[Bindable]
		public var is_horizontal:Boolean;
		
		//ref
		[Bindable]
		public var src_type_name:String;
		[Bindable]
		public var book_type_name:String;
		
		[Bindable]
		public var templates:Array;
		
		public function loadTemplates():Boolean{
			var dao:BookPgTemplateDAO=new BookPgTemplateDAO();
			var a:Array=dao.getByBook(id);
			if(a){
				templates=a;
				return true;
			}
			return false;
		}

		public function createPrintGroup(path:String, bookPart:int, butt:int=0):PrintGroup{
			var pg:PrintGroup;
			var it:BookPgTemplate;
			if(!templates) return null;
			for each(it in templates){
				if(it && it.book_part==bookPart){
					pg=it.createPrintGroup(path,book_type,butt);
				}
			}
			if(pg) pg.is_horizontal=is_horizontal;
			return pg;
		}

	}
}