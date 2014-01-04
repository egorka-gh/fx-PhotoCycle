package com.photodispatcher.model{
	import com.photodispatcher.view.config.BookSynonymView;
	
	import mx.collections.ArrayCollection;

	public class BookPgTemplate extends DBRecord{
		//database props
		[Bindable]
		public var id:int;
		[Bindable]
		public var book:int;
		[Bindable]
		public var book_part:int;
		[Bindable]
		public var width:int;
		[Bindable]
		public var height:int;
		[Bindable]
		public var paper:int=0;
		[Bindable]
		public var frame:int=0;
		[Bindable]
		public var correction:int=0;
		[Bindable]
		public var cutting:int=0;
		[Bindable]
		public var is_duplex:Boolean=false;
		[Bindable]
		public var is_pdf:Boolean=false;
		[Bindable]
		public var sheet_width:int=0;
		[Bindable]
		public var sheet_len:int=0;
		[Bindable]
		public var page_width:int=0;
		[Bindable]
		public var page_len:int=0;
		[Bindable]
		public var font_size:int=0;
		[Bindable]
		public var font_offset:String='+500+0';
		[Bindable]
		public var notching:int=0;
		[Bindable]
		public var stroke:int=0;
		[Bindable]
		public var bar_size:int=0;
		[Bindable]
		public var bar_offset:String='+0+0';
		[Bindable]
		public var tech_bar:int=0;
		[Bindable]
		public var tech_bar_gravity:int=0;
		[Bindable]
		public var tech_bar_step:int=4;
		[Bindable]
		public var tech_bar_color:String='200000';
		[Bindable]
		public var tech_bar_offset:String='+0-200';
		[Bindable]
		public var tech_add:int=4;

		
		//ref
		[Bindable]
		public var book_part_name:String;
		[Bindable]
		public var paper_name:String;
		[Bindable]
		public var frame_name:String;
		[Bindable]
		public var correction_name:String;
		[Bindable]
		public var cutting_name:String;
		
		public function createPrintGroup(path:String, bookType:int, butt:int=0):PrintGroup{
			var pg:PrintGroup=new PrintGroup();
			pg.path=path;
			pg.book_type=bookType;
			pg.book_part=book_part;
			pg.width=width;
			pg.height=height;
			pg.paper=paper;
			pg.frame=frame;
			pg.correction=correction;
			pg.cutting=cutting;
			pg.is_duplex=is_duplex;
			pg.is_pdf=is_pdf;
			pg.butt=butt;
			pg.bookTemplate=this;
			return pg;
		}

		public function toRaw():Object{
			var raw:Object= new Object;
			raw.id=id;
			raw.book=book;
			raw.book_part=book_part;
			raw.width=width;
			raw.height=height;
			raw.paper=paper;
			raw.frame=frame;
			raw.correction=correction;
			raw.cutting=cutting;
			raw.is_pdf=is_pdf?1:0;
			raw.is_duplex=is_duplex?1:0;
			raw.sheet_width=sheet_width;
			raw.sheet_len=sheet_len;
			raw.page_width=page_width;
			raw.page_len=page_len;
			raw.font_size=font_size;
			raw.notching=notching;
			raw.stroke=stroke;
			raw.bar_size=bar_size;
			raw.bar_offset=bar_offset;
			raw.tech_bar=tech_bar;
			raw.tech_bar_gravity=tech_bar_gravity;
			raw.tech_bar_step=tech_bar_step;
			raw.tech_bar_color=tech_bar_color;
			raw.tech_bar_offset=tech_bar_offset;
			raw.tech_add=tech_add;

			return raw;
		}

		public static function fromRaw(raw:Object):BookPgTemplate{
			if(!raw) return null;
			var pgt:BookPgTemplate= new BookPgTemplate();
			pgt.id=raw.id;
			pgt.book=raw.book;
			pgt.book_part=raw.book_part;
			pgt.width=raw.width;
			pgt.height=raw.height;
			pgt.paper=raw.paper;
			pgt.frame=raw.frame;
			pgt.correction=raw.correction;
			pgt.cutting=raw.cutting;
			pgt.is_pdf=Boolean(raw.is_pdf);
			pgt.is_duplex=Boolean(raw.is_duplex);
			pgt.sheet_width=raw.sheet_width;
			pgt.sheet_len=raw.sheet_len;
			pgt.page_width=raw.page_width;
			pgt.page_len=raw.page_len;
			pgt.font_size=raw.font_size;
			pgt.notching=raw.notching;
			pgt.stroke=raw.stroke;
			pgt.bar_size=raw.bar_size;
			pgt.bar_offset=raw.bar_offset;
			pgt.tech_bar=raw.tech_bar;
			pgt.tech_bar_gravity=raw.tech_bar_gravity;
			pgt.tech_bar_step=raw.tech_bar_step;
			pgt.tech_bar_color=raw.tech_bar_color;
			pgt.tech_bar_offset=raw.tech_bar_offset;
			pgt.tech_add=raw.tech_add;
			
			return pgt;
		}

	}
}