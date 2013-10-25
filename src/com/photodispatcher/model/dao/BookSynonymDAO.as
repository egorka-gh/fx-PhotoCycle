package com.photodispatcher.model.dao{
	
	import com.photodispatcher.event.AsyncSQLEvent;
	import com.photodispatcher.model.BookPgTemplate;
	import com.photodispatcher.model.BookSynonym;
	import com.photodispatcher.model.OrderState;
	import com.photodispatcher.model.SourceType;
	import com.photodispatcher.util.GridUtil;
	import com.photodispatcher.view.itemRenderer.BooleanGridItemEditor;
	import com.photodispatcher.view.itemRenderer.CBoxGridItemEditor;
	
	import flash.geom.Point;
	
	import mx.collections.ArrayList;
	import mx.core.ClassFactory;
	
	import spark.components.gridClasses.GridColumn;

	public class BookSynonymDAO extends BaseDAO{
		
		override protected function processRow(o:Object):Object{
			var a:BookSynonym = new BookSynonym();
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
				' SET src_type=?, synonym=?, book_type=?, is_horizontal=?, fb_alias=?' + 
				' WHERE id=?',
				[	item.src_type,
					item.synonym,
					item.book_type,
					item.is_horizontal?1:0,
					item.fb_alias,
					item.id],item);
		}
		
		public function create(item:BookSynonym):void{
			addEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT,onCreate);
			execute(
				"INSERT INTO config.book_synonym (src_type, synonym, book_type, is_horizontal, fb_alias) " +
				"VALUES (?,?,?,?,?)",
				[	item.src_type,
					item.synonym,
					item.book_type,
					item.is_horizontal?1:0,
					item.fb_alias],item);
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
			col= new GridColumn('synonym'); col.headerText='Имя папки'; result.addItem(col);
			col= new GridColumn('fb_alias'); col.headerText='Алиас розницы'; result.addItem(col);
			col= new GridColumn('book_type'); col.headerText='Тип книги'; col.labelFunction=GridUtil.idToLabel; col.itemEditor=new ClassFactory(CBoxGridItemEditor); result.addItem(col);
			col= new GridColumn('is_horizontal'); col.headerText='Горизотальная'; col.labelFunction=GridUtil.booleanToLabel; col.itemEditor=new ClassFactory(BooleanGridItemEditor); result.addItem(col);
			return result;
		}

		private static var synonymMap:Object;
		private static var aliasMap:Object;
		
		public static function initSynonymMap():Boolean{
			if(synonymMap) return true;
			var dao:BookSynonymDAO= new BookSynonymDAO();
			var sql:String='SELECT l.* FROM config.book_synonym l';
			dao.runSelect(sql,[],true);
			var a:Array=dao.itemsArray;
			if(!a) return false; //read lock
			var newMap:Object=new Object();
			var newAliasMap:Object=new Object();
			var subMap:Object;
			var bs:BookSynonym;
			for each(bs in a){
				if(bs){
					if(!bs.loadTemplates()) return false; //read lock
					if(bs.synonym){
						//add to synonym map
						subMap=newMap[bs.src_type.toString()];
						if(!subMap){
							subMap= new Object();
							newMap[bs.src_type.toString()]=subMap;
						}
						subMap[bs.synonym]=bs;
					}
					if(bs.fb_alias){
						//add to alias map
						newAliasMap[bs.fb_alias]=bs;
					}
				}
			}
			synonymMap=newMap;
			aliasMap=newAliasMap;
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

		public static function translateAlias(alias:String):BookSynonym{
			if(!alias) return null;
			if(!aliasMap){
				if (!initSynonymMap()) throw new Error('Блокировка чтения (translateAlias)',OrderState.ERR_READ_LOCK);
			}
			return aliasMap[alias] as BookSynonym; 
		}

		public static function guess(paper:int,coverSize:Point,blockSise:Point):BookSynonym{
			if(!paper || !coverSize || !blockSise) return null;
			if(!synonymMap){
				if (!initSynonymMap()) throw new Error('Блокировка чтения (guess)',OrderState.ERR_READ_LOCK);
			}
			var map:Object;
			var bs:BookSynonym;
			var it:BookPgTemplate;
			var currCover:BookPgTemplate;
			var currBlock:BookPgTemplate;
			var resultCover:BookPgTemplate;
			var resultBlock:BookPgTemplate;
			var result:BookSynonym;
			for each(map in synonymMap){//by src type
				for each(bs in map){
					currCover=null;
					currBlock=null;
					for each(it in bs.templates){
						if(it.book_part==BookSynonym.BOOK_PART_COVER && it.paper==paper && !it.is_pdf) currCover=it;
						if(it.book_part==BookSynonym.BOOK_PART_BLOCK && it.paper==paper && !it.is_pdf) currBlock=it;
					}
					if(currCover && currBlock 
						&& currCover.sheet_width>=Math.min(coverSize.x,coverSize.y) //&& currCover.sheet_len>=Math.max(coverSize.x,coverSize.y)
						&& currBlock.sheet_width>=Math.min(blockSise.x,blockSise.y) && currBlock.sheet_len>=Math.max(blockSise.x,blockSise.y) ){
						if(!result || 
							((currCover.sheet_width<=resultCover.sheet_width ) //|| currCover.sheet_len<=resultCover.sheet_len)
								&& (currBlock.sheet_width<=resultBlock.sheet_width || currBlock.sheet_len<=resultBlock.sheet_len)) ){
							result=bs;
							resultCover=currCover;
							resultBlock=currBlock;
						}
					}
				}
			}
			return result;
		}

	}
}