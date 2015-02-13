package com.photodispatcher.print
{
	import com.akmeful.util.ArrayUtil;
	import com.photodispatcher.context.Context;
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
	import mx.collections.ArrayList;
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
		public var timerDelay:Number = 10*1000;//mem leac? 1000*10;
		
		[Bindable]
		public var autoPrinting:Boolean = false;
		
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
			
			return; //bug in checkPulse
			
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
				//latch.clearResult();
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
				//latch.clearResult();
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
				latch.removeEventListener(Event.COMPLETE,onLoadPrintQueue);
				if(!latch.complite) return;
				printQueue = latch.lastDataArr;
				//latch.clearResult();
				checkPulse();
			}
			
		}
		
		protected function checkPulse():void {
			
			
			if(lastUpdatedTechPoints == null || labStops == null || printQueue == null){
				
				return;
				
			}
			
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
					
				} else {
					
					// TODO обработать ситуацию, когда ГП послана в лабу, в которой нет подходящих девайсов
					
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
			
			if(!autoPrinting){
				
				getPulse();
				return;
				
			} 
			
			var readyDevices:Array = getReadyDevices();
			
			if(readyDevices.length > 0){
				
				loadReadyForPrintingPgList(addToQueueAfterPgList);
				
			} else {
				// нет свободных устройств
				finishPulse();
			}
			
		}
		
		protected function addToQueueAfterPgList(printGroups:Array, loadByDevices:Boolean = false):void {
			
			var readyDevices:Array = getReadyDevices();
			
			if(readyDevices.length > 0 && printGroups.length > 0){
				
				addToQueue(printGroups, readyDevices, loadByDevices);
				
			} else if(readyDevices.length > 0 && !loadByDevices){
				
				// нужно сделать запрос на дополнительные ГП
				loadReadyForPrintingByDevices(getDeviceIds(readyDevices), addToQueueAfterPgList);
				
			} else {
				
				// нет свободных устройств
				finishPulse();
			}
			
		}
		
		protected function getDeviceIds(devices:Array):Array {
			
			return devices.map(function (dev:LabDevice, index:int, array:Array):int { return dev.id });
			
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
				if(devIsReady && checkDevicePrintQueueReady(dev.printQueue)){
					
					readyDevices.push(dev);
					
				}
				
			}
			
			return readyDevices;
			
		}
		
		protected function addToQueue(printGroups:Array, devices:Array, loadByDevices:Boolean):void {
			
			if(printGroups.length == 0 || devices.length == 0){
				
				return;
				
			}
			
			var devList:Array = devices.slice();
			var pg:PrintGroup;
			var lab:LabGeneric;
			var dev:LabDevice;
			var found:Boolean;
			
			var readyPgList:Array = [];
			var i:int;
			
			/* 
			копируем очереди девайсов, они нужны нам для равномерного распределения ГП по девайсам, 
			а оригинальные очереди необходимо заполнить только после выставления статуса в базе
			*/
			var devPrintQueueMap:Object = {};
			for each (dev in devList){
				
				devPrintQueueMap[dev.id] = new ArrayList(dev.printQueue.toArray());
				
			}
			
			
			for each (pg in printGroups){
				
				i = 0;
				found = false;
				
				while (i < devList.length && !found) {
					
					dev = devList[i] as LabDevice;
					lab = labMap[dev.lab] as LabGeneric;
					
					if(lab.printChannel(pg, dev.rollsOnline.toArray()) && checkDevicePrintQueueReady(devPrintQueueMap[dev.id])){
						
						pg.destination = lab.id;
						(devPrintQueueMap[dev.id] as IList).addItem(pg);
						readyPgList.push(pg);
						
						// подходящие девайс найден, выходим из цикла
						found = true;
						
						if(i < devList.length - 1){
							/* 
							вращаем девайсы так, чтобы найденный девайс оказался в конце списка для следующей ГП 
							так исключим ситуацию, когда первый в списке девайс будет ловить все подходящие ГП
							*/
							devList = ArrayUtil.rotateArray(i, devList);
						}
						
					}
					
					i++;
				}
				
			}
			
			
			if(!loadByDevices){
				// добавляем в очередь после загрузки общего списка
				updatePgStatus(readyPgList, onUpdatePgStatusAfterPgList);
				
			} else {
				// добавляем в очередь после загрузки списка по девайсам
				updatePgStatus(readyPgList, onUpdatePgStatusAfterByDevices);
				
			}
			
			
		}
		
		/**
		 * вызываем для того, чтобы заполнить очередь девайсов добавленными ГП
		 */
		protected function addToDeviceQueueAfterStatus(printGroups:Array):void {
			
			var compDevices:Array;
			var devForPg:LabDevice;
			var dev:LabDevice;
			
			for each (var pgQueued:PrintGroup in printGroups){
				
				if(pgQueued.state != OrderState.PRN_QUEUE){
					// добавляем только те ГП у которых определен необходимый статус 203
					continue;
				}
				
				compDevices = (labMap[pgQueued.destination] as LabGeneric).getCompatiableDevices(pgQueued);
				
				if(compDevices.length > 0){
					
					devForPg = compDevices[0]['dev'] as LabDevice; // определяем по умолчанию первый доступный
					
					for each (dev in compDevices) {
						
						// определяем девайс с самой короткой очередью
						if(devForPg != dev['dev'] && devForPg.printQueue.length > (dev['dev'] as LabDevice).printQueue.length){
							devForPg = dev['dev'] as LabDevice;
						}
						
					}
					
					// добавляем ГП в девайс с самой короткой очередью
					devForPg.printQueue.addItem(pgQueued);
					
				} else {
					
					// TODO обработать ситуацию, когда ГП послана в лабу, в которой нет подходящих девайсов
					
				}
				
			}
			
			
		}
		
		protected function updateLabQueue():void {
			
			var dev:LabDevice;
			var pg:PrintGroup;
			var lab:LabGeneric;
			
			for each (dev in devices){
				
				for each (pg in dev.printQueue) {
					
					if(pg.state == OrderState.PRN_QUEUE){
						
						// нужно добавить ГП в лабу, но перед этим проверить наличие этой ГП в соответствующей лабе
						lab = labMap[pg.destination] as LabGeneric;
						
						if(!lab.checkPrintGroupInLab(pg)){
							lab.post(pg, Context.getAttribute('reversPrint'));
						}
						
						
					}
					
				}
				
			}
			
			
		}
		
		
		/**
		 * обрабатываем запрос к серверу на добавление ГП в очередь из ОБЩЕГО СПИСКА
		 */
		protected function onUpdatePgStatusAfterPgList(printGroups:Array):void {
			
			addToDeviceQueueAfterStatus(printGroups);
			
			// если статусы установлены после общего списка, необходимо проверить девайсы и дозаполнить запросом по девайсам
			addToQueueAfterPgList([]);
			
		}
		
		/**
		 * обрабатываем запрос к серверу на добавление ГП в очередь из СПИСКА ПО ДЕВАЙСАМ
		 */
		protected function onUpdatePgStatusAfterByDevices(printGroups:Array):void {
			
			addToDeviceQueueAfterStatus(printGroups);
			
			// если статусы установлены после запроса по девайсам, больше запрашивать нет смысла, заканчиваем пульс
			finishPulse();
			
		}
		
		
		protected function finishPulse():void {
			
			updateLabQueue();
			getPulse();
			
		}
		
		/**
		 * определяет, можно ли загрузить в девайс еще ГП
		 */
		protected function checkDevicePrintQueueReady(printQueue:IList):Boolean {
			
			return printQueue.length < 2;
			
		}
		
		protected var loadReadyForPrintingPgListHandler:Function;
		
		protected function loadReadyForPrintingPgList(handler:Function):void {
			
			loadReadyForPrintingPgListHandler = handler;
			
			var svc:PrintGroupService=Tide.getInstance().getContext().byType(PrintGroupService,true) as PrintGroupService;
			var latch:DbLatch=new DbLatch();
			latch.addEventListener(Event.COMPLETE, onLoadReadyForPrintingPgList);
			
			// получаем список в статусе 200, готовые к печати
			latch.addLatch(svc.loadByState(OrderState.PRN_WAITE,OrderState.PRN_QUEUE));
			latch.start();
			
		}
		
		private function onLoadReadyForPrintingPgList(evt:Event):void{
			var latch:DbLatch= evt.target as DbLatch;
			if(latch){
				latch.removeEventListener(Event.COMPLETE, onLoadReadyForPrintingPgList);
				if(!latch.complite) return;
				if(loadReadyForPrintingPgListHandler != null) loadReadyForPrintingPgListHandler.apply(this, [latch.lastDataArr]);
			}
			
			loadReadyForPrintingPgListHandler = null;
			
		}
		
		protected var loadReadyForPrintingByDevicesHandler:Function;
		
		protected function loadReadyForPrintingByDevices(deviceIds:Array, handler:Function):void
		{
			
			loadReadyForPrintingByDevicesHandler = handler;
			
			var svc:PrintGroupService=Tide.getInstance().getContext().byType(PrintGroupService,true) as PrintGroupService;
			var latch:DbLatch=new DbLatch();
			latch.addEventListener(Event.COMPLETE, onLoadReadyForPrintingByDevices);
			latch.addLatch(svc.loadPrintPostByDev(new ArrayCollection(deviceIds), 0));
			latch.start();
			
		}
		
		private function onLoadReadyForPrintingByDevices(evt:Event):void{
			var latch:DbLatch= evt.target as DbLatch;
			if(latch){
				latch.removeEventListener(Event.COMPLETE, onLoadReadyForPrintingByDevices);
				if(!latch.complite) return;
				if(loadReadyForPrintingByDevicesHandler != null) loadReadyForPrintingByDevicesHandler.apply(this, [latch.lastDataArr, true]);
			}
			
			loadReadyForPrintingByDevicesHandler = null;
			
		}
		
		protected var updatePgStatusHandler:Function;
		protected function updatePgStatus(printGroups:Array, handler:Function):void {
			
			updatePgStatusHandler = handler;
			
			// если список пуст, запрос не делаем, вызываем обработчик
			if(printGroups.length == 0){
				
				if(updatePgStatusHandler != null) updatePgStatusHandler.apply(this, []);
				return;
				
			}
			
			
			// шлем запрос на установку 203 статуса, после чего ГП считается захваченной определенной лабой
			var svc:PrintGroupService=Tide.getInstance().getContext().byType(PrintGroupService,true) as PrintGroupService;
			var latch:DbLatch= new DbLatch(true);
			latch.addEventListener(Event.COMPLETE,onUpdatePgStatus);
			latch.addLatch(svc.capturePrintState(new ArrayCollection([printGroups]),false));
			latch.start();
			
		}
		
		private function onUpdatePgStatus(evt:Event):void
		{
			
			var latch:DbLatch= evt.target as DbLatch;
			if(latch){
				
				latch.removeEventListener(Event.COMPLETE, onLoadReadyForPrintingByDevices);
				
				if(!latch.complite) {
					if(updatePgStatusHandler != null) updatePgStatusHandler.apply(this, []);
					return;
				}
				
				if(updatePgStatusHandler != null) updatePgStatusHandler.apply(this, [latch.lastDataArr]);
				
			}
			
		}
		
		
		
	}
}
