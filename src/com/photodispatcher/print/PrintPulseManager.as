package com.photodispatcher.print
{
	import com.photodispatcher.model.mysql.DbLatch;
	import com.photodispatcher.model.mysql.entities.LabDevice;
	import com.photodispatcher.model.mysql.entities.LabStopLog;
	import com.photodispatcher.model.mysql.entities.LabTimetable;
	import com.photodispatcher.model.mysql.entities.SourceType;
	import com.photodispatcher.model.mysql.entities.TechLog;
	import com.photodispatcher.model.mysql.services.LabService;
	import com.photodispatcher.model.mysql.services.TechService;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.TimerEvent;
	import flash.utils.Timer;
	
	import mx.collections.IList;
	
	import org.granite.tide.Tide;
	
	public class PrintPulseManager extends EventDispatcher
	{
		
		protected var _labs:IList;

		public function get labs():IList
		{
			return _labs;
		}

		public function set labs(value:IList):void
		{
			_labs = value;
			if(_labs && _labs.length > 0 && waitForLabConfig){
				init();
			}
		}
		
		protected var _devices:IList;

		public function get devices():IList
		{
			return _devices;
		}

		public function set devices(value:IList):void
		{
			_devices = value;
		}
		
		public var currentLab:LabGeneric;
		
		public var techPointType:int = SourceType.TECH_PRINT;
		
		/**
		 * Время в мин, в течение которого проверяется активность лабы
		*/
		public var timeGap:int = 2;
		
		/**
		 * Интервал проверки пульса в мс.
		 */
		public var timerDelay:Number = 1000*10;
		
		protected var lastUpdatedTechPoints:Array;
		protected var labStops:Array;
		protected var nowDate:Date;
		protected var fromDate:Date;
		
		protected var timer:Timer;
		protected var waitForLabConfig:Boolean;
		
		public function PrintPulseManager()
		{
			super();
		}
		
		public function init():void {
			
			if((!labs || labs.length == 0) && !waitForLabConfig){
				waitForLabConfig = true;
				return;
			} else if(waitForLabConfig){
				waitForLabConfig = false;
			}
			
			loadPulse();
			startTimer();
		}
		
		protected function startTimer():void {
			
			stopTimer();
			
			if(timerDelay == 0){
				return;
			}
			
			timer = new Timer(timerDelay, 1);
			timer.addEventListener(TimerEvent.TIMER_COMPLETE, timerCompleteHandler);
			timer.start();
			
		}
		
		protected function timerCompleteHandler(event:TimerEvent):void
		{
			
			loadPulse();
			
		}
		
		protected function stopTimer():void {
			
			if(timer){	
				timer.stop();
				timer.removeEventListener(TimerEvent.TIMER_COMPLETE, timerCompleteHandler);
				timer = null;
			}
			
		}
		
		protected function loadPulse():void {
			
			
			if(!labs || labs.length == 0){
				lastUpdatedTechPoints = null;
				labStops = null;
				return;
			}
			
			//nowDate = new Date(2015, 0, 14, 14); // 14:00 14-01-2014 (14 янв);
			nowDate = new Date;
			loadTechPulse();
			loadLabStops();
			
		}
		
		protected function loadTechPulse():void {
			
			lastUpdatedTechPoints = null;
			
			var svc:TechService = Tide.getInstance().getContext().byType(TechService,true) as TechService;
			var latch:DbLatch=new DbLatch();
			latch.addEventListener(Event.COMPLETE,onLoadTechPulse);
			latch.addLatch(svc.loadTechPulse(techPointType));
			latch.start();
			
		}
		
		
		protected function onLoadTechPulse(event:Event):void
		{
			
			var latch:DbLatch= event.target as DbLatch;
			if(latch){
				latch.removeEventListener(Event.COMPLETE,onLoadTechPulse);
				if(!latch.complite) return;
				lastUpdatedTechPoints = latch.lastDataArr;
				checkPulse();
			}
			
		}
		
		protected function loadLabStops():void {
			
			labStops = null;
			
			var to:Date = nowDate;
			var from:Date = fromDate = new Date(to.getTime()-timeGap*60*1000); // на timeGap минут раньше
			
			var svc:LabService = Tide.getInstance().getContext().byType(LabService,true) as LabService;
			var latch:DbLatch=new DbLatch();
			latch.addEventListener(Event.COMPLETE,onLoadLabStops);
			latch.addLatch(svc.getLabStops(from,to));
			latch.start();
			
		}
		
		protected function onLoadLabStops(event:Event):void
		{
			
			var latch:DbLatch= event.target as DbLatch;
			if(latch){
				latch.removeEventListener(Event.COMPLETE,onLoadLabStops);
				if(!latch.complite) return;
				labStops = latch.lastDataArr;
				checkPulse();
			}
			
		}
		
		protected function checkPulse():void {
			
			
			if(lastUpdatedTechPoints == null || labStops == null){
				
				return;
				
			}
			
			/* 
			промежутки времени простоя теоретически могут накладываться 
			или их может быть несколько для одного устройства, поэтому нужно определить 
			самый последний для каждого устройства и составить карту
			*/
			var stopMap:Object = {};
			
			for each (var ls:LabStopLog in labStops){
				
				stopMap[ls.lab_device] = LabStopLog.getLast(stopMap[ls.lab_device], ls);
				
			}
			
			var dev:LabDevice;
			var lastStop:LabStopLog;
			var tt:LabTimetable;
			for each (var tl:TechLog in lastUpdatedTechPoints){
				
				dev = LabDevice.findDeviceByTechPointId(devices.toArray(), tl.src_id);
				if(dev){
					
					dev.lastPrintDate = new Date(tl.log_date.time);
					
					lastStop = stopMap[dev.id];
					
					if(dev.lastPrintDate.time < fromDate.time){
						// если последняя печать была до проверочного интервала, значит простой, 
						// необходимо определить был ли этот простой уже зафиксирован
						
						if(lastStop == null){
							
							// если простой не зафиксирован, необходимо проверить расписание на сегодня
							tt = dev.getCurrentTimeTableByDate(fromDate);
							if(tt){
								//проверяем интервал проверки на вхождение в расписание
								if(fromDate.time > tt.time_from.time && nowDate.time < tt.time_to.time){
									
									/* 
									если интервал проверки входит в расписание, значит необходимо зафиксировать простой
									простой нужно фиксировать относительно расписания, 
									если дата последней печати не входит в рабочий интервал по расписанию, значит простой фиксируется от начальной даты расписания
									иначе простой фиксируется от даты последней печати
									*/
									
									if(dev.lastPrintDate.time < tt.time_from.time){
										dev.lastStopLog = openLabStop(dev.id, new Date(tt.time_from.time));
									} else {
										dev.lastStopLog = openLabStop(dev.id, new Date(dev.lastPrintDate.time));
									}
									
									
								}
								
								
								
							}
							
						} else {
							
							dev.lastStopLog = lastStop;
							
						}
						
					} else {
						
						// если последняя печать была в течение проверочного интервала, значит устройство работает
						
						if(lastStop && lastStop.time_to == null){
							// если был открыт простой, значит нужно его закрыть
							
							closeLabStop(lastStop, new Date(dev.lastPrintDate.time));
							dev.lastStopLog = lastStop;
							
						}
						
					}
					
				}
				
			}
			
			if(timer){
				timer.start();
			}
			
		}
		
		/**
		 * открываем простой
		 */
		public function openLabStop(deviceId:int, timeFrom:Date, type:int = 0, comment:String = "auto"):LabStopLog {
			
			var stop:LabStopLog = new LabStopLog();
			stop.lab_device = deviceId;
			stop.lab_stop_type = type;
			stop.log_comment = comment;
			stop.time_from = timeFrom;
			
			var svc:LabService = Tide.getInstance().getContext().byType(LabService,true) as LabService;
			var latch:DbLatch=new DbLatch();
			latch.addEventListener(Event.COMPLETE,onLogLabStop);
			latch.addLatch(svc.logLabStop(stop));
			latch.start();
			
			return stop;
		}
		
		protected function onLogLabStop(event:Event):void
		{
			var latch:DbLatch= event.target as DbLatch;
			if(latch){
				latch.removeEventListener(Event.COMPLETE,onLogLabStop);
			}
		}
		
		
		/**
		 * закрываем простой
		 */
		public function closeLabStop(stop:LabStopLog, timeTo:Date = null):void {
			
			
			stop.time_to = timeTo;
			
			var svc:LabService = Tide.getInstance().getContext().byType(LabService,true) as LabService;
			var latch:DbLatch=new DbLatch();
			latch.addEventListener(Event.COMPLETE,onUpdateLabStop);
			latch.addLatch(svc.updateLabStop(stop));
			latch.start();
			
		}
		
		protected function onUpdateLabStop(event:Event):void
		{
			var latch:DbLatch= event.target as DbLatch;
			if(latch){
				latch.removeEventListener(Event.COMPLETE,onLogLabStop);
			}
		}
		
		
	}
}