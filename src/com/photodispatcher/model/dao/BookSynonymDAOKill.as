package com.photodispatcher.model.dao{
	
	import com.photodispatcher.context.Context;
	import com.photodispatcher.event.AsyncSQLEvent;
	import com.photodispatcher.model.mysql.entities.BookPgTemplate;
	import com.photodispatcher.model.mysql.entities.BookSynonym;
	import com.photodispatcher.model.SourceType;
	import com.photodispatcher.model.mysql.entities.OrderState;
	import com.photodispatcher.util.GridUtil;
	import com.photodispatcher.view.itemRenderer.BooleanGridItemEditor;
	import com.photodispatcher.view.itemRenderer.CBoxGridItemEditor;
	
	import flash.geom.Point;
	
	import mx.collections.ArrayList;
	import mx.core.ClassFactory;
	
	import spark.components.gridClasses.GridColumn;

	public class BookSynonymDAOKill extends BaseDAO{
		
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
		
		public function findAllArray(src_type:int, contentFilter:int=0):Array{
			var sql:String;
			if(contentFilter==0){
				sql='SELECT l.*, st.name src_type_name, bt.name book_type_name, 1 is_allow'+
					' FROM config.book_synonym l'+
					' INNER JOIN config.src_type st ON l.src_type = st.id'+
					' INNER JOIN config.book_type bt ON l.book_type = bt.id'+
					' WHERE l.src_type = ?'+
					' ORDER BY l.synonym';
				runSelect(sql,[src_type]);
			}else{
				sql='SELECT l.*, st.name src_type_name, bt.name book_type_name, ifnull(fa.alias,0) is_allow'+
					' FROM config.book_synonym l'+
					' INNER JOIN config.src_type st ON l.src_type = st.id'+
					' INNER JOIN config.book_type bt ON l.book_type = bt.id'+
					' LEFT OUTER JOIN config.content_filter_alias fa ON fa.filter= ? AND l.id=fa.alias'+
					' WHERE l.src_type = ?'+
					' ORDER BY l.synonym';
				runSelect(sql,[contentFilter, src_type]);
			}
			return itemsArray;
		}

		public function get4LayersetKill(src_type:int, layerset:int=0):Array{
			var sql:String;
			sql='SELECT l.*, st.name src_type_name, bt.name book_type_name, ifnull(la.alias,0) is_allow'+
				' FROM config.book_synonym l'+
				' INNER JOIN config.src_type st ON l.src_type = st.id'+
				' INNER JOIN config.book_type bt ON l.book_type = bt.id'+
				' LEFT OUTER JOIN config.layerset_alias la ON la.layerset=? AND la.alias=l.id'+
				' WHERE l.src_type = ?'+
				' ORDER BY l.synonym';
			runSelect(sql,[layerset, src_type]);
			return itemsArray;
		}

		public static function gridColumns(short:Boolean=false):ArrayList{
			var result:ArrayList= new ArrayList();
			var col:GridColumn;
			col= new GridColumn('synonym'); col.headerText='Имя папки'; result.addItem(col);
			if(!short){
				col= new GridColumn('fb_alias'); col.headerText='Алиас розницы'; result.addItem(col);
				col= new GridColumn('book_type'); col.headerText='Тип книги'; col.labelFunction=GridUtil.idToLabel; col.itemEditor=new ClassFactory(CBoxGridItemEditor); result.addItem(col);
				col= new GridColumn('is_horizontal'); col.headerText='Горизотальная'; col.labelFunction=GridUtil.booleanToLabel; col.itemEditor=new ClassFactory(BooleanGridItemEditor); result.addItem(col);
			}
			return result;
		}

		private static var synonymMap:Object;
		private static var aliasMap:Object;
		private static var filter:int=0;
		
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

		public static function guess(paper:int,coverSize:Point,blockSise:Point,sliceSise:Point):BookSynonym{
			if(!paper || !blockSise) return null;
			if(!synonymMap){
				if (!initSynonymMap()) throw new Error('Блокировка чтения (guess)',OrderState.ERR_READ_LOCK);
			}
			var bs:BookSynonym;
			var it:BookPgTemplate;
			var currCover:BookPgTemplate;
			var currSlice:BookPgTemplate;
			var currBlock:BookPgTemplate;
			var fit:Boolean;
			var resultCover:BookPgTemplate;
			var resultSlice:BookPgTemplate;
			var resultBlock:BookPgTemplate;
			var result:BookSynonym;

			for each(bs in aliasMap){
				//init templetes
				currCover=null;
				currBlock=null;
				currSlice=null;
				for each(it in bs.templates){
					if(it.book_part==BookSynonym.BOOK_PART_COVER && it.paper==paper && !it.is_pdf) currCover=it;
					if(it.book_part==BookSynonym.BOOK_PART_INSERT && it.paper==paper && !it.is_pdf) currSlice=it;
					if(it.book_part==BookSynonym.BOOK_PART_BLOCK && it.paper==paper && !it.is_pdf) currBlock=it;
				}
				//check template structure
				if( ((currCover && coverSize) || (!currCover && !coverSize)) && 
					((currSlice && sliceSise) || (!currSlice && !sliceSise)) 
					&& currBlock){
					//process synonym
					fit=true;
					//fit?
					if(currCover) fit=currCover.sheet_width>=coverSize.y;//Math.min(coverSize.x,coverSize.y);
					/*
					if(fit && currSlice) fit=(currSlice.sheet_width>=sliceSise.x && currSlice.sheet_len>=sliceSise.y) ||
											 (currSlice.sheet_width>=sliceSise.y && currSlice.sheet_len>=sliceSise.x);
					*/
					if(fit && currSlice) fit= currSlice.sheet_width>=sliceSise.y && currSlice.sheet_len>=sliceSise.x;
					//if(fit) fit=currBlock.sheet_width>=Math.min(blockSise.x,blockSise.y) && currBlock.sheet_len>=Math.max(blockSise.x,blockSise.y);
					if(fit) fit=currBlock.sheet_width>=blockSise.y && currBlock.sheet_len>=blockSise.x;
					//set result
					if(fit){
						if(result){
							//compare synonyms
							if(currCover) fit=currCover.sheet_width<=resultCover.sheet_width;
							/*
							if(fit && currSlice) fit=Math.min(currSlice.sheet_width,currSlice.sheet_len)<=Math.min(resultSlice.sheet_width,resultSlice.sheet_len) &&
													 Math.max(currSlice.sheet_width,currSlice.sheet_len)<=Math.max(resultSlice.sheet_width,resultSlice.sheet_len);
							*/
							if(fit && currSlice) fit=currSlice.sheet_width<=resultSlice.sheet_width && currSlice.sheet_len<=resultSlice.sheet_len;
							if(fit) fit=currBlock.sheet_width<=resultBlock.sheet_width && currBlock.sheet_len<=resultBlock.sheet_len;
						}
						if(fit){
							result=bs;
							resultCover=currCover;
							resultSlice=currSlice;
							resultBlock=currBlock;
						}
					}
				}
			}
			return result;
		}

	}
}