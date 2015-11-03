package com.photodispatcher.print{
	
	import com.photodispatcher.context.Context;
	import com.photodispatcher.model.mysql.DbLatch;
	import com.photodispatcher.model.mysql.entities.BookSynonym;
	import com.photodispatcher.model.mysql.entities.LabDevice;
	import com.photodispatcher.model.mysql.entities.LabMeter;
	import com.photodispatcher.model.mysql.entities.LabRoll;
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
	import com.photodispatcher.printer.Printer;
	import com.photodispatcher.util.ArrayUtil;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.TimerEvent;
	import flash.utils.Timer;
	
	import mx.collections.ArrayCollection;
	import mx.collections.ArrayList;
	import mx.collections.IList;
	
	import org.granite.tide.Tide;
	
	public class PrintPulseManager extends EventDispatcher{
		/* скорость печати
		SELECT lml.lab, lml.lab_device, SUM(TIMESTAMPDIFF(SECOND, lml.start_time, lml.end_time)) ttime, SUM(lml.amt) amt, SUM(lml.amt - 1) * 60 / SUM(TIMESTAMPDIFF(SECOND, lml.start_time, lml.end_time))
		FROM lab_meter_log lml
		WHERE lml.state = 255
		AND lml.amt > 1
		AND lml.end_time IS NOT NULL
		GROUP BY lml.lab, lml.lab_device
		*/
		/* скорость постановки
		SELECT lml.lab, SUM(TIMESTAMPDIFF(SECOND, lml.start_time, lml.end_time)) ttime, SUM(pg.prints) amt, SUM(pg.prints) * 60 / SUM(TIMESTAMPDIFF(SECOND, lml.start_time, lml.end_time))
		FROM lab_meter_log lml
		INNER JOIN print_group pg ON lml.print_group = pg.id
		WHERE lml.state > 203
		AND lml.state < 250
		AND lml.end_time IS NOT NULL
		GROUP BY lml.lab
		*/
		
		protected var _labs:IList;
		public function get labs():IList{
			return _labs;
		}
		public function set labs(value:IList):void{
			_labs = value;
			//карта лаб по id
			labMap={};
			if(_labs){
				for each (var lab:LabGeneric in _labs) labMap[lab.id] = lab;
			}
			if(_labs && _labs.length > 0 && waitForLabConfig) init();
		}
		
		protected var _devices:IList;
		public function get devices():IList{
			return _devices;
		}
		public function set devices(value:IList):void{
			_devices = value;
			deviceMap={};
			if(_devices){
				for each (var item:LabDevice in _devices) deviceMap[item.id] = item;
			}
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
		public var timerDelay:Number = 30*1000;//mem leac? 1000*10;
		
		[Bindable]
		public var autoPrinting:Boolean = false;
		
		[Bindable]
		public var printGroupListLimit:int = 50;
		
		[Bindable]
		/**
		 * Следует ли следить за размером очереди, при false пихает все ГП в лабы не проверяя загрузку
		 */
		public var checkQueue:Boolean;
		
		public var printQueueManager:PrintQueueManager;
		
		private var _labService:LabService;
		protected function get labService():LabService{
			if(!_labService) _labService=Tide.getInstance().getContext().byType(LabService,true) as LabService;
			return _labService;
		}
		private var _printGroupService:PrintGroupService;
		protected function get printGroupService():PrintGroupService{
			if(!_printGroupService) _printGroupService=Tide.getInstance().getContext().byType(PrintGroupService,true) as PrintGroupService;
			return _printGroupService;
		}
		
		//protected var lastUpdatedTechPoints:Array;
		//protected var labStops:Array;
		protected var printQueue:Array;
		protected var pulseStartTime:Date;
		protected var pulseCreateStopTime:Date;
		protected var labMap:Object;
		protected var deviceMap:Object;
		
		protected var timer:Timer;
		protected var waitForLabConfig:Boolean;
		
		[Bindable]
		public var debugStr:String;
		
		protected var _printQueueList:ArrayList;
		
		[Bindable (event="printQueueListChanged")]
		public function get printQueueList():IList {
			return _printQueueList;
		}
		
		protected function printQueueListChanged():void {
			
			_printQueueList = new ArrayList(printQueue);
			dispatchEvent(new Event('printQueueListChanged'));
			
		}
		
		public function PrintPulseManager(){
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
			if(timer) timer.start();
		}
		
		protected function startTimer():void {
			stopTimer();
			if(timerDelay == 0) return;
			timer = new Timer(timerDelay, 1);
			timer.addEventListener(TimerEvent.TIMER_COMPLETE, timerCompleteHandler);
			timer.start();
		}
		
		protected function timerCompleteHandler(event:TimerEvent):void{
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
				//lastUpdatedTechPoints = null;
				//labStops = null;
				return;
			}
			
			//nowDate = new Date(2015, 0, 14, 14); // 14:00 14-01-2014 (14 янв);
			pulseStartTime = new Date;
			pulseCreateStopTime = new Date(pulseStartTime.getTime()-timeGap*60*1000); // на timeGap минут раньше

			debugStr = "";
			
			var latch:DbLatch=loadPrintQueue();
			latch.join(loadLabMeter());
			latch.join(loadLastRolls());
			latch.join(loadOnlineRolls());
			latch.start();
		}
		
		protected function loadLabMeter():DbLatch{
			var latch:DbLatch=new DbLatch();
			latch.addEventListener(Event.COMPLETE,onLoadLabMeter);
			latch.addLatch(labService.loadLabMeters());
			latch.start();
			return latch;
		}
		protected function onLoadLabMeter(event:Event):void{
			var latch:DbLatch= event.target as DbLatch;
			var localTime:Date= new Date();
			if(latch){
				latch.removeEventListener(Event.COMPLETE,onLoadLabMeter);
				if(!latch.complite) return;
				var lastLabMeters:Array=latch.lastDataArr;
				//reset labs
				var lab:LabGeneric;
				for each (lab in labs) lab.resetMeters();
				//update lab meters
				for each (var lm:LabMeter in lastLabMeters){
					lm.toLocalTime(localTime);
					lab=labMap[lm.lab] as LabGeneric;
					if(lab) lab.addMeter(lm);
				}
			}
		}

		protected function loadLastRolls():DbLatch{
			var latch:DbLatch=new DbLatch();
			latch.addEventListener(Event.COMPLETE,onLoadLastRolls);
			latch.addLatch(labService.loadLastRolls());
			latch.start();
			return latch;
		}
		protected function onLoadLastRolls(event:Event):void{
			var latch:DbLatch= event.target as DbLatch;
			var localTime:Date= new Date();
			if(latch){
				latch.removeEventListener(Event.COMPLETE,onLoadLastRolls);
				if(!latch.complite) return;
				for each (var r:LabRoll in latch.lastDataArr){
					if(r){
						var dev:LabDevice=deviceMap[r.lab_device] as LabDevice;
						if(dev) dev.lastRoll=r;
					}
				}
			}
		}

		protected function loadOnlineRolls():DbLatch{
			var latch:DbLatch=new DbLatch();
			latch.addEventListener(Event.COMPLETE,onLoadOnlineRolls);
			latch.addLatch(labService.loadOnlineRolls());
			latch.start();
			return latch;
		}
		protected function onLoadOnlineRolls(event:Event):void{
			var latch:DbLatch= event.target as DbLatch;
			var localTime:Date= new Date();
			if(latch){
				latch.removeEventListener(Event.COMPLETE,onLoadOnlineRolls);
				if(!latch.complite) return;
				var dev:LabDevice;
				//reset online rolls
				for each (dev in devices) dev.resetOnlineRolls();
				//set online rolls
				for each (var r:LabRoll in latch.lastDataArr){
					if(r){
						dev=deviceMap[r.lab_device] as LabDevice;
						if(dev) dev.setRollOnline(r);
					}
				}
				//refresh online rolls
				for each (dev in devices) dev.rollsOnline.refresh();
			}
		}

		protected function loadPrintQueue():DbLatch {
			printQueue = null;
			printQueueListChanged();
			// тут нужно послать запрос на загрузку очереди ГП, определяется по набору статусов
			var latch:DbLatch= new DbLatch();
			latch.addEventListener(Event.COMPLETE,onLoadPrintQueue);
			latch.addLatch(printGroupService.loadInPrintPost(null));
			//latch.start();
			return latch;
		}
		
		protected function onLoadPrintQueue(event:Event):void{
			//TODO refactor process printQueue
			var latch:DbLatch= event.target as DbLatch;
			if(latch){
				latch.removeEventListener(Event.COMPLETE,onLoadPrintQueue);
				if(!latch.complite) return;
				printQueue = latch.lastDataArr;
				checkPulse();
				printQueueListChanged();
			}
			
		}
		
		protected function checkPulse():void {
			//if(lastUpdatedTechPoints == null || labStops == null || printQueue == null) return;
			if(printQueue == null) return;
			
			debugStr += "Очередь на печать: " + getPrintGroupIds(printQueue).join(", ") + "\n";
			var lab:LabGeneric;
			var dev:LabDevice;
			/*
			нужно инициализировать очередь для каждого девайса
			*/
			for each (dev in devices){
				dev.compatiableQueue = [];
				dev.onLineRollQueue = [];
			}
			
			/*
			нужно пробежаться по совокупной очереди ГП и разделить очередь по девайсам + составить карту лаба - девайс - подходящщая ГП
			*/
			var queueMap:Object = {}; // лаба - очередь ГП
			var compDevices:Array;
			var devForPg:LabDevice;
			var devComp:Object;
			var pgQueued:PrintGroup;
			var incompPG:Array=[];
			var hasNoOnlineRollPG:Array=[];
			
			for each (pgQueued in printQueue){
				if(queueMap[pgQueued.destination] == null) queueMap[pgQueued.destination] = [];
				
				lab=labMap[pgQueued.destination] as LabGeneric;
				
				if(!lab) continue;

				pgQueued.lab_name = lab.name;
				// Добавляем в очередь лабы
				(queueMap[pgQueued.destination] as Array).push(pgQueued);

				//попытка раскидать по девайсам с подходящими рулонами
				//для определения типа простоя Нет подходящего заказа (4)
				compDevices = lab.getCompatiableDevices(pgQueued);
				if(compDevices.length > 0){
					devForPg = compDevices[0] as LabDevice; // определяем по умолчанию первый доступный
					// составляем карту
					for each (devComp in compDevices) {
						// определяем девайс с самой короткой очередью
						if(devForPg != devComp && devForPg.compatiableQueue.length > (devComp as LabDevice).compatiableQueue.length){
							devForPg = devComp as LabDevice;
						}
					}
					// добавляем ГП в девайс с самой короткой очередью
					devForPg.compatiableQueue.push(pgQueued);
				}else{
					// TODO обработать ситуацию, когда ГП послана в лабу, в которой нет подходящих девайсов
					//пока тока отображаем в дебуг
					incompPG.push(pgQueued.id);
				}
				
				//попытка раскидать по девайсам по онлайн рулону
				var hasRoll:Boolean=false;
				compDevices = lab.getOnLineRollDevices(pgQueued);
				if(compDevices.length > 0){
					hasRoll=true;
					devForPg = compDevices[0] as LabDevice; // определяем по умолчанию первый доступный
					// составляем карту
					for each (devComp in compDevices) {
						// определяем девайс с самой короткой очередью
						if(devForPg != devComp && devForPg.compatiableQueue.length > (devComp as LabDevice).compatiableQueue.length){
							devForPg = devComp as LabDevice;
						}
					}
					// добавляем ГП в девайс с самой короткой очередью
					devForPg.onLineRollQueue.push(pgQueued);
				}
				// TODO обработать ситуацию когда нет online рулона?
				if(!hasRoll) hasNoOnlineRollPG.push(pgQueued.id);
			}
			
			if(incompPG.length>0) debugStr += "Не совместимы по рулону: " + incompPG.join(", ") + "\n";
			if(hasNoOnlineRollPG.length>0) debugStr += "Не подходит рулон: " + hasNoOnlineRollPG.join(", ") + "\n";
			
			/*
			
			TODO проверить, все ли ГП были распределены по девайсам, если не все, то необходимо отменить печать ГП из-за того, что нет подходящих девайсов (рулонов)
			
			*/

			var tt:LabTimetable;
			//var device:LabDevice;
			var stopType:int = LabStopType.OTHER;
			var lastMeter:LabMeter;
			var postMeter:LabMeter;
			var l:DbLatch;
			
			//генерим стопы 
			//бежим по всем девайсам и проверяем состояние 
			for each (dev in devices){
				if(!dev) continue;
				lab = labMap[dev.lab] as LabGeneric;
				if(!lab) continue;
				//обновляем время последней постановки в печать, для отображения
				postMeter=lab.getPostMeter();
				if(postMeter){
					postMeter=postMeter.clone();
					dev.lastPostDate=postMeter.getLastTime(); 
				}
				//время последней печати
				lastMeter=lab.getPrintMeter(dev.id);
				//обновляем время последней печати, для отображения
				if(lastMeter) dev.lastPrintDate=lastMeter.getLastTime();
				//если не в расписании стопы не фиксим
				tt = dev.getCurrentTimeTableByDate(pulseCreateStopTime);
				if(tt){
					//проверяем интервал проверки на вхождение в расписание
					if(pulseCreateStopTime.time > tt.time_from.time && pulseStartTime.time < tt.time_to.time){
						//должон работать
						//обновляем последний стоп, для отображения
						dev.lastStop=lab.getDeviceStopMeter(dev.id);
						
						if(!lastMeter){
							lastMeter=new LabMeter(); lastMeter.lab=lab.id; lastMeter.lab_device=dev.id;
						}else{
							lastMeter=lastMeter.clone();
						}
						// проверяем был ли пост в лабу, если был и был завершон и еще идет обработка лабой то стоп не фиксим, текущий стоп не меняем - полюбому ждем печати
						// расчитать и учесть время постановки на печать 
						if(postMeter && postMeter.start_time && postMeter.print_group && postMeter.state==OrderState.PRN_PRINT){
							//post meter
							//look 4 printgroup
							pgQueued=ArrayUtil.searchItem('id',lastMeter.print_group,printQueue) as PrintGroup;
							if(pgQueued){
								//если pgQueued не найдена - группа уже как минимум печатается, пост закончен и его учитывать не надо 
								var delta:Number= (pgQueued.prints/lab.soft_speed)*60*1000; // скорость в файл/мин, переводим в мс
								postMeter.start_time= new Date(postMeter.start_time.time+delta);
								if(postMeter.isAfter(pulseCreateStopTime)) continue;
							}
						}
						if(lastMeter.isBefore(pulseCreateStopTime)){
							//стоит ссука
							//detect stop type
							stopType=LabStopType.OTHER;
							//TODO post stop?
							//тут херня надо смотреть был ли пост после печати
							//закончен ли пост (< OrderState.PRN_PRINT)
							// расчитать время поста и если пост уже должен быть закончен то значит застряли на постановке
							//TODO ввести в лабу postSpeed расчитывать по логу labMeter
							if(postMeter && postMeter.isNewer(lastMeter) && postMeter.state < OrderState.PRN_PRINT){
								//OrderState.PRN_PRINT - копирование завершено значит проблема не в постановке 
								//stopType=LabStopType.POST_WAITE;
							}
							//empty queue?
							var labQueue:Array = queueMap[dev.lab] as Array;
							if(!labQueue || labQueue.length == 0){
								stopType=LabStopType.NO_ORDER;
							}else if(dev.compatiableQueue.length==0){
								//гп неподходят по рулонам
								//TODO тут похоже косяк
								//если несколько девайсов будет не корректным, мы наверняка не знаем на какой девайс пойдет печать
								stopType=LabStopType.NO_COMPATIBLE_ORDER;
							}else if(dev.onLineRollQueue.length==0){
								//гп не подходят текущему рулону
								stopType=LabStopType.WRONG_ONLINE_ROLL;
							}
							/*
							тут можно определить тип простоя
							если в очереди есть ГП и они все в статусе копирования, то это может означать проблемы с постановкой на печать (сеть упала)
							если в очереди есть ГП и они поставлены на печать, то у нас замена рулона или не работает оператор
							если в очереди нет ГП - то это отсутствие заказов
							*/

							//fix stop
							var devStop:LabMeter=lab.getDeviceStopMeter(dev.id);
							if(!devStop || devStop.state!=stopType){
								//фиксим по времени lastMeter, если null то по времени стопа пульса, выравниваем на время начала расписания
								if(!lastMeter.getLastTime()) lastMeter.start_time=pulseCreateStopTime;
								if(lastMeter.start_time.time<tt.time_from.time) lastMeter.start_time=tt.time_from;
								lastMeter.meter_type=LabMeter.TYPE_STOP;
								lastMeter.state=stopType;
								//store stop in device
								var lm:LabMeter=lastMeter.clone();
								lab.addMeter(lm);
								dev.lastStop=lm;
								//save
								lastMeter.toServerTime();
								l=new DbLatch();
								l.addLatch(labService.fixStopMeter(lastMeter));
								l.start();
							}
						}
					}else{
						//вне расписания
						dev.lastStop=null;
						//надо закрыть стоп если есть открытый, лаба закончила работу
						var stopMeter:LabMeter=lab.getDeviceStopMeter(dev.id);
						if(stopMeter){
							//выравниваем на конец расписания
							stopMeter.last_time=tt.time_to;
							stopMeter=stopMeter.clone();
							stopMeter.toServerTime();
							//закрываем
							l=new DbLatch();
							l.addLatch(labService.endStopMeter(stopMeter));
							l.start();
						}
					}
				}
			}
			
			//4 debug, while auto print under refactoring
			getPulse();
			return;
			
			// auto print under refactoring
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
		
		/*** открываем простой
		public function openLabStop(deviceId:int, timeFrom:Date, type:int = 0, comment:String = "auto"):LabStopLog {
			
			var stop:LabStopLog = new LabStopLog();
			stop.lab_device = deviceId;
			stop.lab_stop_type = type;
			stop.log_comment = comment;
			stop.time_from = timeFrom;
			
			var latch:DbLatch=new DbLatch();
			latch.addEventListener(Event.COMPLETE,onLogLabStop);
			latch.addLatch(labService.logLabStop(stop));
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
		 */
		
		
		/*** закрываем простой
		public function closeLabStop(stop:LabStopLog, timeTo:Date = null):void {
			stop.time_to = timeTo;
			
			var latch:DbLatch=new DbLatch();
			latch.addEventListener(Event.COMPLETE,onUpdateLabStop);
			latch.addLatch(labService.updateLabStop(stop));
			latch.start();
		}
		
		protected function onUpdateLabStop(event:Event):void
		{
			var latch:DbLatch= event.target as DbLatch;
			if(latch){
				latch.removeEventListener(Event.COMPLETE,onLogLabStop);
			}
		}
		 */
		
		
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
				
				//getPulse();
				finishPulse();
				return;
				
			} 
			
			var readyDevices:Array = getReadyDevices();
			
			debugStr += "Свободные устройства: " + getDeviceIds(readyDevices).join(", ") + "\n";
			
			if(readyDevices.length > 0){
				
				loadReadyForPrintingPgList(addToQueueAfterPgList);
				
			} else {
				// нет свободных устройств
				finishPulse();
			}
			
		}
		
		protected function addToQueueAfterPgList(printGroups:Array, loadByDevices:Boolean = false):void {
			
			var readyDevices:Array = getReadyDevices();
			
			if(loadByDevices){
				debugStr += "Общий список: " + getPrintGroupIds(printGroups).join(", ") + "\n";
			} else {
				debugStr += "Список по устройствам: " + getPrintGroupIds(printGroups).join(", ") + "\n";
			}
			
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
		
		protected function getPrintGroupIds(printGroups:Array):Array {
			return printGroups.map(function (item:PrintGroup, index:int, array:Array):String { return item.id });
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
				
				// если нет проверки очереди, то готовность определяем только по расписанию, иначе проверяем только лог простоя
				var lastStop:LabMeter=lab.getDeviceStopMeter(dev.id);
				/*if( !checkQueue || 
					dev.lastStopLog == null || 
					(dev.lastStopLog && dev.lastStopLog.time_to && dev.lastStopLog.time_to.time < now.time) || 
					(dev.lastStopLog && dev.lastStopLog.time_to == null && dev.lastStopLog.lab_stop_type == LabStopType.NO_ORDER)){*/
				if(!checkQueue || lastStop == null || lastStop.state == LabStopType.NO_ORDER){

					// если простоя нет или он уже закончился или простой из-за отсутствия заказов
					tt = dev.getCurrentTimeTableByDate(now);
					
					if(tt && now.time>=tt.time_from.time && now.time<=tt.time_to.time){
						// если девайс работает по расписанию
						devIsReady = true;
						
					} else if(tt && (tt.time_from.time - now.time) <= 5000*60){
						// если девайс начнет работать по расписанию меньше чем через 5 мин.
						devIsReady = true;
						
					}
					
				}
				
				// проверяем очередь refactor!!!
				if(devIsReady && checkDevicePrintQueueReady(new ArrayList(dev.compatiableQueue))){
					
					readyDevices.push(dev);
					
				}
				
			}
			
			return readyDevices;
			
		}
		
		protected function addToQueue(printGroups:Array, devices:Array, loadByDevices:Boolean):void {
			
			var devList:Array = devices.slice();
			var dev:LabDevice;
			var readyPgList:Array = [];
			
			/* 
			копируем очереди девайсов, они нужны нам для равномерного распределения ГП по девайсам, 
			а оригинальные очереди необходимо заполнить только после выставления статуса в базе
			*/
			var devPrintQueueMap:Object = {};
			for each (dev in devList){
				
				devPrintQueueMap[dev.id] = new ArrayList(dev.compatiableQueue.toArray());
				
			}
			
			var debugIds:Array = [];
			
			var skippedList:Array = [];
			
			fillDevicesWithPrintGroups(printGroups, devList, devPrintQueueMap, readyPgList, skippedList, true, debugIds);
			debugStr += "Проходят по алиасу: "+ debugIds.join(", ") +"\n";
			
			if(skippedList.length > 0){
				printGroups = skippedList.concat();
			}
			
			skippedList = [];
			debugIds = [];
			fillDevicesWithPrintGroups(printGroups, devList, devPrintQueueMap, readyPgList, skippedList, false, debugIds);
			debugStr += "Проходят в канал: "+ debugIds.join(", ") +"\n";
			
			if(!loadByDevices){
				// проверяем на сайте, после чего добавляем в очередь после загрузки общего списка
				//updatePgStatus(readyPgList, onUpdatePgStatusAfterPgList);
				checkWebReady(readyPgList, onUpdatePgStatusAfterPgList);
				
			} else {
				// проверяем на сайте, после чего добавляем в очередь после загрузки списка по девайсам
				//updatePgStatus(readyPgList, onUpdatePgStatusAfterByDevices);
				checkWebReady(readyPgList, onUpdatePgStatusAfterByDevices);
				
			}
			
			
		}
		
		protected function fillDevicesWithPrintGroups(printGroups:Array, devList:Array, devPrintQueueMap:Object, readyPgList:Array, skippedList:Array, checkAliases:Boolean, debugIds:Array):void {
			
			var pg:PrintGroup;
			var lab:LabGeneric;
			var dev:LabDevice;
			var found:Boolean;
			var i:int;
			
			var printChannelReady:Boolean;
			for each (pg in printGroups){
				
				i = 0;
				found = false;
				
				while (i < devList.length && !found) {
					
					dev = devList[i] as LabDevice;
					lab = labMap[dev.lab] as LabGeneric;
					
					printChannelReady = lab.printChannel(pg, dev.rollsOnline.toArray()) != null;
					
					if(checkAliases){
						
						printChannelReady = printChannelReady && lab.checkAliasPrintCompatiable(pg);
						
					}
					
					if(printChannelReady){
						debugIds.push(pg.id);
					}
					
					if(printChannelReady && checkDevicePrintQueueReady(devPrintQueueMap[dev.id])){
						
						pg.destination = lab.id;
						pg.state = OrderState.PRN_QUEUE;
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
				
				if(!found){
					skippedList.push(pg);
				}
				
			}
			
			
		}
		
		protected var webTask:PrintQueueWebTask;
		protected var webTaskHandler:Function;
		
		protected function checkWebReady(printGroups:Array, handler:Function):void {
			
			debugStr += "Проверка на веб-статус: " + getPrintGroupIds(printGroups).join(", ") + "\n";
			
			webTaskHandler = handler;
			
			if(printGroups.length == 0){
				updatePgStatus(printGroups, webTaskHandler);
				return;
			}
			
			webTask = new PrintQueueWebTask(printGroups);
			webTask.addEventListener(Event.COMPLETE, checkWebReadyHandler);
			webTask.execute();
			
		}
		
		protected function checkWebReadyHandler(event:Event):void
		{
			
			var webReady:Array = webTask.getItemsReady();
			
			debugStr += "Готовы для захвата в 203: " + getPrintGroupIds(webReady).join(", ") + "\n";
			
			for each (var pg:PrintGroup in webReady){
				// нужно поставить корректный статус для очереди, при веб проверке может меняться
				pg.state = OrderState.PRN_QUEUE;
			}
			
			//добавляем в очередь
			updatePgStatus(webReady, webTaskHandler);
			
			webTask.removeEventListener(Event.COMPLETE, checkWebReadyHandler);
			webTask = null;
			
		}
		
		/**
		 * вызываем для того, чтобы заполнить очередь девайсов добавленными ГП
		 */
		protected function addToDeviceQueueAfterStatus(printGroups:Array):void {
			var compDevices:Array;
			var devForPg:LabDevice;
			var dev:Object;
			
			var debugIds:Array = [];
			
			for each (var pgQueued:PrintGroup in printGroups){
				if(pgQueued.state != OrderState.PRN_QUEUE){
					// добавляем только те ГП у которых определен необходимый статус 203
					continue;
				}
				compDevices = (labMap[pgQueued.destination] as LabGeneric).getCompatiableDevices(pgQueued);
				//TODO refactor getCompatiableDevices - returns array of device
				if(compDevices.length > 0){
					devForPg = compDevices[0]['dev'] as LabDevice; // определяем по умолчанию первый доступный
					for each (dev in compDevices) {
						// определяем девайс с самой короткой очередью
						if(devForPg != dev['dev'] && devForPg.compatiableQueue.length > (dev['dev'] as LabDevice).compatiableQueue.length){
							devForPg = dev['dev'] as LabDevice;
						}
					}
					// добавляем ГП в девайс с самой короткой очередью
					devForPg.compatiableQueue.addItem(pgQueued);
					debugIds.push(pgQueued.id);
				} else {
					// TODO обработать ситуацию, когда ГП послана в лабу, в которой нет подходящих девайсов
				}
			}
			debugStr += "Добавлены в 203: "+ debugIds.join(", ") +"\n";
		}
		
		protected function updateLabQueue():void {
			var dev:LabDevice;
			var pg:PrintGroup;
			var lab:LabGeneric;
			var debugIds:Array = [];
			
			for each (dev in devices){
				for each (pg in dev.compatiableQueue.toArray()) {
					if(pg.state == OrderState.PRN_QUEUE){
						// нужно добавить ГП в лабу, но перед этим проверить наличие этой ГП в соответствующей лабе
						lab = labMap[pg.destination] as LabGeneric;
						if(!lab.checkPrintGroupInLab(pg)){
							debugIds.push(pg.id);
							lab.post(pg, Context.getAttribute('reversPrint'));
							printTicket(pg);
						}
					}
					
				}
			}
			debugStr += "Отправлены в лабу: "+ debugIds.join(", ") +"\n";
		}
		
		protected function printTicket(pg:PrintGroup):void {
			
			Printer.instance.printOrderTicket(pg);
			
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
			trace(debugStr);
			getPulse();
			
		}
		
		/**
		 * определяет, можно ли загрузить в девайс еще ГП
		 */
		protected function checkDevicePrintQueueReady(printQueue:IList):Boolean {
			
			return checkQueue? printQueue.length < 2 : true;
			
		}
		
		protected var loadReadyForPrintingPgListHandler:Function;
		
		protected function loadReadyForPrintingPgList(handler:Function):void {
			
			loadReadyForPrintingPgListHandler = handler;
			
			var latch:DbLatch=new DbLatch();
			latch.addEventListener(Event.COMPLETE, onLoadReadyForPrintingPgList);
			
			// получаем список в статусе 200, готовые к печати
			//latch.addLatch(svc.loadByState(OrderState.PRN_WAITE,OrderState.PRN_QUEUE));
			latch.addLatch(printGroupService.loadReady4Print(printGroupListLimit, true));
			latch.start();
			
		}
		
		private function onLoadReadyForPrintingPgList(evt:Event):void{
			var latch:DbLatch= evt.target as DbLatch;
			if(latch){
				latch.removeEventListener(Event.COMPLETE, onLoadReadyForPrintingPgList);
				if(!latch.complite) return;
				if(loadReadyForPrintingPgListHandler != null) loadReadyForPrintingPgListHandler.apply(this, [latch.lastDataArr]);
				//latch.clearResult();
			}
			
			loadReadyForPrintingPgListHandler = null;
			
		}
		
		protected var loadReadyForPrintingByDevicesHandler:Function;
		
		protected function loadReadyForPrintingByDevices(deviceIds:Array, handler:Function):void
		{
			
			loadReadyForPrintingByDevicesHandler = handler;
			
			var latch:DbLatch=new DbLatch();
			latch.addEventListener(Event.COMPLETE, onLoadReadyForPrintingByDevices);
			latch.addLatch(printGroupService.loadPrintPostByDev(new ArrayCollection(deviceIds), 0));
			latch.start();
			
		}
		
		private function onLoadReadyForPrintingByDevices(evt:Event):void{
			var latch:DbLatch= evt.target as DbLatch;
			if(latch){
				latch.removeEventListener(Event.COMPLETE, onLoadReadyForPrintingByDevices);
				if(!latch.complite) return;
				if(loadReadyForPrintingByDevicesHandler != null) loadReadyForPrintingByDevicesHandler.apply(this, [latch.lastDataArr, true]);
				//latch.clearResult();
			}
			
			loadReadyForPrintingByDevicesHandler = null;
			
		}
		
		protected var updatePgStatusHandler:Function;
		protected function updatePgStatus(printGroups:Array, handler:Function):void {
			updatePgStatusHandler = handler;
			// если список пуст, запрос не делаем, вызываем обработчик
			if(printGroups.length == 0){
				if(updatePgStatusHandler != null) updatePgStatusHandler.apply(this, [new Array]);
				return;
			}
			// шлем запрос на установку 203 статуса, после чего ГП считается захваченной определенной лабой
			var latch:DbLatch= new DbLatch(true);
			latch.addEventListener(Event.COMPLETE,onUpdatePgStatus);
			latch.addLatch(printGroupService.capturePrintState(new ArrayCollection(printGroups),true));
			latch.start();
		}
		
		private function onUpdatePgStatus(evt:Event):void
		{
			
			var latch:DbLatch= evt.target as DbLatch;
			if(latch){
				
				latch.removeEventListener(Event.COMPLETE, onLoadReadyForPrintingByDevices);
				
				if(!latch.complite) {
					if(updatePgStatusHandler != null) updatePgStatusHandler.apply(this, [new Array]);
					return;
				}
				
				if(updatePgStatusHandler != null) updatePgStatusHandler.apply(this, [latch.lastDataArr]);
				//latch.clearResult();
				
			}
			
		}
		
		
		
	}
}
