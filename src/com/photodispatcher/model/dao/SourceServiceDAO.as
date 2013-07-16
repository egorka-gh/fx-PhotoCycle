package com.photodispatcher.model.dao{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.event.AsyncSQLEvent;
	import com.photodispatcher.model.SourceService;
	import com.photodispatcher.model.dao.daoi.ISourceServiceDAO;
	
	import mx.collections.ArrayCollection;
	
	public class SourceServiceDAO extends BaseDAO{
		
		public function getBySource(sourceId:int):Array{
			var sql:String='SELECT s.*, st.name type_name, st.loc_type FROM config.services s INNER JOIN config.srvc_type st ON st.id = s.srvc_id WHERE s.src_id = ?';
			runSelect(sql,[sourceId]);
			return itemsArray;
		}
		
		override public function save(item:Object):void{
			var it:SourceService=item as SourceService;
			if(!it) return;
			if (it.loaded){
				update(it);
			}else{
				create(it);
			}
		}
		
		public function update(item:SourceService):void{
			execute(
				"UPDATE config.services SET url=?, user=?, pass=?, connections=? WHERE src_id=? AND srvc_id=?",
				[	item.url,
					item.user,
					item.pass,
					item.connections,
					item.src_id,
					item.srvc_id],item);
		}
		
		public function create(item:SourceService):void{
			execute("INSERT INTO config.services (src_id, srvc_id, url, user, pass, connections) " +
					"VALUES (?,?,?,?,?,?)",
					[	item.src_id,
						item.srvc_id,
						item.url,
						item.user,
						item.pass,
						item.connections],item);
		}

		override protected function processRow(o:Object):Object{
			var a:SourceService = new SourceService();
			a.src_id=o.src_id;
			a.srvc_id=o.srvc_id;
			a.url=o.url;
			a.user=o.user;
			a.pass=o.pass;
			a.type_name=o.type_name;
			a.loc_type=o.loc_type;
			a.connections=o.connections;
			
			a.loaded = true;
			return a;
		}
	}
}