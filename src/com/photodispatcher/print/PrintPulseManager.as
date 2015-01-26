package com.photodispatcher.print
{
	import com.google.zxing.common.flexdatatypes.ArrayList;
	import com.photodispatcher.model.mysql.DbLatch;
	import com.photodispatcher.model.mysql.entities.LabDevice;
	import com.photodispatcher.model.mysql.entities.LabStopLog;
	import com.photodispatcher.model.mysql.entities.LabStopType;
	import com.photodispatcher.model.mysql.entities.LabTimetable;
	import com.photodispatcher.model.mysql.entities.OrderState;
	import com.photodispatcher.model.mysql.entities.PrintGroup;
	import com.photodispatcher.model.mysql.entities.SourceType;
	import com.photodispatcher.model.mysql.entities.TechLog;
	import com.photodispatcher.model.mysql.services.LabService;
	import com.photodispatcher.model.mysql.services.PrintGroupService;
	import com.photodispatcher.model.mysql.services.TechService;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.TimerEvent;
	import flash.utils.Timer;
	
	import mx.collections.ArrayCollection;
	import mx.collections.IList;
	import mx.collections.IViewCursor;
	
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
		
		public var printQueueManager:PrintQueueManager;
		
		protected var lastUpdatedTechPoints:Array;
		protected var labStops:Array;
		protected var printQueue:Array;
		protected var nowDate:Date;
		protected var fromDate:Date;
		protected var labMap:Object;
		
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
		
		protected function getPulse():void {
			
			if(timer){
				timer.start();
			}
			
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
			loadPrintQueue();
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
		
		protected function loadPrintQueue():void {
			
			printQueue = null;
			
			// тут нужно послать запрос на загрузку очереди ГП, определяется по набору статусов
			var svc:PrintGroupService=Tide.getInstance().getContext().byType(PrintGroupService,true) as PrintGroupService;
			var latch:DbLatch= new DbLatch();
			latch.addEventListener(Event.COMPLETE,onLoadPrintQueue);
			latch.addLatch(svc.loadInPrint(0));
			latch.start();
			
		}
		
		protected function onLoadPrintQueue(event:Event):void
		{
			
			var latch:DbLatch= event.target as DbLatch;
			if(latch){
				latch.removeEventListener(Event.COMPLETE,onLoadLabStops);
				if(!latch.complite) return;
				printQueue = latch.lastDataArr;
				checkPulse();
			}
			
		}
		
		protected function checkPulse():void {
			
			
			if(lastUpdatedTechPoints == null || labStops == null || printQueue == null){
				
				return;
				
			}
			
			// TODO исключить ситуацию, когда пульс обрабатывается одновременно с предыдущей постановкой на печать
			
			/*
			нужно составить карту лаб по id
			*/
			
			var labIdToLabGenericMap:Object = {};
			var lab:LabGeneric;
			
			for each (lab in labs){
				
				labIdToLabGenericMap[lab.id] = lab;
				
			}
			
			labMap = labIdToLabGenericMap;
			
			var dev:LabDevice;
			/*
			нужно инициализировать очередь для каждого девайса
			*/
			
			for each (dev in devices){
				
				dev.printQueue = new ArrayList;
				
			}
			
			/*
			нужно пробежаться по совокупной очереди ГП и разделить очередь по девайсам + составить карту лаба - девайс - подходящщая ГП
			*/
			
			var compMap:Object = {}; //лаба - девайс - подходящщая ГП
			var queueMap:Object = {}; // лаба - очередь ГП
			var compDevices:Array;
			
			var devForPg:LabDevice;
			
			for each (var pgQueued:PrintGroup in printQueue){
				
				if(compMap[pgQueued.destination] == null){
					compMap[pgQueued.destination] = {};
				}
				
				if(queueMap[pgQueued.destination] == null){
					queueMap[pgQueued.destination] = [];
				}
				
				compDevices = (labIdToLabGenericMap[pgQueued.destination] as LabGeneric).getCompatiableDevices(pgQueued);
				
				if(compDevices.length > 0){
					
					devForPg = compDevices[0]['dev'] as LabDevice; // определяем по умолчанию первый доступный
					
					// составляем карту
					for each (dev in compDevices) {
						
						if(compMap[pgQueued.destination][dev['dev'].id] == null){
							compMap[pgQueued.destination][dev['dev'].id] = [];
						}
						
						(compMap[pgQueued.destination][dev['dev'].id] as Array).push(pgQueued);
						
						(queueMap[pgQueued.destination] as Array).push(pgQueued);
						
						// определяем девайс с самой короткой очередью
						if(devForPg != dev['dev'] && devForPg.printQueue.length > (dev['dev'] as LabDevice).printQueue.length){
							devForPg = dev['dev'] as LabDevice;
						}
						
					}
					
					// добавляем ГП в девайс с самой короткой очередью
					devForPg.printQueue.addItem(pgQueued);
					
				}
				
			}
			
			/*
			
			TODO проверить, все ли ГП были распределены по девайсам, если не все, то необходимо отменить печать ГП из-за того, что нет подходящих девайсов (рулонов)
			
			*/
			
			/* 
			промежутки времени простоя теоретически могут накладываться 
			или их может быть несколько для одного устройства, поэтому нужно определить 
			самый последний для каждого устройства и составить карту
			*/
			var stopMap:Object = {};
			
			for each (var ls:LabStopLog in labStops){
				
				stopMap[ls.lab_device] = LabStopLog.getLast(stopMap[ls.lab_device], ls);
				
			}
			
			
			var lastStop:LabStopLog;
			var tt:LabTimetable;
			var checkDate:Date;
			var labQueue:Array;
			var labHasQueue:Boolean;
			var delta:Number;
			var printReadyPg:PrintGroup;
			var stopType:int = LabStopType.OTHER;
			
			for each (var tl:TechLog in lastUpdatedTechPoints){
				
				dev = LabDevice.findDeviceByTechPointId(devices.toArray(), tl.src_id);
				if(dev){
					
					lab = labIdToLabGenericMap[dev.lab] as LabGeneric;
					
					dev.lastPrintDate = new Date(tl.log_date.time);
					
					lastStop = stopMap[dev.id];
					
					checkDate = dev.lastPrintDate;
					delta = 0;
					
					// TODO внести коррекцию используя время постановки на печать, используя карту: лаба - очередь ГП
					labQueue = queueMap[dev.lab] as Array;
					labHasQueue = labQueue && labQueue.length > 0;
					
					if(labHasQueue){
						/* 
						если в лабе есть очередь, то нужно определить время постановки на печать самой первой ГП из очереди
						потом сравниваем это время со временем последней печати, 
						если постановка в очередь была позже печати, значит дальше нужно проверочный интервал сравнивать с временем постановки в печать прибавив рассчетное время печати,
						*/
						
						printReadyPg = getFirstPrintReadyPG(labQueue);
						
						if(printReadyPg && (printReadyPg.state_date.time > dev.lastPrintDate.time)){
							checkDate = printReadyPg.state_date;
							// определяем рассчетное время подготовки для печати первой добавленной в очередь ГП, используем soft_speed лабы
							delta = (printReadyPg.prints/lab.soft_speed)*60*1000; // скорость в файл/мин, переводим в мс
						}
						
					} else {
						
						// если будет фиксироваться простой, значит нет подходящих ГП
						stopType = LabStopType.NO_ORDER;
						
					}
					
					
					if((checkDate.time + delta) < fromDate.time){
						// если рассчетное время (последняя печать, постановка на печать) было до проверочного интервала, значит простой, 
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
									
									/*
									тут можно определить тип простоя
									если в очереди есть ГП и они все в статусе копирования, то это может означать проблемы с постановкой на печать (сеть упала)
									если в очереди есть ГП и они поставлены на печать, то у нас замена рулона или не работает оператор
									если в очереди нет ГП - то это отсутствие заказов
									*/
									
									if((checkDate.time + delta) < tt.time_from.time){
										dev.lastStopLog = openLabStop(dev.id, new Date(tt.time_from.time), stopType);
									} else {
										dev.lastStopLog = openLabStop(dev.id, new Date(checkDate.time + delta), stopType);
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
			
			updatePrintQueue();
			
		}
		
		/**
		 * вычисляет время постановки на печать самой первой ГП из очереди
		 */
		protected function getFirstPrintReadyPG(queue:Array, printState: int = -1):PrintGroup {
			
			var fpg:PrintGroup;
			for each (var pg:PrintGroup in queue){
				
				if(printState > -1 && pg.state != printState){
					// нужно пропустить ГП, если статус другой
					continue;
				}
				
				if(fpg == null || (fpg && (pg.state_date.time < fpg.state_date.time))){
					
					fpg = pg;
					
				}
				
			}
			
			return fpg;
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
		
		
		/**
		 * функция автоматической постановки на печать
		 */
		protected function updatePrintQueue():void 
		{
			
			/* 
			нужно пробежаться по всем лабам/девайсам и посмотреть зафиксирован ли простой, дальше нужно проверить расписание девайса, 
			если девайс/лаба активен, то нужно посмотреть размер очереди для конкретного девайса и определить можно ли ему добавлять ГП в очередь
			
			Если есть свободные девайсы, получаем список подготовленных для печати групп, какое-то фиксированное количество, 
			дальше бежим по списку пытаясь добавить ГП в очередь по каждому девайсу и контролируем размер очереди,
			
			Если девайс не загружен, то нужно сделать выборку групп печати для незагруженных девайсов, эту выборку мы сохраняем и добавляем в список, 
			который приходит со следующим основным запросом  
			так мы пытаемся гарантировать постоянную загруженность
			
			*/
			
			getPulse();
			return;
			
			var readyDevices:Array = getReadyDevices();
			
			if(readyDevices.length > 0){
				
				loadReadyForPrintingPgList(addToQueueAfterPgList);
				
			}
			
		}
		
		protected function addToQueueAfterPgList(printGroups:Array):void {
			
			var readyDevices:Array = getReadyDevices();
			
			if(readyDevices.length > 0){
				
				addToQueue(printGroups, readyDevices);
				
			}
			
		}
		
		protected function getReadyDevices():Array {
			
			var now:Date = new Date
			var readyDevices:Array = [];
			var tt:LabTimetable;
			var lab:LabGeneric;
			var devIsReady:Boolean;
			
			for each (var dev:LabDevice in devices.toArray()){
				
				lab = (labMap[dev.lab] as LabGeneric);
				
				if(!lab.is_managed){
					// пропускает девайсы лаб, на которых идет ручная постановка в печать
					continue;
				}
				
				devIsReady = false;
				
				// проверяем лог простоя
				if(dev.lastStopLog == null || (dev.lastStopLog && dev.lastStopLog.time_to && dev.lastStopLog.time_to.time < now.time)){
					// если простоя нет или он уже закончился
					tt = dev.getCurrentTimeTableByDate(now);
					
					if(tt && now.time>=tt.time_from.time && now.time<=tt.time_to.time){
						// если девайс работает по расписанию
						devIsReady = true;
						
					} else if(tt && (tt.time_from.time - now.time) <= 5000*60){
						// если девайс начнет работать по расписанию меньше чем через 5 мин.
						devIsReady = true;
						
					}
					
				}
				
				// проверяем очередь
				if(devIsReady && checkDevicePrintQueueReady(dev)){
					
					readyDevices.push(dev);
					
				}
				
			}
			
		}
		
		protected function addToQueue(printGroups:Array, devices:Array):void {
			
			if(printGroups.length == 0 || devices.length == 0){
				
				return;
				
			}
			
			var devList:ArrayCollection = new ArrayCollection(devices);
			var devCursor:IViewCursor = devList.createCursor();
			var pg:PrintGroup;
			var lab:LabGeneric;
			var dev:LabDevice;
			
			for each (pg in printGroups){
				
				dev = devCursor.current as LabDevice;
				lab = labMap[dev.id] as LabGeneric;
				
				if(lab.printChannel(pg, dev.rollsOnline.toArray())){
					
					
					
				}
				
			}
			
			
		}
		
		/**
		 * определяет, можно ли загрузить в девайс еще ГП
		 */
		protected function checkDevicePrintQueueReady(dev:LabDevice):Boolean {
			
			return dev.printQueue.length < 2;
			
		}
		
		protected var loadReadyForPrintingPgListHandler:Function;
		
		protected function loadReadyForPrintingPgList(handler:Function):void {
			
			loadReadyForPrintingPgListHandler = handler;
			
			var svc:PrintGroupService=Tide.getInstance().getContext().byType(PrintGroupService,true) as PrintGroupService;
			var latch:DbLatch=new DbLatch();
			latch.addEventListener(Event.COMPLETE, onLoadReadyForPrintingPgList);
			latch.addLatch(svc.loadByState(OrderState.PRN_WAITE,OrderState.PRN_PRINT));
			latch.start();
			
		}
		
		private function onLoadReadyForPrintingPgList(evt:Event):void{
			var latch:DbLatch= evt.target as DbLatch;
			if(latch){
				latch.removeEventListener(Event.COMPLETE,onLoadReadyForPrintingPgList);
				if(!latch.complite) return;
				if(loadReadyForPrintingPgListHandler) loadReadyForPrintingPgListHandler.apply(this, [latch.lastDataArr]);
			}
		}
		
		
	}
}