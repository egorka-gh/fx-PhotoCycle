package com.photodispatcher.model.dao{
	import com.photodispatcher.event.AsyncSQLEvent;
	import com.photodispatcher.model.BookSynonym;
	import com.photodispatcher.model.ContentFilter;

	public class ContentFilterDAO extends BaseDAO{


		override protected function processRow(o:Object):Object{
			var a:ContentFilter = new ContentFilter();
			fillRow(o,a);
			return a;
		}
		
		override public function save(item:Object):void{
			var it:ContentFilter= item as ContentFilter;
			if(!it) return;
			if (it.loaded){
				update(it);
			}else{
				create(it);
			}
		}

		public function update(item:ContentFilter):void{
			execute(
				'UPDATE config.content_filter'+
				' SET name=?, is_photo_allow=?, is_retail_allow=?, is_pro_allow=?, is_alias_filter=?' + 
				' WHERE id=?',
				[	item.name,
					item.is_photo_allow?1:0,
					item.is_retail_allow?1:0,
					item.is_pro_allow?1:0,
					item.is_alias_filter?1:0,
					item.id],item);
		}
		
		public function create(item:ContentFilter):void{
			addEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT,onCreate);
			execute(
				"INSERT INTO config.content_filter (name, is_photo_allow, is_retail_allow, is_pro_allow, is_alias_filter) " +
				"VALUES (?,?,?,?,?)",
				[	item.name,
					item.is_photo_allow?1:0,
					item.is_retail_allow?1:0,
					item.is_pro_allow?1:0,
					item.is_alias_filter?1:0],item);
		}
		private function onCreate(e:AsyncSQLEvent):void{
			removeEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT,onCreate);
			if(e.result==AsyncSQLEvent.RESULT_COMLETED){
				var it:ContentFilter= e.item as ContentFilter;
				if(it){ 
					it.id=e.lastID;
					it.loaded=true;
				}
			}
		}
		
		public function findAllArray(includeDefault:Boolean=false):Array{
			var sql:String;
			sql='SELECT l.*'+
				' FROM config.content_filter l';
			if(!includeDefault) sql+=' WHERE l.id != 0';
			//sql+=' ORDER BY l.name';
			runSelect(sql);
			return itemsArray;
		}

		public function saveAliasesBatch(filterId:int, aliases:Array):void{
			if(!filterId || !aliases) return;
			var sequence:Array=[];

			var item:BookSynonym;
			var sql:String;
			var params:Array;

			sql='DELETE FROM config.content_filter_alias WHERE filter=?';
			sequence.push(prepareStatement(sql,[filterId]));
			
			for each(item in aliases){
				if(item && item.is_allow){
					sql='INSERT INTO config.content_filter_alias(filter, alias) VALUES(?,?)';
					params=[filterId, item.id];
					sequence.push(prepareStatement(sql,params));
				}
			}
			executeSequence(sequence);
		}

	}
}