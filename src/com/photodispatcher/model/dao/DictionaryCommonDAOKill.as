package com.photodispatcher.model.dao{
	import com.photodispatcher.event.AsyncSQLEvent;
	import com.photodispatcher.model.SynonymCommon;
	
	import mx.collections.ArrayList;
	
	import spark.components.gridClasses.GridColumn;

	public class DictionaryCommonDAOKill extends BaseDAO{
		

		public function getLayersetSynonyms(byItemId:int=-1, silent:Boolean=false):Array{
			var params:Array;
			var sql:String='SELECT s.id, s.item_id, s.synonym'+
				' FROM config.layerset_synonym s';
			if(byItemId==-1){
				sql+=' ORDER BY s.item_id, s.synonym';
			}else{
				sql+=' WHERE s.item_id=?';
				params=[byItemId];
			}
			runSelect(sql,params,silent);
			var res:Array=itemsArray;
			return res;
		}

		public function getEndpaperSynonyms(byItemId:int=-1, silent:Boolean=false):Array{
			var params:Array;
			var sql:String='SELECT s.id, s.item_id, s.synonym'+
				' FROM config.endpaper_synonym s';
			if(byItemId==-1){
				sql+=' ORDER BY s.item_id, s.synonym';
			}else{
				sql+=' WHERE s.item_id=?';
				params=[byItemId];
			}
			runSelect(sql,params,silent);
			var res:Array=itemsArray;
			return res;
		}

		public function saveLayersetSynonym(synonym:SynonymCommon):void{
			if(!synonym) return;
			if(!synonym.loaded){
				if(synonym.synonym){
					//insert
					addEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT,onCreate);
					execute("INSERT INTO config.layerset_synonym (item_id, synonym)" + //OR IGNORE 
						"VALUES (?, ?)",
						[	synonym.item_id,
							synonym.synonym],synonym);
				}
			}else{
				if(synonym.synonym){
					//update
					execute(
						'UPDATE config.layerset_synonym SET synonym=? WHERE id=?',
						[	synonym.synonym,
							synonym.id],synonym);
				}else{
					//delete
					execute(
						'DELETE FROM config.layerset_synonym WHERE id=?',
						[synonym.id],synonym);
				}
			}
		}
		private function onCreate(e:AsyncSQLEvent):void{
			removeEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT,onCreate);
			if(e.result==AsyncSQLEvent.RESULT_COMLETED){
				var it:SynonymCommon= e.item as SynonymCommon;
				if(it){ 
					it.id=e.lastID;
					it.loaded=true;
				}
			}
		}
		
		public function saveEndpaperSynonym(synonym:SynonymCommon):void{
			if(!synonym) return;
			if(!synonym.loaded){
				if(synonym.synonym){
					//insert
					addEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT,onCreate);
					execute("INSERT INTO config.endpaper_synonym (item_id, synonym)" + //OR IGNORE 
						"VALUES (?, ?)",
						[	synonym.item_id,
							synonym.synonym],synonym);
				}
			}else{
				if(synonym.synonym){
					//update
					execute(
						'UPDATE config.endpaper_synonym SET synonym=? WHERE id=?',
						[	synonym.synonym,
							synonym.id],synonym);
				}else{
					//delete
					execute(
						'DELETE FROM config.endpaper_synonym WHERE id=?',
						[synonym.id],synonym);
				}
			}
		}

		override protected function processRow(o:Object):Object{
			var a:SynonymCommon= new SynonymCommon();
			fillRow(o,a);
			return a;
		}
	}
}