package com.photodispatcher.model.dao{
	
	import com.photodispatcher.event.AsyncSQLEvent;
	import com.photodispatcher.model.BookSynonym;
	import com.photodispatcher.model.OrderState;
	import com.photodispatcher.model.SourceType;
	import com.photodispatcher.util.GridUtil;
	import com.photodispatcher.view.itemRenderer.BooleanGridItemEditor;
	import com.photodispatcher.view.itemRenderer.CBoxGridItemEditor;
	
	import mx.collections.ArrayList;
	import mx.core.ClassFactory;
	
	import spark.components.gridClasses.GridColumn;

	public class BookSynonymDAO extends BaseDAO{
		
		override protected function processRow(o:Object):Object{
			var a:BookSynonym = new BookSynonym();
			/*
			a.id=o.id;
			a.src_type=o.src_type;
			a.synonym=o.synonym;
			a.book_type=o.book_type;
			
			a.src_type_name=o.src_type_name;
			a.book_type_name=o.book_type_name;
			
			a.loaded = true;
			*/
			fillRow(o,a);
			return a;
		}

		override public function save(item:Object):void{
			var it:BookSynonym= item as BookSynonym;
			if(!it) return;
			if (it.id){
				update(it);
			}else{
				create(it);
			}
		}
		
		public function update(item:BookSynonym):void{
			execute(
				'UPDATE config.book_synonym'+
				' SET src_type=?, synonym=?, book_type=?, is_horizontal=?' + 
				' WHERE id=?',
				[	item.src_type,
					item.synonym,
					item.book_type,
					item.is_horizontal?1:0,
					item.id],item);
		}
		
		public function create(item:BookSynonym):void{
			addEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT,onCreate);
			execute(
				"INSERT INTO config.book_synonym (src_type, synonym, book_type, is_horizontal) " +
				"VALUES (?,?,?,?)",
				[	item.src_type,
					item.synonym,
					item.book_type,
					item.is_horizontal?1:0],item);
		}
		private function onCreate(e:AsyncSQLEvent):void{
			removeEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT,onCreate);
			if(e.result==AsyncSQLEvent.RESULT_COMLETED){
				var it:BookSynonym= e.item as BookSynonym;
				if(it) it.id=e.lastID;
			}
		}

		public function findAllArray(src_type:int):Array{
			var sql:String;
			sql='SELECT l.*, st.name src_type_name, bt.name book_type_name'+
				' FROM config.book_synonym l'+
				' INNER JOIN config.src_type st ON l.src_type = st.id'+
				' INNER JOIN config.book_type bt ON l.book_type = bt.id'+
				' WHERE l.src_type = ?'+
				' ORDER BY l.synonym';
			runSelect(sql,[src_type]);
			return itemsArray;
		}

		public static function gridColumns():ArrayList{
			var result:ArrayList= new ArrayList();
			var col:GridColumn;
			//col= new GridColumn('src_type'); col.headerText='Тип источника'; col.labelFunction=idToLabel; col.itemEditor=new ClassFactory(CBoxGridItemEditor); result.addItem(col);
			col= new GridColumn('synonym'); col.headerText='Имя папки'; result.addItem(col);
			col= new GridColumn('book_type'); col.headerText='Тип книги'; col.labelFunction=GridUtil.idToLabel; col.itemEditor=new ClassFactory(CBoxGridItemEditor); result.addItem(col);
			col= new GridColumn('is_horizontal'); col.headerText='Горизотальная'; col.labelFunction=GridUtil.booleanToLabel; col.itemEditor=new ClassFactory(BooleanGridItemEditor); result.addItem(col);
			//var fmt:DateTimeFormatter=new DateTimeFormatter(); fmt.dateStyle=fmt.timeStyle=DateTimeStyle.SHORT; 
			/*
			col= new GridColumn('width'); col.headerText='Ширина'; result.addItem(col);
			col= new GridColumn('height'); col.headerText='Длина'; result.addItem(col);
			col= new GridColumn('paper'); col.headerText='Бумага'; col.labelFunction=idToLabel; col.itemEditor=new ClassFactory(CBoxGridItemEditor); result.addItem(col);
			col= new GridColumn('frame'); col.headerText='Рамка'; col.labelFunction=idToLabel; col.itemEditor=new ClassFactory(CBoxGridItemEditor); result.addItem(col);
			col= new GridColumn('correction'); col.headerText='Коррекция'; col.labelFunction=idToLabel; col.itemEditor=new ClassFactory(CBoxGridItemEditor); result.addItem(col);
			col= new GridColumn('cutting'); col.headerText='Обрезка'; col.labelFunction=idToLabel; col.itemEditor=new ClassFactory(CBoxGridItemEditor); result.addItem(col);
			col= new GridColumn('pdf'); col.headerText='PDF шаблон'; col.labelFunction=idToLabel; col.itemEditor=new ClassFactory(CBoxGridItemEditor); result.addItem(col);
			col= new GridColumn('is_cover'); col.headerText='Обложка'; col.labelFunction=booleanToLabel; col.itemEditor=new ClassFactory(BooleanGridItemEditor); result.addItem(col);
			*/
			return result;
		}

		/**
		 * 
		 * @param path
		 * @param sourceType
		 * @return BookSynonym
		 */		
		/*
		public function translatePath(path:String, sourceType:int=SourceType.SRC_FOTOKNIGA):BookSynonym{
			var sql:String;
			var result:BookSynonym;
			sql='SELECT l.* FROM config.book_synonym l WHERE l.src_type = ? AND l.synonym = ?';
			runSelect(sql,[sourceType,path],true);
			if (lastResult==null) throw new Error('Блокировка чтения (translatePath1)',OrderState.ERR_READ_LOCK);
			result=item as BookSynonym;
			if(!result) return null;
			if (!result.loadTemplates()) throw new Error('Блокировка чтения (translatePath2)',OrderState.ERR_READ_LOCK);
			return result;
		}
		*/

		private static var synonymMap:Object;
		
		public static function initSynonymMap():Boolean{
			if(synonymMap) return true;
			var dao:BookSynonymDAO= new BookSynonymDAO();
			var sql:String='SELECT l.* FROM config.book_synonym l';
			dao.runSelect(sql,[],true);
			var a:Array=dao.itemsArray;
			if(!a) return false; //read lock
			var newMap:Object=new Object();
			var subMap:Object;
			var bs:BookSynonym;
			for each(bs in a){
				if(bs){
					if(!bs.loadTemplates()) return false; //read lock
					subMap=newMap[bs.src_type.toString()];
					if(!subMap){
						subMap= new Object();
						newMap[bs.src_type.toString()]=subMap;
					}
					subMap[bs.synonym]=bs;
				}
			}
			synonymMap=newMap;
			return true;
		}
		
		/**
		 * 
		 * @param path
		 * @param sourceType
		 * @return BookSynonym
		 */		
		public static function translatePath(path:String, sourceType:int=SourceType.SRC_FOTOKNIGA):BookSynonym{
			if(!synonymMap){
				if (!initSynonymMap()) throw new Error('Блокировка чтения (translatePath)',OrderState.ERR_READ_LOCK);
			}
			var map:Object=synonymMap[sourceType.toString()];
			if(!map) return null;
			var result:BookSynonym=map[path] as BookSynonym;
			return result; 
		}

	}
}