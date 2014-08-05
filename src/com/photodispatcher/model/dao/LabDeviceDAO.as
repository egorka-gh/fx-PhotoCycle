package com.photodispatcher.model.dao{
	import com.photodispatcher.event.AsyncSQLEvent;
	import com.photodispatcher.model.mysql.entities.LabDevice;
	import com.photodispatcher.model.mysql.entities.LabRoll;
	import com.photodispatcher.model.LabTimetable;
	
	import mx.collections.ArrayCollection;

	public class LabDeviceDAO extends BaseDAO{

		public function getByLab(labId:int, silent:Boolean=false):Array{
			var sql:String='SELECT s.id, s.lab, s.name, s.speed1, s.speed2, tech_point, tp.name tech_point_name'+
							' FROM config.lab_device s' +
							' LEFT OUTER JOIN config.tech_point tp ON tp.id = s.tech_point'+
							' WHERE s.lab=?'
			runSelect(sql,[labId],silent);
			var res:Array=itemsArray;
			return res;
		}
		
		override public function save(item:Object):void{
			var it:LabDevice=item as LabDevice;
			if(!it) return;
			if (it.id>0){
				update(it);
			}else{
				create(it);
			}
		}
		
		public function update(item:LabDevice):void{
			execute(
				'UPDATE config.lab_device SET name=?, speed1=?, speed2=?, tech_point=? WHERE id=?',
				[	item.name,
					item.speed1,
					item.speed2,
					item.tech_point,
					item.id],item);
		}
		
		public function updateSequence(items:Array):Array{
			if(!items) return [];
			var item:LabDevice;
			var sequence:Array=[];
			var o:Object;
			var sql:String;
			var params:Array;
			/*TODO refactor
			var lrDao:LabRollDAO= new LabRollDAO();
			*/
			var lttDao:LabTimetableDAO= new LabTimetableDAO();
			for each(o in items){
				item= o as LabDevice;
				if(item){
					if(item.changed){
						sql='UPDATE config.lab_device SET name=?, speed1=?, speed2=?, tech_point=? WHERE id=?';
						params=[item.name,item.speed1,item.speed2,item.tech_point,item.id];
						sequence.push(prepareStatement(sql,params));
					}
					//add roll update
					/*TODO refactor
					sequence=sequence.concat(lrDao.saveSequence(item.rolls));
					*/
					//add time table update
					//sequence=sequence.concat(lttDao.saveSequence(item.timetable));
				}
			}
			return sequence;
		}

		public function remove(id:int):void{
			execute('DELETE FROM config.lab_device WHERE id=?',[id]);
		}

		public function create(item:LabDevice):void{
			addEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT,onCreate);
			execute("INSERT INTO config.lab_device (id, lab, name, speed1, speed2, tech_point)" +
				"VALUES (?,?,?,?,?,?)",
				[	item.id > 0 ? item.id : null,
					item.lab,
					item.name,
					item.speed1,
					item.speed2,
					item.tech_point]
				,item);
		}
		private function onCreate(e:AsyncSQLEvent):void{
			removeEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT,onCreate);
			if(e.result==AsyncSQLEvent.RESULT_COMLETED){
				var it:LabDevice= e.item as LabDevice;
				if(it){ 
					it.id=e.lastID;
					it.loaded=true;
				}
			}
		}

/*
		override protected function processRow(o:Object):Object{
			var a:LabDevice= new LabDevice();
			fillRow(o,a);
			return a;
		}
		*/
	}
}