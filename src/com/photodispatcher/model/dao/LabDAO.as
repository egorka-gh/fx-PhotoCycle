package com.photodispatcher.model.dao{
	import com.photodispatcher.event.AsyncSQLEvent;
	import com.photodispatcher.model.Lab;
	
	import mx.collections.ArrayCollection;
	
	public class LabDAO extends BaseDAO{

		public function findAll(silent:Boolean=false):ArrayCollection{
			var res:Array=findAllArray(silent);
			return new ArrayCollection(res);
		}
		
		public function findAllArray(silent:Boolean=false):Array{
			var sql:String='SELECT s.*, st.name src_type_name'+
							' FROM config.lab s' +
							' INNER JOIN config.src_type st ON st.id = s.src_type'+
							' ORDER BY s.name';
			runSelect(sql,null,silent);
			var res:Array=itemsArray;
			return res;
		}

		public function findActive(silent:Boolean=false):Array{
			var sql:String='SELECT s.*, st.name src_type_name'+
				' FROM config.lab s' +
				' INNER JOIN config.src_type st ON st.id = s.src_type'+
				' WHERE s.is_active=1'+
				' ORDER BY s.name';
			runSelect(sql,null,silent);
			var res:Array=itemsArray;
			return res;
		}

		
		override public function save(item:Object):void{
			var it:Lab=item as Lab;
			if(!it) return;
			if (it.id>0){
				update(it);
			}else{
				create(it);
			}
		}
		
		public function update(item:Lab):void{
			/*
			execute(
				'UPDATE config.lab SET name=?, hot=?, hot_nfs=?, queue_limit=?, is_active=? WHERE id=?',
				[	item.name,
					item.hot,
					item.hot_nfs,
					item.queue_limit,
					item.is_active?1:0,
					item.id],item);
			*/
			var sequence:Array=[];
			if(item.changed){
				sequence.push(prepareStatement(
					'UPDATE config.lab SET name=?, hot=?, hot_nfs=?, queue_limit=?, is_active=?, is_managed=? WHERE id=?',
					[	item.name,
						item.hot,
						item.hot_nfs,
						item.queue_limit,
						item.is_active?1:0,
						item.is_managed?1:0,
						item.id]));
			}
			var ldDao:LabDeviceDAO= new LabDeviceDAO();
			sequence=sequence.concat(ldDao.updateSequence(item.devices));
			executeSequence(sequence);
		}
		
		public function create(item:Lab):void{
			addEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT,onCreate);
			execute("INSERT INTO config.lab (id, src_type, name, hot, hot_nfs, queue_limit, is_active, is_managed)" +
					"VALUES (?,?,?,?,?,?,?,?)",
				[	item.id > 0 ? item.id : null,
					item.src_type,
					item.name,
					item.hot,
					item.hot_nfs,
					item.queue_limit,
					item.is_active?1:0,
					item.is_managed?1:0],item);
		}
		private function onCreate(e:AsyncSQLEvent):void{
			removeEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT,onCreate);
			if(e.result==AsyncSQLEvent.RESULT_COMLETED){
				var it:Lab= e.item as Lab;
				if(it){ 
					it.id=e.lastID;
					it.loaded=true;
				}
			}
		}

		override protected function processRow(o:Object):Object{
			var a:Lab= new Lab();
			fillRow(o,a);
			return a;
		}

	}
}