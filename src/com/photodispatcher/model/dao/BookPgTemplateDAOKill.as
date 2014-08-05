package com.photodispatcher.model.dao{
	
	import com.photodispatcher.event.AsyncSQLEvent;
	import com.photodispatcher.model.mysql.entities.BookPgTemplate;
	import com.photodispatcher.util.GridUtil;
	import com.photodispatcher.view.itemRenderer.BooleanGridItemEditor;
	import com.photodispatcher.view.itemRenderer.CBoxGridItemEditor;
	import com.photodispatcher.view.itemRenderer.OffsetGridItemEditor;
	
	import mx.collections.ArrayList;
	import mx.core.ClassFactory;
	
	import spark.components.gridClasses.GridColumn;

	public class BookPgTemplateDAOKill extends BaseDAO{
		
		override protected function processRow(o:Object):Object{
			var a:BookPgTemplate = new BookPgTemplate();
			fillRow(o,a);
			return a;
		}

		override public function save(item:Object):void{
			var it:BookPgTemplate= item as BookPgTemplate;
			if(!it) return;
			if (it.id){
				update(it);
			}else{
				create(it);
			}
		}
		
		public function update(item:BookPgTemplate):void{
			execute(
				'UPDATE config.book_pg_template'+
				' SET book=?, book_part=?, width=?, height=?, height_add=?, paper=?, frame=?, correction=?, cutting=?, is_duplex=?, is_pdf=?, is_sheet_ready=?,'+
				' sheet_width=?, sheet_len=?, page_width=?, page_len=?, page_hoffset=?, font_size=?, font_offset=?, fontv_size=?, fontv_offset=?,'+
				' notching=?, stroke=?, bar_offset=?, bar_size=?,' + 
				' tech_bar=?, tech_add=?, tech_bar_color=?, tech_bar_step=?,'+
				' is_tech_center=?, tech_bar_offset=?, is_tech_top=?, tech_bar_toffset=?, is_tech_bot=?, tech_bar_boffset=?,' + 
				' tech_stair_add=?, tech_stair_step=?, is_tech_stair_top=?, is_tech_stair_bot=?' + 
				' WHERE id=?',
				[	item.book,
					item.book_part,
					item.width,
					item.height,
					item.height_add,
					item.paper,
					item.frame,
					item.correction,
					item.cutting,
					item.is_duplex?1:0,
					item.is_pdf?1:0,
					item.is_sheet_ready?1:0,
					item.sheet_width,
					item.sheet_len,
					item.page_width,
					item.page_len,
					item.page_hoffset,
					item.font_size,
					item.font_offset,
					item.fontv_size,
					item.fontv_offset,
					item.notching,
					item.stroke,
					item.bar_offset,
					item.bar_size,
					item.tech_bar,
					item.tech_add,
					item.tech_bar_color,
					item.tech_bar_step,
					item.is_tech_center?1:0,
					item.tech_bar_offset,
					item.is_tech_top?1:0,
					item.tech_bar_toffset,
					item.is_tech_bot?1:0,
					item.tech_bar_boffset,
					item.tech_stair_add,
					item.tech_stair_step,
					item.is_tech_stair_top?1:0,
					item.is_tech_stair_bot?1:0,
					item.id],item);
		}
		
		public function create(item:BookPgTemplate):void{
			addEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT,onCreate);
			execute(
				'INSERT INTO config.book_pg_template (book, book_part, width, height, height_add, paper, frame, correction, cutting, is_duplex, is_pdf, is_sheet_ready,'+
					' sheet_width, sheet_len, page_width, page_len, page_hoffset, font_size, font_offset, fontv_size, fontv_offset,'+
					' notching, stroke, bar_offset, bar_size,'+
					' tech_bar, tech_add, tech_bar_color, tech_bar_step, is_tech_center, tech_bar_offset, is_tech_top, tech_bar_toffset, is_tech_bot, tech_bar_boffset,'+
					' tech_stair_add, tech_stair_step, is_tech_stair_top, is_tech_stair_bot)' +
				'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
				[	item.book,
					item.book_part,
					item.width,
					item.height,
					item.height_add,
					item.paper,
					item.frame,
					item.correction,
					item.cutting,
					item.is_duplex?1:0,
					item.is_pdf?1:0,
					item.is_sheet_ready?1:0,
					item.sheet_width,
					item.sheet_len,
					item.page_width,
					item.page_len,
					item.page_hoffset,
					item.font_size,
					item.font_offset,
					item.fontv_size,
					item.fontv_offset,
					item.notching,
					item.stroke,
					item.bar_offset,
					item.bar_size,
					item.tech_bar,
					item.tech_add,
					item.tech_bar_color,
					item.tech_bar_step,
					item.is_tech_center?1:0,
					item.tech_bar_offset,
					item.is_tech_top?1:0,
					item.tech_bar_toffset,
					item.is_tech_bot?1:0,
					item.tech_bar_boffset,
					item.tech_stair_add,
					item.tech_stair_step,
					item.is_tech_stair_top?1:0,
					item.is_tech_stair_bot?1:0
				],item);
		}
		private function onCreate(e:AsyncSQLEvent):void{
			removeEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT,onCreate);
			if(e.result==AsyncSQLEvent.RESULT_COMLETED){
				var it:BookPgTemplate= e.item as BookPgTemplate;
				if(it) it.id=e.lastID;
			}
		}

		public function getByBook(book:int, silent:Boolean=true):Array{
			var sql:String;
			sql='SELECT pg.*, p.value paper_name, fr.value frame_name, cr.value correction_name, cu.value cutting_name, bp.name book_part_name'+
				' FROM config.book_pg_template pg'+
				' INNER JOIN config.attr_value p ON pg.paper = p.id'+
				' INNER JOIN config.attr_value fr ON pg.frame = fr.id'+
				' INNER JOIN config.attr_value cr ON pg.correction = cr.id'+
				' INNER JOIN config.attr_value cu ON pg.cutting = cu.id'+
				' INNER JOIN config.book_part bp ON pg.book_part = bp.id'+
				' WHERE pg.book=?';
			runSelect(sql,[book],silent);
			return itemsArray;
		}

		public static function gridColumns():ArrayList{
			var result:ArrayList= new ArrayList();
			var col:GridColumn;
			col= new GridColumn('book_part'); col.headerText='Часть книги';  col.width=100; col.labelFunction=GridUtil.idToLabel; col.itemEditor=new ClassFactory(CBoxGridItemEditor); result.addItem(col);
			col= new GridColumn('width'); col.headerText='Ширина'; col.width=70; result.addItem(col);
			col= new GridColumn('height'); col.headerText='Длина'; col.width=70; result.addItem(col);
			col= new GridColumn('height_add'); col.headerText='Увеличение длинны с каждой стороны'; result.addItem(col);
			col= new GridColumn('paper'); col.headerText='Бумага'; col.width=100; col.labelFunction=GridUtil.idToLabel; col.itemEditor=new ClassFactory(CBoxGridItemEditor); result.addItem(col);
			/*
			col= new GridColumn('frame'); col.headerText='Рамка'; col.labelFunction=idToLabel; col.itemEditor=new ClassFactory(CBoxGridItemEditor); result.addItem(col);
			col= new GridColumn('correction'); col.headerText='Коррекция'; col.labelFunction=idToLabel; col.itemEditor=new ClassFactory(CBoxGridItemEditor); result.addItem(col);
			col= new GridColumn('cutting'); col.headerText='Обрезка'; col.labelFunction=idToLabel; col.itemEditor=new ClassFactory(CBoxGridItemEditor); result.addItem(col);
			*/
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
			return result;
		}

	}
}