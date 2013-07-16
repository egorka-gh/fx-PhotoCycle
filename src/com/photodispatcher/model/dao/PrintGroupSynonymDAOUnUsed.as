package com.photodispatcher.model.dao{
	import com.photodispatcher.event.AsyncSQLEvent;
	import com.photodispatcher.model.OrderState;
	import com.photodispatcher.model.PrintGroup;
	import com.photodispatcher.model.PrintGroupSynonym;
	import com.photodispatcher.view.itemRenderer.BooleanGridItemEditor;
	import com.photodispatcher.view.itemRenderer.CBoxGridItemEditor;
	
	import mx.collections.ArrayList;
	import mx.core.ClassFactory;
	
	import spark.components.gridClasses.GridColumn;

	public class PrintGroupSynonymDAOUnUsed extends BaseDAO{
		
		override protected function processRow(o:Object):Object{
			var a:PrintGroupSynonym = new PrintGroupSynonym();
			a.id=o.id;
			a.src_type=o.src_type;
			a.synonym=o.synonym;
			a.width=o.width;
			a.height=o.height;
			a.paper=o.paper;
			a.frame=o.frame;
			a.correction=o.correction;
			a.cutting=o.cutting;
			a.cover=o.cover;
			a.pdf=o.pdf;
			a.is_book=o.is_book==1;
			a.is_cover=o.is_cover==1;
			
			a.src_type_name=o.src_type_name;
			a.correction_name=o.correction_name;
			a.cutting_name=o.cutting_name;
			a.frame_name=o.frame_name;
			a.paper_name=o.paper_name;
			a.cover_name=o.cover_name;
			a.pdf_name=o.pdf_name;
			
			a.loaded = true;
			return a;
		}

		override public function save(item:Object):void{
			var it:PrintGroupSynonym= item as PrintGroupSynonym;
			if(!it) return;
			if (it.id){
				update(it);
			}else{
				create(it);
			}
		}
		
		public function update(item:PrintGroupSynonym):void{
			execute(
				'UPDATE config.pg_synonym'+
				' SET src_type=?, synonym=?, width=?, height=?, paper=?, frame=?, correction=?, cutting=?, pdf=?, is_cover=?, is_book=?' + 
				' WHERE id=?',
				[	item.src_type,
					item.synonym,
					item.width,
					item.height,
					item.paper,
					item.frame,
					item.correction,
					item.cutting,
					item.pdf,
					item.is_cover?1:0,
					item.is_book?1:0,
					item.id],item);
		}
		
		public function create(item:PrintGroupSynonym):void{
			addEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT,onCreate);
			execute(
				"INSERT INTO config.pg_synonym (src_type, synonym, width, height, paper, frame, correction, cutting, pdf, is_cover, is_book) " +
				"VALUES (?,?,?,?,?,?,?,?,?,?,?)",
				[	item.src_type,
					item.synonym,
					item.width,
					item.height,
					item.paper,
					item.frame,
					item.correction,
					item.cutting,
					item.pdf,
					item.is_cover?1:0,
					item.is_book?1:0],item);
		}
		private function onCreate(e:AsyncSQLEvent):void{
			removeEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT,onCreate);
			if(e.result==AsyncSQLEvent.RESULT_COMLETED){
				var it:PrintGroupSynonym= e.item as PrintGroupSynonym;
				if(it) it.id=e.lastID;
			}
		}

		public function findAllArray(src_type:int):Array{
			var sql:String;
			sql='SELECT l.*, p.value paper_name, fr.value frame_name, cr.value correction_name, cu.value cutting_name, pt.name pdf_name, st.name src_type_name'+
				' FROM config.pg_synonym l'+
				' INNER JOIN config.src_type st ON l.src_type = st.id'+
				' INNER JOIN config.attr_value p ON l.paper = p.id'+
				' INNER JOIN config.attr_value fr ON l.frame = fr.id'+
				' INNER JOIN config.attr_value cr ON l.correction = cr.id'+
				' INNER JOIN config.attr_value cu ON l.cutting = cu.id'+
				' INNER JOIN config.pdf_template pt ON l.pdf = pt.id'+
				' WHERE l.src_type = ?'+
				' ORDER BY l.synonym';
			runSelect(sql,[src_type]);
			return itemsArray;
		}

		/*
		public static function idToLabel(item:Object, column:GridColumn):String{
			return item[column.dataField+'_name'];
		}
		public static function booleanToLabel(item:Object, column:GridColumn):String{
			return item[column.dataField]?'Да':'Нет';
		}
		*/
		
		public static function gridColumns():ArrayList{
			var result:ArrayList= new ArrayList();
			var col:GridColumn;
			col= new GridColumn('src_type'); col.headerText='Тип источника'; col.labelFunction=idToLabel; col.itemEditor=new ClassFactory(CBoxGridItemEditor); result.addItem(col);
			col= new GridColumn('synonym'); col.headerText='Папка'; result.addItem(col);
			//var fmt:DateTimeFormatter=new DateTimeFormatter(); fmt.dateStyle=fmt.timeStyle=DateTimeStyle.SHORT; 
			col= new GridColumn('width'); col.headerText='Ширина'; result.addItem(col);
			col= new GridColumn('height'); col.headerText='Длина'; result.addItem(col);
			col= new GridColumn('paper'); col.headerText='Бумага'; col.labelFunction=idToLabel; col.itemEditor=new ClassFactory(CBoxGridItemEditor); result.addItem(col);
			/*
			col= new GridColumn('frame'); col.headerText='Рамка'; col.labelFunction=idToLabel; col.itemEditor=new ClassFactory(CBoxGridItemEditor); result.addItem(col);
			col= new GridColumn('correction'); col.headerText='Коррекция'; col.labelFunction=idToLabel; col.itemEditor=new ClassFactory(CBoxGridItemEditor); result.addItem(col);
			col= new GridColumn('cutting'); col.headerText='Обрезка'; col.labelFunction=idToLabel; col.itemEditor=new ClassFactory(CBoxGridItemEditor); result.addItem(col);
			*/
			col= new GridColumn('pdf'); col.headerText='PDF шаблон'; col.labelFunction=idToLabel; col.itemEditor=new ClassFactory(CBoxGridItemEditor); result.addItem(col);
			col= new GridColumn('is_cover'); col.headerText='Обложка'; col.labelFunction=booleanToLabel; col.itemEditor=new ClassFactory(BooleanGridItemEditor); result.addItem(col);
			return result;
		}

		/**
		 * 
		 * @param sourceType
		 * @param path
		 * @return array of PrintGroup 
		 * 	1 for cover & 1 for sheet
		 * 
		 */		
		public function translatePath(sourceType:int, path:String):Array{
			var sql:String;
			sql='SELECT l.* FROM config.pg_synonym l WHERE l.src_type = ? AND l.synonym = ? ORDER BY l.is_cover DESC';
			runSelect(sql,[sourceType,path]);
			var a:Array=itemsArray;
			if(a==null) throw new Error('Блокировка чтения (translatePath)',OrderState.ERR_READ_LOCK);
			var res:Array;
			var pgs:PrintGroupSynonym;
			var pg:PrintGroup;
			for each(pgs in a){
				if(pgs){
					if(!res) res=[];
					pg= new PrintGroup();
					pg.correction=pgs.correction;
					pg.cover=pgs.cover;
					pg.cutting=pgs.cutting;
					pg.frame=pgs.frame;
					pg.height=pgs.height;
					pg.paper=pgs.paper;
					pg.path=path;
					pg.pdf=pgs.pdf;
					pg.width=pgs.width;
					pg.is_cover=pgs.is_cover;
					pg.is_book=pgs.is_book;
					res.push(pg);
				}
			}
			return res;
		}

	}
}