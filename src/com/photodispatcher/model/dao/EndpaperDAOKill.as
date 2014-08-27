package com.photodispatcher.model.dao{
	import com.photodispatcher.event.AsyncSQLEvent;
	import com.photodispatcher.model.Endpaper;
	
	import mx.collections.ArrayCollection;
	
	public class EndpaperDAOKill extends BaseDAO{
		
		public function findAll(silent:Boolean=false):ArrayCollection{
			var res:Array=findAllArray(silent);
			return new ArrayCollection(res);
		}
		
		public function findAllArray(silent:Boolean=false):Array{
			var sql:String='SELECT s.id, s.name'+
				' FROM config.endpaper s';
			//if(forEdit) sql+=' WHERE s.id NOT IN (0,1,2)';
			//sql+=' ORDER BY s.name';
			runSelect(sql,null,silent);
			var res:Array=itemsArray;
			return res;
		}
		
		override public function save(item:Object):void{
			var it:Endpaper=item as Endpaper;
			if(!it) return;
			if(it.id==0)  return; //predefined
			if (it.id==-1){
				create(it);
			}else{
				update(it);
			}
		}
		
		public function update(item:Endpaper):void{
			execute(
				'UPDATE config.endpaper SET name=? WHERE id=?',
				[	item.name,
					item.id],item);
		}
		
		public function create(item:Endpaper):void{
			addEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT,onCreate);
			execute("INSERT INTO config.endpaper (name)" +
				"VALUES (?)",
				[	item.name],item);
		}
		private function onCreate(e:AsyncSQLEvent):void{
			removeEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT,onCreate);
			if(e.result==AsyncSQLEvent.RESULT_COMLETED){
				var it:Endpaper= e.item as Endpaper;
				if(it){ 
					it.id=e.lastID;
					it.loaded=true;
				}
			}
		}

		override protected function processRow(o:Object):Object{
			var a:Endpaper= new Endpaper();
			fillRow(o,a);
			return a;
		}

	}
}