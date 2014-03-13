package com.photodispatcher.model.dao{
	import com.photodispatcher.event.AsyncSQLEvent;
	import com.photodispatcher.model.LayersetGroup;
	
	import mx.collections.ArrayCollection;
	
	public class LayersetGroupDAO extends BaseDAO{

		public function findAll(silent:Boolean=false):ArrayCollection{
			var res:Array=findAllArray(silent);
			return new ArrayCollection(res);
		}
		
		public function findAllArray(silent:Boolean=false):Array{
			var sql:String='SELECT s.*'+
				' FROM config.layerset_group s';
			runSelect(sql,null,silent);
			var res:Array=itemsArray;
			return res;
		}
		
		override public function save(item:Object):void{
			var it:LayersetGroup=item as LayersetGroup;
			if(!it) return;
			if (it.id==-1){
				create(it);
			}else{
				update(it);
			}
		}
		
		public function update(item:LayersetGroup):void{
			execute(
				'UPDATE config.layerset_group SET name=? WHERE id=?',
				[item.name, item.id],item);
		}
		
		public function create(item:LayersetGroup):void{
			addEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT,onCreate);
			execute("INSERT INTO config.layerset_group (name)" +
				" VALUES (?)",
				[item.name],item);
		}
		private function onCreate(e:AsyncSQLEvent):void{
			removeEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT,onCreate);
			if(e.result==AsyncSQLEvent.RESULT_COMLETED){
				var it:LayersetGroup= e.item as LayersetGroup;
				if(it){ 
					it.id=e.lastID;
					it.loaded=true;
				}
			}
		}

		override protected function processRow(o:Object):Object{
			var a:LayersetGroup= new LayersetGroup();
			fillRow(o,a);
			return a;
		}


	}
}