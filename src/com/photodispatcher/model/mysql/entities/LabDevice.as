/**
 * Generated by Gas3 v2.3.2 (Granite Data Services).
 *
 * NOTE: this file is only generated if it does not exist. You may safely put
 * your custom code here.
 */

package com.photodispatcher.model.mysql.entities {
	import com.photodispatcher.print.LabGeneric;
	import com.photodispatcher.util.ArrayUtil;
	
	import flash.events.Event;
	import flash.utils.IDataInput;
	
	import mx.collections.ArrayCollection;
	import mx.collections.IList;
	import mx.collections.ListCollectionView;
	import mx.events.PropertyChangeEvent;

	[Bindable]
	[RemoteClass(alias="com.photodispatcher.model.mysql.entities.LabDevice")]
	public class LabDevice extends LabDeviceBase {
		
		//run time
		public var onlineState:int=0;
		
		/**
		 * используется для определения должен ли работать девайс по расписанию
		 */
		public function get isOnline():Boolean{
			return onlineState==LabGeneric.STATE_ON || onlineState==LabGeneric.STATE_ON_WARN;
		}
		
		/**
		 * хранит список совместимых по рулонам PrintGroup
		 */
		public var compatiableQueue:Array;

		/**
		 * хранит список PrintGroup для текущего рулона
		 */
		public var onLineRollQueue:Array;
		
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
			if(!queue || !lastPG || !lastRoll) return;
			var pg:PrintGroup=ArrayUtil.searchItem('id', lastPG.id,queue) as PrintGroup;
			if(pg){
				var height:int=(pg.width==lastRoll.width)?pg.height:pg.width;
				_currentBusyTime=height*(pg.prints-pg.prints_done)/lastRoll.speed;
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
		public function get lastRoll():LabRoll{
			return _lastRoll;
		}
		public function set lastRoll(roll:LabRoll):void{
			_lastRoll=roll;
			if(roll && rolls && rolls.length>0){
				for each (var r:LabRoll in rolls){
					if(r.paper==roll.paper && r.width==roll.width){
						r.is_last=true;
						_lastRoll=r;
					}else{
						r.is_last=false;
					}
				}
			}
		}
		
		
		private var _lastPrintDate:Date;
		
		/**
		 * время печати последнего листа, берется по логу тех.точки
		 * неа берется по labmeter
		 */
		public function get lastPrintDate():Date{
			return _lastPrintDate;
		}

		public function set lastPrintDate(value:Date):void{
			_lastPrintDate = value;
		}
		
		public var lastPostDate:Date;

		public var lastStop:LabMeter;

		
		protected var _rollsOnline:Array;
		/*
		public function set rollsOnline(value:ListCollectionView):void {
			_rollsOnline = value;
		}
		*/
		public function get rollsOnline():Array {
			return _rollsOnline;
		}
		
		public function setRollOnline(roll:LabRoll):void{
			if(roll && rolls && rolls.length>0){
				for each (var r:LabRoll in rolls){
					if(r.paper==roll.paper && r.width==roll.width){
						r.is_online=true;
						_rollsOnline.push(r);
						//rollsOnline.refresh();
						break;
					}
				}
			}
		}

		public function LabDevice() {
			super();
		}
		
		/*
		public override function readExternal(input:IDataInput):void {
			super.readExternal(input);
			if(rolls){
				rollsOnline = new ListCollectionView(rolls);
				rollsOnline.filterFunction = filterOnlineRolls;
				rollsOnline.refresh();
			} else {
				rollsOnline = null;
			}
		}
		private static function filterOnlineRolls(item:LabRoll):Boolean {
			return item.is_online;
		}
		*/
		
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
		
		public function resetOnlineRolls():void{
			if(rolls){
				var roll:LabRoll;
				for each(roll in rolls) roll.is_online=false;
			}
			_rollsOnline=[];
		}
		
		/**
		 * deprecated
		 */
		private function hasOnlineRolls():Boolean{
			if(!rolls) return false;
			var roll:LabRoll;
			for each(roll in rolls){
				if(roll.is_online) return true;
			}
			return false;
		}
		
		/**
		 * deprecated
		 */
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
		
		/**
		 * возвращает актуальное расписание относительно определенной даты
		 */
		public function getCurrentTimeTableByDate(date:Date):LabTimetable {
			
			var tt:LabTimetable = ArrayUtil.searchItem('day_id',date.day, timetable.toArray()) as LabTimetable;
			if(tt && tt.is_online){
				tt = tt.createCurrent(date);
			} else {
				tt = null;
			}
			return tt;
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
		
		public static function findDeviceByTechPointId(deviceList:Array, techPointId:int):LabDevice {
			
			return ArrayUtil.searchItem('tech_point', techPointId, deviceList) as LabDevice;
			
		}

		public function toString():String {
			var res:String=this.name;
			if(!res) res='id'+this.id;
			if(this.compatiableQueue) res=res+'(cq'+this.compatiableQueue.length+')';
			return res;
		}

    }
}