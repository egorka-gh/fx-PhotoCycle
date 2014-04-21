package com.photodispatcher.model{
	import com.photodispatcher.model.dao.LabRollDAO;
	import com.photodispatcher.model.dao.LabTimetableDAO;
	import com.photodispatcher.model.dao.PrintGroupDAO;
	import com.photodispatcher.print.LabBase;
	import com.photodispatcher.util.ArrayUtil;

	public class LabDevice extends DBRecord{

		//db fileds
		[Bindable]
		public var id:int;
		[Bindable]
		public var lab:int;
		[Bindable]
		public var tech_point:int;
		[Bindable]
		public var name:String;
		[Bindable]
		public var speed1:Number=0.0;
		[Bindable]
		public var speed2:Number=0.0;
		
		
		public var queue_limit:int;

		[Bindable]
		public var onlineState:int=0;
		
		public function get isOnline():Boolean{
			return onlineState==LabBase.STATE_ON || onlineState==LabBase.STATE_ON_WARN;
		}
		//db drived
		[Bindable]
		public var tech_point_name:String;

		//db childs
		private var _rolls:Array;
		private var _timetable:Array;

		[Bindable]
		public function get timetable():Array{
			return _timetable;
		}
		public function set timetable(value:Array):void{
			_timetable = value;
		}
		
		public function getTimetable(silent:Boolean=false):Array{
			if(!loaded) return _timetable;
			var dao:LabTimetableDAO=new LabTimetableDAO();
			_timetable=dao.getByDevice(id,silent);
			return _timetable;
		}

		[Bindable]
		public function get rolls():Array{
			return _rolls;
		}
		public function set rolls(value:Array):void{
			_rolls = value;
		}
		
		public function getRolls(forEdit:Boolean=false, silent:Boolean=false):Array{
			if(!loaded) return _rolls;
			var dao:LabRollDAO=new LabRollDAO();
			_rolls=dao.getByDevice(id,forEdit,silent);
			//set speed
			if(_rolls){
				var roll:LabRoll;
				for each(roll in rolls){
					roll.is_online=false;//reset if persisted
					roll.speed=roll.width<203?speed1:speed2;
				}
			}
			return _rolls;
		}
		
		//run time
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
			var dao:PrintGroupDAO= new PrintGroupDAO();
			try{
				pg=dao.lastByTechPoint(tech_point);
				//check if new print goup - reset online rolls (reset manul settings)
				if((! _lastPG && pg) || ( _lastPG && pg && _lastPG.id != pg.id)) resetOnlineRolls();
				_lastPG=pg;
			} catch(error:Error){
				return false;
			}	
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
			if(!_timetable) getTimetable(true);
			if(!_timetable){
				onlineState=LabBase.STATE_OFF;
				return false;
			}
			var now:Date=new Date();
			var tt:LabTimetable=ArrayUtil.searchItem( 'day_id',now.day, _timetable) as LabTimetable;
			if(!tt || !tt.is_online){
				onlineState=LabBase.STATE_OFF;
				return false;
			}
			//reset to current date
			tt.time_from.date=1; tt.time_from.fullYear=now.fullYear; tt.time_from.month=now.month; tt.time_from.date=now.date; 
			tt.time_to.date=1; tt.time_to.fullYear=now.fullYear; tt.time_to.month=now.month; tt.time_to.date=now.date;
			if(now.time>=tt.time_from.time && now.time<=tt.time_to.time){
				onlineState=LabBase.STATE_ON;
			}else if(now.time<tt.time_from.time && (tt.time_from.time-now.time)/(1000*60)<=30){ //30min till on
				onlineState=LabBase.STATE_SCHEDULED_ON;
			}else{
				onlineState=LabBase.STATE_OFF;
			}
			return onlineState==LabBase.STATE_ON;
		}
		
		//minutes till device on
		public function timeToOn():int{
			if(!_timetable) getTimetable(true);
			if(!_timetable){
				return 1440;
			}
			var now:Date=new Date();
			var tt:LabTimetable=ArrayUtil.searchItem( 'day_id',now.day, _timetable) as LabTimetable;
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
			if(!_timetable) getTimetable(true);
			if(!_timetable){
				return 0;
			}
			var now:Date=new Date();
			var tt:LabTimetable=ArrayUtil.searchItem( 'day_id',now.day, _timetable) as LabTimetable;
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