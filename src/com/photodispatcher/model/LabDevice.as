package com.photodispatcher.model{
	import com.photodispatcher.model.dao.LabRollDAO;
	import com.photodispatcher.model.dao.LabTimetableDAO;

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

		//db childs
		private var _rolls:Array;
		private var _timetable:Array;

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


		public function get rolls():Array{
			return _rolls;
		}
		public function set rolls(value:Array):void{
			_rolls = value;
		}
		public function getRolls(forEdit:Boolean=false):Array{
			if(!loaded) return _rolls;
			var dao:LabRollDAO=new LabRollDAO();
			_rolls=dao.getByDevice(id,forEdit,!forEdit);
			return _rolls;
		}

	}
}