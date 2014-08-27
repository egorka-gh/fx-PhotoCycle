package com.photodispatcher.model.dao{
	import com.photodispatcher.event.AsyncSQLEvent;
	import com.photodispatcher.model.mysql.entities.TechPoint;
	
	import mx.collections.ArrayCollection;

	public class TechPointDAOKill extends BaseDAO{
		
		public function findAll(silent:Boolean=false, type:int=-1):ArrayCollection{
			var res:Array;
			if(type>0){
				res=findByType(type,silent);
			}else{
				res=findAllArray(silent);
			}
			return new ArrayCollection(res);
		}
		
		public function findAllArray(silent:Boolean=false):Array{
			var params:Array=null;
			var sql:String='SELECT s.id, s.name, s.tech_type, st.name tech_type_name, st.state tech_state, st.book_part tech_book_part'+
				' FROM config.tech_point s' +
				' INNER JOIN config.src_type st ON st.id = s.tech_type'
				' ORDER BY s.name';
			runSelect(sql,null,silent);
			var res:Array=itemsArray;
			return res;
		}
		
		public function findByType(type:int, silent:Boolean=false):Array{
			var sql:String='SELECT s.id, s.name, s.tech_type, st.name tech_type_name, st.state tech_state, st.book_part tech_book_part'+
							' FROM config.tech_point s' +
							' INNER JOIN config.src_type st ON st.id = s.tech_type'+
							' WHERE s.tech_type=?'+
							' ORDER BY s.name';
			runSelect(sql,[type],silent);
			var res:Array=itemsArray;
			return res;
		}
		
		override public function save(item:Object):void{
			var it:TechPoint=item as TechPoint;
			if(!it) return;
			if (it.id>0){
				update(it);
			}else{
				create(it);
			}
		}
		
		public function update(item:TechPoint):void{
			execute(
				'UPDATE config.tech_point SET name=?, tech_type=? WHERE id=?',
				[	item.name,
					item.tech_type,
					item.id],item);
		}
		
		public function create(item:TechPoint):void{
			addEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT,onCreate);
			execute("INSERT INTO config.tech_point (id, tech_type, name)" +
				"VALUES (?,?,?)",
				[	item.id > 0 ? item.id : null,
					item.tech_type,
					item.name],item);
		}
		private function onCreate(e:AsyncSQLEvent):void{
			removeEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT,onCreate);
			if(e.result==AsyncSQLEvent.RESULT_COMLETED){
				var it:TechPoint= e.item as TechPoint;
				if(it){ 
					it.id=e.lastID;
					it.loaded=true;
				}
			}
		}
		
		override protected function processRow(o:Object):Object{
			var a:TechPoint= new TechPoint();
			fillRow(o,a);
			return a;
		}

	}
}