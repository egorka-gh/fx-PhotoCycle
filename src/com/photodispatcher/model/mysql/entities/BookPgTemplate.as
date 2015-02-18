/**
 * Generated by Gas3 v2.3.2 (Granite Data Services).
 *
 * NOTE: this file is only generated if it does not exist. You may safely put
 * your custom code here.
 */

package com.photodispatcher.model.mysql.entities {
	import com.photodispatcher.util.GridUtil;
	import com.photodispatcher.view.itemRenderer.BooleanGridItemEditor;
	import com.photodispatcher.view.itemRenderer.CBoxGridItemEditor;
	import com.photodispatcher.view.itemRenderer.CBoxGridItemEditorFullList;
	import com.photodispatcher.view.itemRenderer.OffsetGridItemEditor;
	
	import mx.collections.ArrayList;
	import mx.core.ClassFactory;
	
	import spark.components.gridClasses.GridColumn;

    [Bindable]
    [RemoteClass(alias="com.photodispatcher.model.mysql.entities.BookPgTemplate")]
    public class BookPgTemplate extends BookPgTemplateBase {
		
		public static function gridColumns():ArrayList{
			var result:ArrayList= new ArrayList();
			var col:GridColumn;
			col= new GridColumn('book_part'); col.headerText='Часть книги';  col.width=100; col.labelFunction=GridUtil.idToLabel; col.itemEditor=new ClassFactory(CBoxGridItemEditor); result.addItem(col);
			col= new GridColumn('width'); col.headerText='Ширина'; col.width=70; result.addItem(col);
			col= new GridColumn('height'); col.headerText='Длина'; col.width=70; result.addItem(col);
			col= new GridColumn('height_add'); col.headerText='Увеличение длинны с каждой стороны'; result.addItem(col);
			col= new GridColumn('paper'); col.headerText='Бумага'; col.width=100; col.labelFunction=GridUtil.idToLabel; col.itemEditor=new ClassFactory(CBoxGridItemEditor); result.addItem(col);
			col= new GridColumn('is_duplex'); col.headerText='Duplex'; col.labelFunction=GridUtil.booleanToLabel; col.itemEditor=new ClassFactory(BooleanGridItemEditor); col.width=60; result.addItem(col);
			col= new GridColumn('is_pdf'); col.headerText='PDF'; col.labelFunction=GridUtil.booleanToLabel; col.itemEditor=new ClassFactory(BooleanGridItemEditor); col.width=50; result.addItem(col);
			col= new GridColumn('is_sheet_ready'); col.headerText='Готовый разворот'; col.labelFunction=GridUtil.booleanToLabel; col.itemEditor=new ClassFactory(BooleanGridItemEditor); col.width=50; result.addItem(col);
			col= new GridColumn('sheet_width'); col.headerText='Ширина разворота pix'; result.addItem(col);
			col= new GridColumn('sheet_len'); col.headerText='Длина разворота pix'; result.addItem(col);
			col= new GridColumn('page_width'); col.headerText='Ширина страницы pix'; result.addItem(col);
			col= new GridColumn('page_len'); col.headerText='Длина страницы pix'; result.addItem(col);
			col= new GridColumn('page_hoffset'); col.headerText='Смещение страницы pix'; col.width=60; result.addItem(col);
			col= new GridColumn('font_size'); col.headerText='Шрифт'; col.width=60; result.addItem(col);
			col= new GridColumn('font_offset'); col.headerText='Шрифт смещение pix'; col.itemEditor=new ClassFactory(OffsetGridItemEditor); result.addItem(col);
			col= new GridColumn('notching'); col.headerText='Насечка pix'; result.addItem(col);
			col= new GridColumn('stroke'); col.headerText='Рамка pix'; result.addItem(col);
			col= new GridColumn('bar_size'); col.headerText='Подпись книги высота pix'; result.addItem(col);
			col= new GridColumn('bar_offset'); col.headerText='Подпись книги смещение pix'; col.itemEditor=new ClassFactory(OffsetGridItemEditor); result.addItem(col);
			col= new GridColumn('fontv_size'); col.headerText='Вертикальная подпись шрифт'; col.width=60; result.addItem(col);
			col= new GridColumn('fontv_offset'); col.headerText='Вертикальная подпись смещение pix'; col.itemEditor=new ClassFactory(OffsetGridItemEditor); result.addItem(col);
			col= new GridColumn('lab_type'); col.headerText='Тип лабы'; col.labelFunction=GridUtil.idToLabel; col.itemEditor=new ClassFactory(CBoxGridItemEditorFullList); result.addItem(col);
			return result;
		}

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
			raw.height_add=height_add;
			raw.paper=paper;
			raw.frame=frame;
			raw.correction=correction;
			raw.cutting=cutting;
			raw.is_pdf=is_pdf?1:0;
			raw.is_sheet_ready=is_sheet_ready?1:0;
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
			raw.tech_bar_step=tech_bar_step;
			raw.tech_bar_color=tech_bar_color;
			raw.tech_add=tech_add;
			raw.is_tech_center=is_tech_center;
			raw.tech_bar_offset=tech_bar_offset;
			raw.is_tech_top=is_tech_top;
			raw.tech_bar_toffset=tech_bar_toffset;
			raw.is_tech_bot=is_tech_bot;
			raw.tech_bar_boffset=tech_bar_boffset;
			raw.tech_stair_add=tech_stair_add;
			raw.tech_stair_step=tech_stair_step;
			raw.is_tech_stair_top=is_tech_stair_top;
			raw.is_tech_stair_bot=is_tech_stair_bot;
			
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
			pgt.height_add=raw.height_add;
			pgt.paper=raw.paper;
			pgt.frame=raw.frame;
			pgt.correction=raw.correction;
			pgt.cutting=raw.cutting;
			pgt.is_pdf=Boolean(raw.is_pdf);
			pgt.is_sheet_ready=Boolean(raw.is_sheet_ready);
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
			pgt.tech_bar_step=raw.tech_bar_step;
			pgt.tech_bar_color=raw.tech_bar_color;
			pgt.tech_add=raw.tech_add;
			pgt.is_tech_center=raw.is_tech_center;
			pgt.tech_bar_offset=raw.tech_bar_offset;
			pgt.is_tech_top=raw.is_tech_top;
			pgt.tech_bar_toffset=raw.tech_bar_toffset;
			pgt.is_tech_bot=raw.is_tech_bot;
			pgt.tech_bar_boffset=raw.tech_bar_boffset;
			pgt.tech_stair_add=raw.tech_stair_add;
			pgt.tech_stair_step=raw.tech_stair_step;
			pgt.is_tech_stair_top=raw.is_tech_stair_top;
			pgt.is_tech_stair_bot=raw.is_tech_stair_bot;
			
			return pgt;
		}

    }
}