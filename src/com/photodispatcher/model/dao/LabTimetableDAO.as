package com.photodispatcher.model.dao{
	import com.photodispatcher.model.LabTimetable;
	
	public class LabTimetableDAO extends BaseDAO{

		public function getByDevice(device:int, silent:Boolean=false):Array {
			var sql:String;
			sql="SELECT wd.id day_id, wd.name day_id_name, ? lab_device,"+
					" IFNULL(STRFTIME('%m/%d/%Y %H:%M:%S', ltt.time_from),'01/01/2000 08:00:00') time_from,"+
					" IFNULL(STRFTIME('%m/%d/%Y %H:%M:%S', ltt.time_to),'01/01/2000 18:00:00') time_to,"+
					" IFNULL(ltt.is_online,0) is_online" +
					" FROM config.week_days wd"+
					" LEFT OUTER JOIN config.lab_timetable ltt ON  wd.id=ltt.day_id and ltt.lab_device=?"+
					" ORDER BY wd.id";	
			runSelect(sql,[device,device],silent );
			return itemsArray ;
		}
		
		public function saveSequence(items:Array):Array{
			var sequence:Array=[];
			var item:LabTimetable;
			var o:Object;
			//asyncFaultMode=FAULT_REPIT;
			var sql:String;
			var params:Array;
			if (!items) return [];
			for each(o in items){
				item= o as LabTimetable;
				if(item){
					sql='UPDATE config.lab_timetable SET time_from=?, time_to=?, is_online=? WHERE lab_device=? AND day_id=?';
					params=[item.time_from, item.time_to, item.is_online?1:0, item.lab_device, item.day_id];
					sequence.push(prepareStatement(sql,params));
					sql='INSERT OR IGNORE INTO config.lab_timetable(lab_device, day_id, time_from, time_to, is_online) VALUES(?,?,?,?,?)';
					params=[item.lab_device, item.day_id, item.time_from, item.time_to, item.is_online?1:0];
					sequence.push(prepareStatement(sql,params));
				}
			}
			return sequence;
		}

		override protected function processRow(o:Object):Object{
			var a:LabTimetable= new LabTimetable();
			fillRow(o,a);
			return a;
		}

	}
}