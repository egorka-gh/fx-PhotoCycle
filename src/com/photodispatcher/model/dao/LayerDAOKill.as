package com.photodispatcher.model.dao{
	import com.photodispatcher.event.AsyncSQLEvent;
	import com.photodispatcher.model.Layer;
	
	import mx.collections.ArrayCollection;

	public class LayerDAOKill extends BaseDAO{

		public function findAll(silent:Boolean=false):ArrayCollection{
			var res:Array=findAllArray(silent);
			return new ArrayCollection(res);
		}
		
		public function findAllArray(silent:Boolean=false):Array{
			var sql:String='SELECT s.id, s.name'+
				' FROM config.layer s';
			//if(forEdit) sql+=' WHERE s.id NOT IN (0,1,2)';
			//sql+=' ORDER BY s.name';
			runSelect(sql,null,silent);
			var res:Array=itemsArray;
			return res;
		}

		override public function save(item:Object):void{
			var it:Layer=item as Layer;
			if(!it) return;
			if(it.id==0 || it.id==1 || it.id==2)  return; //predefined
			if (it.id==-1){
				create(it);
			}else{
				update(it);
			}
		}

		public function update(item:Layer):void{
			execute(
				'UPDATE config.layer SET name=? WHERE id=?',
				[	item.name,
					item.id],item);
		}
		
		public function create(item:Layer):void{
			addEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT,onCreate);
			execute("INSERT INTO config.layer (name)" +
				"VALUES (?)",
				[	item.name],item);
		}
		private function onCreate(e:AsyncSQLEvent):void{
			removeEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT,onCreate);
			if(e.result==AsyncSQLEvent.RESULT_COMLETED){
				var it:Layer= e.item as Layer;
				if(it){ 
					it.id=e.lastID;
					it.loaded=true;
				}
			}
		}

		
		override protected function processRow(o:Object):Object{
			var a:Layer= new Layer();
			fillRow(o,a);
			return a;
		}

	}
}