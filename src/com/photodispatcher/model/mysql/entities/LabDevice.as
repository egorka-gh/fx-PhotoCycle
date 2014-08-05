/**
 * Generated by Gas3 v2.3.2 (Granite Data Services).
 *
 * NOTE: this file is only generated if it does not exist. You may safely put
 * your custom code here.
 */

package com.photodispatcher.model.mysql.entities {
	import com.photodispatcher.model.PrintGroup;
	import com.photodispatcher.print.LabGeneric;
	import com.photodispatcher.util.ArrayUtil;

    [Bindable]
    [RemoteClass(alias="com.photodispatcher.model.mysql.entities.LabDevice")]
    public class LabDevice extends LabDeviceBase {
		
		//run time
		public var onlineState:int=0;
		
		public function get isOnline():Boolean{
			return onlineState==LabGeneric.STATE_ON || onlineState==LabGeneric.STATE_ON_WARN;
		}

		private var _currentBusyTime:int=0;//sek
		/**
		 * время на печать текущей группы печати
		 * @return  сек
		 * 
		 */		
		public function get currentBusyTime():int{
			return _currentBusyTime;
		}
		public function setCurrentBusyTime(queue:Array):void{
			_currentBusyTime=0;
			if(!queue || !lastPG || !lastRool) return;
			var pg:PrintGroup=ArrayUtil.searchItem('id', lastPG.id,queue) as PrintGroup;
			if(pg){
				var height:int=(pg.width==lastRool.width)?pg.height:pg.width;
				_currentBusyTime=height*(pg.prints-pg.prints_done)/lastRool.speed;
			}
		}
		
		/**
		 * доступное рабочее время до отключения
		 * @return сек  
		 * 
		 */		
		public function get maxAvailableTime():int{
			return timeToOff()*60-currentBusyTime;
		}
		
		private var _lastPG:PrintGroup;
		public function get lastPG():PrintGroup{
			return _lastPG;
		}
		
		private var _lastRoll:LabRoll;
		public function get lastRool():LabRoll{
			return _lastRoll;
		}
		
		public function refresh():Boolean{
			if(!tech_point){
				_lastPG=null;
				return true;
			}
			var result:Boolean=true;
			var pg:PrintGroup;
			
			/*TODO REFACTOR
			var dao:PrintGroupDAO= new PrintGroupDAO();
			try{
				pg=dao.lastByTechPoint(tech_point);
				//check if new print goup - reset online rolls (reset manul settings)
				if((! _lastPG && pg) || ( _lastPG && pg && _lastPG.id != pg.id)) resetOnlineRolls();
				_lastPG=pg;
			} catch(error:Error){
				return false;
			}
			*/
			return true;
		}
		
		private function resetOnlineRolls():void{
			if(rolls){
				var roll:LabRoll;
				for each(roll in rolls) roll.is_online=false;
			}
		}
		
		private function hasOnlineRolls():Boolean{
			if(!rolls) return false;
			var roll:LabRoll;
			for each(roll in rolls){
				if(roll.is_online) return true;
			}
			return false;
		}
		
		public function setRollByChanel(byChanel:LabPrintCode):LabRoll{
			_lastRoll=null;
			if(!byChanel || !rolls) return null;
			var roll:LabRoll;
			for each(roll in rolls){
				if(roll.width==byChanel.roll && roll.paper==byChanel.paper){
					_lastRoll=roll;
					if(!hasOnlineRolls()) _lastRoll.is_online=true; //no manual online rolls
					break;
				}
			}
			return _lastRoll;
		}
		
		public function checkTimeTable():Boolean{
			if(!timetable){
				onlineState=LabGeneric.STATE_OFF;
				return false;
			}
			var now:Date=new Date();
			var tt:LabTimetable=ArrayUtil.searchItem( 'day_id',now.day, timetable.toArray()) as LabTimetable;
			if(!tt || !tt.is_online){
				onlineState=LabGeneric.STATE_OFF;
				return false;
			}
			//reset to current date
			tt.time_from.date=1; tt.time_from.fullYear=now.fullYear; tt.time_from.month=now.month; tt.time_from.date=now.date; 
			tt.time_to.date=1; tt.time_to.fullYear=now.fullYear; tt.time_to.month=now.month; tt.time_to.date=now.date;
			if(now.time>=tt.time_from.time && now.time<=tt.time_to.time){
				onlineState=LabGeneric.STATE_ON;
			}else if(now.time<tt.time_from.time && (tt.time_from.time-now.time)/(1000*60)<=30){ //30min till on
				onlineState=LabGeneric.STATE_SCHEDULED_ON;
			}else{
				onlineState=LabGeneric.STATE_OFF;
			}
			return onlineState==LabGeneric.STATE_ON;
		}
		
		//minutes till device on
		public function timeToOn():int{
			if(!timetable){
				return 1440;
			}
			var now:Date=new Date();
			var tt:LabTimetable=ArrayUtil.searchItem( 'day_id',now.day, timetable.toArray()) as LabTimetable;
			if(!tt || !tt.is_online){
				return 1440;
			}
			//reset to current date
			tt.time_from.date=1; tt.time_from.fullYear=now.fullYear; tt.time_from.month=now.month; tt.time_from.date=now.date; 
			tt.time_to.date=1; tt.time_to.fullYear=now.fullYear; tt.time_to.month=now.month; tt.time_to.date=now.date;
			if(now.time>=tt.time_from.time && now.time<=tt.time_to.time){
				return 0;
			}else if(now.time<tt.time_from.time){
				return Math.round((tt.time_from.time-now.time)/(1000*60));
			}else{
				return 1440;
			}
		}
		//minutes till device off, or full work day if waite to on
		public function timeToOff():int{
			if(!timetable){
				return 0;
			}
			var now:Date=new Date();
			var tt:LabTimetable=ArrayUtil.searchItem( 'day_id',now.day, timetable.toArray()) as LabTimetable;
			if(!tt || !tt.is_online){
				return 0;
			}
			//reset to current date
			tt.time_from.date=1; tt.time_from.fullYear=now.fullYear; tt.time_from.month=now.month; tt.time_from.date=now.date; 
			tt.time_to.date=1; tt.time_to.fullYear=now.fullYear; tt.time_to.month=now.month; tt.time_to.date=now.date;
			if(now.time>=tt.time_from.time && now.time<=tt.time_to.time){
				// till off
				return Math.round((tt.time_to.time-now.time)/(1000*60));
			}else if(now.time<tt.time_from.time){
				//work time
				return Math.round((tt.time_to.time-tt.time_from.time)/(1000*60));
			}else{
				return 0;
			}
		}

    }
}