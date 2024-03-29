package com.photodispatcher.print{
	import com.akmeful.util.Exception;
	import com.photodispatcher.context.Context;
	import com.photodispatcher.event.PrintEvent;
	import com.photodispatcher.factory.LabBuilder;
	import com.photodispatcher.factory.PrintQueueBuilder;
	import com.photodispatcher.factory.WebServiceBuilder;
	import com.photodispatcher.interfaces.IMessageRecipient;
	import com.photodispatcher.model.mysql.DbLatch;
	import com.photodispatcher.model.mysql.entities.AbstractEntity;
	import com.photodispatcher.model.mysql.entities.Lab;
	import com.photodispatcher.model.mysql.entities.LabDevice;
	import com.photodispatcher.model.mysql.entities.LabMeter;
	import com.photodispatcher.model.mysql.entities.LabStopLog;
	import com.photodispatcher.model.mysql.entities.LabStopType;
	import com.photodispatcher.model.mysql.entities.LabTimetable;
	import com.photodispatcher.model.mysql.entities.Order;
	import com.photodispatcher.model.mysql.entities.OrderExtraInfo;
	import com.photodispatcher.model.mysql.entities.OrderState;
	import com.photodispatcher.model.mysql.entities.PrintGroup;
	import com.photodispatcher.model.mysql.entities.PrnQueue;
	import com.photodispatcher.model.mysql.entities.PrnQueueTimetable;
	import com.photodispatcher.model.mysql.entities.PrnStrategy;
	import com.photodispatcher.model.mysql.entities.SourceProperty;
	import com.photodispatcher.model.mysql.entities.SourceType;
	import com.photodispatcher.model.mysql.entities.StateLog;
	import com.photodispatcher.model.mysql.entities.messenger.CycleMessage;
	import com.photodispatcher.model.mysql.services.LabService;
	import com.photodispatcher.model.mysql.services.OrderService;
	import com.photodispatcher.model.mysql.services.OrderStateService;
	import com.photodispatcher.model.mysql.services.PrintGroupService;
	import com.photodispatcher.model.mysql.services.PrnStrategyService;
	import com.photodispatcher.printer.Printer;
	import com.photodispatcher.provider.preprocess.PrintCompleteTask;
	import com.photodispatcher.service.messenger.MessengerGeneric;
	import com.photodispatcher.service.web.BaseWeb;
	import com.photodispatcher.util.ArrayUtil;
	import com.photodispatcher.view.ModalPopUp;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.TimerEvent;
	import flash.filesystem.File;
	import flash.globalization.DateTimeStyle;
	import flash.net.SharedObject;
	import flash.utils.Dictionary;
	import flash.utils.Timer;
	import flash.utils.flash_proxy;
	
	import mx.collections.ArrayCollection;
	import mx.collections.ISort;
	import mx.controls.Alert;
	
	import org.granite.tide.Tide;
	
	import spark.collections.Sort;
	import spark.collections.SortField;
	import spark.formatters.DateTimeFormatter;
	
	[Event(name="managerError", type="com.photodispatcher.event.PrintEvent")]
	[Event(name="stopComplited", type="flash.events.Event")]
	public class PrintQueueManager extends EventDispatcher implements IMessageRecipient{
		public static const DEV_COMP_QUEUE_LEN:int=1000;
		public static const STRATEGY_REFRESH_INTERVAL:int = 10*60*1000;

		[Bindable]
		public var queueOrders:int;
		[Bindable]
		public var queuePGs:int;
		[Bindable]
		public var queuePrints:int;

		[Bindable]
		public var isBusy:Boolean=false;

		[Bindable]
		public var labMetersAC:ArrayCollection;

		[Bindable]
		public var timetableAC:ArrayCollection;
		//public var strategiesAC:ArrayCollection;
		[Bindable]
		public var strategyPusherAC:ArrayCollection;
		
		[Bindable]
		public var prnQueuesAC:ArrayCollection;

		private var _autoPrint:Boolean;

		[Bindable]
		public function get autoPrint():Boolean{
			return _autoPrint && isAutoPrintManager;
		}

		public function set autoPrint(value:Boolean):void{
			_autoPrint = value && isAutoPrintManager;
		}


		private var _isAutoPrintManager:Boolean=false;
		[Bindable]
		public function get isAutoPrintManager():Boolean{
			return _isAutoPrintManager;
		}
		public function set isAutoPrintManager(value:Boolean):void{
			_isAutoPrintManager = value;
			if(_isAutoPrintManager){
				MessengerGeneric.subscribe(MessengerGeneric.TOPIC_PRNQUEUE,this);
			}else{
				MessengerGeneric.unsubscribe(MessengerGeneric.TOPIC_PRNQUEUE,this);
			}
		}


		//print queue (printgroups)
		private var queue:Array;

		private var prnPusher:PrintQueuePusher;
		
		//map by source.id->map by order.id->Order 
		private var webQueue:Object=new Object;
		//map by source->web service
		private var webServices:Object=new Object;
		////PrintGroups 4 load 
		//private var loadQueue:Array=[];
		//PrintGroups 4 lock 
		private var lockQueue:Array=[];
		//PrintGroups in post 
		private var postQueue:Array=[];
		private var labNamesMap:Object;
		
		private var _initCompleted:Boolean=false;
		public function get initCompleted():Boolean{
			return _initCompleted;
		}

		
		private static var _instance:PrintQueueManager;
		public static function get instance():PrintQueueManager{
			if(_instance == null) var t:PrintQueueManager=new PrintQueueManager();
			return _instance;
		}
		
		private var _labs:ArrayCollection=new ArrayCollection();
		[Bindable(event="labsChange")]
		public function get labs():ArrayCollection{
			return _labs;
		}
		
		protected var _devices:ArrayCollection;
		[Bindable(event="devicesChange")]
		public function get devices():ArrayCollection {
			return _devices;
		}
		
		
		public function PrintQueueManager(){
			super(null);
			if(_instance == null){
				_instance = this;
			} else {
				throw new Exception(Exception.SINGLETON);
			}
			var so:SharedObject = SharedObject.getLocal('appProps','/');
			_includeReprintInPrnQueue=so.data.reprintInPrnQueue;
		}
		
		
		private var forceStop:Boolean=false;
		private var stopPopup:ModalPopUp;
		public function stop():Boolean{
			//TODO implement
			
			forceStop=true;
			var stopItems:Array=[];
			var o:Object;
			var pg:PrintGroup;
			
			//stop web check
			//scan sources
			var src_id:String;
			for(src_id in webQueue){
				var svc:BaseWeb=webServices[src_id] as BaseWeb;
				if(svc){
					//stop listen
					svc.removeEventListener(Event.COMPLETE,serviceCompliteHandler);
				}
				//reset printgroups
				var oMap:Object=webQueue[src_id];
				if (oMap){
					var order:Order;
					for each(o in oMap){
						order=o as Order;
						if(order && order.printGroups){
							for each(pg in order.printGroups){
								pg.state=OrderState.PRN_WAITE;
							}
						}
					}
				}
			}
			//clear
			webQueue=new Object;
			webServices=new Object;
			
			//locks in process
			//clear state
			resetPrintState(lockQueue);
			lockQueue=[];
			
			//posted
			var lab:LabGeneric;
			postQueue=[];
			stopItems=[];
			if(labs){
				for each(lab in labs){
					if(lab){
						//reset state
						stopItems=stopItems.concat(lab.resetPostQueue());
						//in process, waite post complite
						pg=lab.currentPrintGroup();
						if(pg) postQueue.push(pg);
					}
				}
				resetPrintState(stopItems);
			}
			
			//waite post complite
			if(postQueue.length>0){
				stopPopup= new ModalPopUp();
				stopPopup.label='Остановка менеджера печати';
				stopPopup.open(null);
				return false;
			}
			forceStop=false;
			dispatchEvent(new Event('stopComplited'));
			return true;
		}
		
		private function resetPrintState(items:Array):void{
			if(!items || items.length==0) return;
			var o:Object;
			var pg:PrintGroup;
			var toReset:Array=[];
			
			for each(o in items){
				pg=o as PrintGroup;
				if(pg && pg.id && pg.state>OrderState.PRN_WAITE && pg.state<OrderState.PRN_PRINT){
					pg.state=OrderState.PRN_WAITE;
					toReset.push(pg.id);
				}
			}
			if(toReset.length>0){
				var osSvc:OrderStateService=Tide.getInstance().getContext().byType(OrderStateService,true) as OrderStateService;
				var latch:DbLatch= new DbLatch();
				latch.addLatch(osSvc.printCancel(toReset));
				latch.start();
			}
		}
		
		public function init(rawLabs:Array=null):void{
			if(!rawLabs && initCompleted) return;
			if(rawLabs){
				fillLabs(rawLabs);
				return;
			}
			//read labs from bd
			var svc:LabService=Tide.getInstance().getContext().byType(LabService,true) as LabService;
			var latch:DbLatch= new DbLatch();
			latch.addEventListener(Event.COMPLETE,onLabsLoad);
			latch.addLatch(svc.loadAll(false));
			latch.start();
			
			//load strategies && PrnQueues
			loadPusherStrategy();
			loadStartTimetable();
			loadPrnQueues();
			
			startTimer();
		}
		
		
		private function onLabsLoad(evt:Event):void{
			var latch:DbLatch= evt.target as DbLatch;
			if(!latch) return;
			latch.removeEventListener(Event.COMPLETE,onLabsLoad);
			if(!latch.complite) return;
			var rawLabs:Array=latch.lastDataArr;
			if(!rawLabs) return;
			fillLabs(rawLabs);
		}
		
		private function fillLabs(rawLabs:Array):void{
			_labMap=null;
			//fill labs 
			var lab:Lab;
			var result:Array=[];
			var devArr:Array = [];
			var lb:LabGeneric;
			labNamesMap= new Object();
			for each(lab in rawLabs){
				labNamesMap[lab.id.toString()]=lab.name;
				lb=LabBuilder.build(lab);
				lb.refresh();
				result.push(lb);
				devArr = devArr.concat(lb.devices.toArray());
			}
			_labs.source=result;
			refreshLabs(true);
			
			//fill devices
			_devices = new ArrayCollection(devArr);
			dispatchEvent(new Event("devicesChange"));
			
			_initCompleted=true;
			dispatchEvent(new Event("labsChange"));
			
		}
		
		/*
		public function startStrategyBYPARTPDF():void{
			if(!initCompleted || ! strategiesAC) return;
			if(!isAutoPrintManager) return;

			var sublatch:DbLatch;
			var hasStrategy:Boolean;
			var item:PrnStrategy;
			
			for each(item in strategiesAC){
				if(item.strategy_type==PrnStrategy.STRATEGY_BYPARTPDF){
					hasStrategy=true;
					break;
				}
			}
			if(!hasStrategy) return;
			
			if(timer) timer.stop(); 
			
			//start strategy
			var svcs:PrnStrategyService=Tide.getInstance().getContext().byType(PrnStrategyService,true) as PrnStrategyService;
			sublatch= new DbLatch();
			sublatch.addEventListener(Event.COMPLETE,onstartStrategy);
			sublatch.addLatch(svcs.startStrategy2(item.id));
			sublatch.start();
			
			startTimer();
		}
		*/
		
		private var _includeReprintInPrnQueue:Boolean;
		[Bindable]
		public function get includeReprintInPrnQueue():Boolean{
			return _includeReprintInPrnQueue;
		}
		public function set includeReprintInPrnQueue(value:Boolean):void{
			_includeReprintInPrnQueue = value;
			var so:SharedObject = SharedObject.getLocal('appProps','/');
			so.data.reprintInPrnQueue = value;
			so.flush();
		}

		
		public function runStartTimetable(items:ArrayCollection):void{
			if(!items || items.length==0){
				startTimer();
				return;
			}
			var reprintMode:int=0;
			if(includeReprintInPrnQueue) reprintMode=-1;
			
			var svcs:PrnStrategyService=Tide.getInstance().getContext().byType(PrnStrategyService,true) as PrnStrategyService;
			var latch:DbLatch= new DbLatch();
			latch.addEventListener(Event.COMPLETE,onCreateQueues);
			latch.addLatch(svcs.createQueueBatch(items, reprintMode));
			latch.start();
		}
		
		private function checkStartTimetable():void{
			if(!timetableAC){
				startTimer();
				return;
			}
			var it:PrnQueueTimetable;
			var items:ArrayCollection=new ArrayCollection();
			for each(it in timetableAC){
				if(it.isTimeToStart()){
					it.booksonly=true;
					items.addItem(it);
				}
			}
			runStartTimetable(items);
		}
		private function onCreateQueues(evt:Event):void{
			var reloadQueues:Boolean;
			var latch:DbLatch= evt.target as DbLatch;
			if(latch){
				latch.removeEventListener(Event.COMPLETE,onCreateQueues);
				if(latch.complite){
					reloadQueues=latch.resultCode>0;
				}
			}
			if(reloadQueues){
				//loadPrnQueues();
				MessengerGeneric.sendMessage(CycleMessage.createMessage(MessengerGeneric.TOPIC_PRNQUEUE,MessengerGeneric.CMD_PRNQUEUE_REFRESH));
			}
			loadStartTimetable();
			startTimer();
		}

		public function checkPusher():void{
			if(!strategyPusherAC || strategyPusherAC.length==0) return;
			var item:PrnStrategy=strategyPusherAC.getItemAt(0) as PrnStrategy;
			if(item.strategy_type==PrnStrategy.STRATEGY_PUSHER){
				if(!prnPusher){
					prnPusher=new PrintQueuePusher(this,null);
					prnPusher.prnQueue.priority=item.priority;
					prnPusher.prnQueue.strategy_type=item.strategy_type;
					prnPusher.prnQueue.strategy_type_name=item.strategy_type_name;
				}
				if(item.is_active){
					//stop/start  pusher
					if(prnPusher.isActive()){
						if(item.isTimeToStop()){
							//stop pusher
							prnPusher.prnQueue.is_active=false;
							prnPusher.queue=null;
						}
					}else if(item.isTimeToStart() && !item.isTimeToStop()){
						prnPusher.prnQueue.is_active=true;
						prnPusher.prnQueue.started=new Date();
					}
				}else{
					//stop pusher
					prnPusher.prnQueue.is_active=false;
					prnPusher.queue=null;
				}
			}
		}
		
		private var timer:Timer;
		
		private function startTimer():void{
			if(!isAutoPrintManager) return;
			if(!timer){
				timer= new Timer(STRATEGY_REFRESH_INTERVAL,1);
				timer.addEventListener(TimerEvent.TIMER,onTimer);
			}else{
				timer.reset();
			}
			timer.start();
		}
		private function onTimer(event:TimerEvent):void{
			if(!initCompleted) return;
			if(!isAutoPrintManager) return;
			var startlatch:DbLatch;
			var sublatch:DbLatch;

			checkPusher();
			checkStartTimetable();
		}
		
		/*
		private function onstartStrategy(evt:Event):void{
			var latch:DbLatch= evt.target as DbLatch;
			if(!latch) return;
			latch.removeEventListener(Event.COMPLETE,onstartStrategy);
			loadPrnQueues();
		}
		*/


		private function loadStartTimetable():void{
			if(!isAutoPrintManager) return;
			timetableAC=null;
			var svcs:PrnStrategyService=Tide.getInstance().getContext().byType(PrnStrategyService,true) as PrnStrategyService;
			var latch:DbLatch= new DbLatch();
			latch.addEventListener(Event.COMPLETE,onTimetableLoad);
			latch.addLatch(svcs.loadStartTimetable());
			latch.start();
		}
		private function onTimetableLoad(evt:Event):void{
			var latch:DbLatch= evt.target as DbLatch;
			if(!latch) return;
			latch.removeEventListener(Event.COMPLETE,onStrategyLoad);
			if(!latch.complite) return;
			timetableAC=latch.lastDataAC;
		}

		
		private function loadPusherStrategy():void{
			if(!isAutoPrintManager) return;
			strategyPusherAC=new ArrayCollection();
			var svcs:PrnStrategyService=Tide.getInstance().getContext().byType(PrnStrategyService,true) as PrnStrategyService;
			var latch:DbLatch= new DbLatch();
			latch.addEventListener(Event.COMPLETE,onStrategyLoad);
			latch.addLatch(svcs.loadStrategies());
			latch.start();
		}
		private function onStrategyLoad(evt:Event):void{
			var latch:DbLatch= evt.target as DbLatch;
			if(!latch) return;
			latch.removeEventListener(Event.COMPLETE,onStrategyLoad);
			if(!latch.complite) return;
			
			//strategiesAC=latch.lastDataAC;
			//if(!strategiesAC) return;

			//create pusher
			for each(var st:PrnStrategy in latch.lastDataArr){
				if(st.strategy_type==PrnStrategy.STRATEGY_PUSHER){
					strategyPusherAC.addItem(st);
					prnPusher=new PrintQueuePusher(this,null);
					//prnPusher.prnQueue.is_active=st.is_active && st.isTimeToStart();
					prnPusher.prnQueue.priority=st.priority;
					prnPusher.prnQueue.strategy_type=st.strategy_type;
					prnPusher.prnQueue.strategy_type_name=st.strategy_type_name;
					break;
				}
			}
			checkPusher();
		}
		
		

		public function loadPrnQueues():void{
			if(!isAutoPrintManager) return;
			var svcs:PrnStrategyService=Tide.getInstance().getContext().byType(PrnStrategyService,true) as PrnStrategyService;
			var latch:DbLatch= new DbLatch();
			latch.addEventListener(Event.COMPLETE,onloadPrnQueues);
			latch.addLatch(svcs.loadQueues());
			latch.start();
		}
		private function onloadPrnQueues(evt:Event):void{
			var latch:DbLatch= evt.target as DbLatch;
			if(!latch) return;
			latch.removeEventListener(Event.COMPLETE,onloadPrnQueues);

			if(latch.complite){
				var pqg:PrintQueueGeneric;
				
				//stop listen old
				if(prnQueuesAC){
					for each(pqg in prnQueuesAC){
						pqg.removeEventListener(Event.COMPLETE, onPrintQueueFetch);
					}
				}
				
				var ac:ArrayCollection=latch.lastDataAC;
				//sort
				var sort:ISort = new Sort();
				sort.fields = [new SortField("is_reprint",true,true), new SortField("priority",true,true)]; //, new SortField("created",false,true)
				ac.sort=sort;
				ac.refresh();
				//fill
				prnQueuesAC=new ArrayCollection();
				var pq:PrnQueue; 
				for each(pq in ac){
					pqg=PrintQueueBuilder.build(this, pq);
					if(pqg) prnQueuesAC.addItem(pqg);
				}
				if(prnPusher) prnQueuesAC.addItem(prnPusher);

				//start listen
				for each(pqg in prnQueuesAC){
					pqg.addEventListener(Event.COMPLETE, onPrintQueueFetch);
				}

				
				//prnQueuesAC.refresh();
				//prnQueuesAC=latch.lastDataAC;
			}
		}
		
		private function initErr(msg:String):void{
			_labs.source=[];
			_labMap=null;
			dispatchEvent(new Event("labsChange"));
			_devices = null;
			dispatchEvent(new Event("devicesChange"));
			dispatchManagerErr(msg);
		}
		private function dispatchManagerErr(msg:String):void{
			dispatchEvent(new PrintEvent(PrintEvent.MANAGER_ERROR_EVENT,null,msg));
		}

		private var _labMap:Object;
		public function get labMap():Object{
			if(!initCompleted) return null;
			if(!_labs) return null;
			if(_labMap) return _labMap;
			var result:Object= new Object();
			var lab:LabGeneric;
			for each(lab in _labs.source){
				if(lab){
					result[lab.id.toString()]=lab;
				}
			}
			_labMap=result;
			return _labMap;
		}

		public function isLabLocked(lab:int):Boolean{
			if(!prnQueuesAC) return false;
			var pq:PrintQueueGeneric;
			for each(pq in prnQueuesAC){
				if(pq.isLabLocked(lab)) return true;
			}
			return false;
		}

		public function getLabStartedQueue(lab:int):PrintQueueGeneric{
			if(!prnQueuesAC) return null;
			var pq:PrintQueueGeneric;
			for each(pq in prnQueuesAC){
				if(pq.isLabLocked(lab) && pq.isStarted()) return pq;
			}
			return null;
		}
		
		public function isPgLocked(pgId:String, priority:int):Boolean{
			if(!prnQueuesAC) return false;
			var pq:PrintQueueGeneric;
			for each(pq in prnQueuesAC){
				if(pq.prnQueue.priority>priority){
					if(pq.isPgLocked(pgId)) return true;
				}else{
					break;
				}
			}
			return false;
		}
		
		public function getLab(id:int):LabGeneric{
			if(!_labMap) return null;
			return _labMap[id.toString()] as LabGeneric;
		}
		
		private var _labDeviceMap:Object;
		public function get labDeviceMap():Object {
			if(!initCompleted) return null;
			if(_labDeviceMap) return _labDeviceMap;
			_labDeviceMap= new Object();
			var dev:LabDevice;
			for each(dev in _devices.source){
				if(dev) _labDeviceMap[dev.id]=dev;
			}
			return _labDeviceMap;
		}

		public function getDevice(id:int):LabDevice{
			if(!_labDeviceMap) return null;
			return _labDeviceMap[id] as LabDevice;
		}

		public function refreshStops():DbLatch{
			//get current date stops
			var svc:LabService=Tide.getInstance().getContext().byType(LabService,true) as LabService;
			var latch:DbLatch= new DbLatch();
			var dtFrom:Date= new Date();
			dtFrom=new Date(dtFrom.fullYear, dtFrom.month, dtFrom.date);
			var dtTo:Date=new Date(dtFrom.time + 1000*60*60*24);
			var idAc:ArrayCollection= new ArrayCollection();
			for each (var l:LabGeneric in labs) idAc.addItem(l.id);
			latch.addEventListener(Event.COMPLETE,onrefreshStops);
			latch.addLatch(svc.loadLabStops(dtFrom,dtTo,idAc));
			latch.start();
			return latch;
		}
		private function onrefreshStops(evt:Event):void{
			var latch:DbLatch= evt.target as DbLatch;
			if(!latch) return;
			latch.removeEventListener(Event.COMPLETE,onrefreshStops);
			if(!latch.complite) return;
			if(!labMap) return;
			//fill labs
			var lm:LabStopLog;
			var lab:LabGeneric;
			//clear
			for each(lab in labs){
				if(lab) lab.resetStops();
			}
			for each(lm in latch.lastDataAC){
				if(lm){
					lab=getLab(lm.lab);
					if(lab) lab.stops.addItem(lm);
				}
			}
		}

		public function refreshMeters():DbLatch{
			var svc:LabService=Tide.getInstance().getContext().byType(LabService,true) as LabService;
			var latch:DbLatch= new DbLatch();
			latch.addEventListener(Event.COMPLETE,onrefreshMeters);
			latch.addLatch(svc.showLabMeters());
			latch.start();
			return latch;
		}
		private function onrefreshMeters(evt:Event):void{
			var currDate:Date= new Date();
			var latch:DbLatch= evt.target as DbLatch;
			if(!latch) return;
			latch.removeEventListener(Event.COMPLETE,onrefreshMeters);
			if(!latch.complite) return;
			labMetersAC=latch.lastDataAC;
			if(!labMap) return;
			//fill labs
			var lm:LabMeter;
			var lab:LabGeneric;
			//clear
			for each(lab in labs){
				if(lab) lab.resetMeters();
			}
			for each(lm in labMetersAC){
				if(lm){
					lm.toLocalTime(currDate);
					lab=getLab(lm.lab);
					if(lab) lab.addMeter(lm);
				}
			}
		}

		public function refreshSpeed():DbLatch{
			var svc:LabService=Tide.getInstance().getContext().byType(LabService,true) as LabService;
			var latch:DbLatch= new DbLatch();
			latch.addEventListener(Event.COMPLETE,onrefreshSpeed);
			latch.addLatch(svc.loadLabsSpeed());
			latch.start();
			return latch;
		}
		private function onrefreshSpeed(evt:Event):void{
			var currDate:Date= new Date();
			var latch:DbLatch= evt.target as DbLatch;
			if(!latch) return;
			latch.removeEventListener(Event.COMPLETE,onrefreshSpeed);
			if(!latch.complite) return;
			if(!labMap) return;
			var speeds:Array=latch.lastDataArr;
			//set labs speed 
			var ls:Lab;
			var lab:LabGeneric;
			for each(ls in speeds){
				if(ls){
					lab=getLab(ls.id);
					if(lab) lab.soft_speed=ls.soft_speed;
				}
			}
		}

		public function reSync(printGrps:Array=null):void{
			if(printGrps){
				_reSync(printGrps);
				return;
			}
			var svc:PrintGroupService=Tide.getInstance().getContext().byType(PrintGroupService,true) as PrintGroupService;
			var latch:DbLatch= new DbLatch();
			latch.addEventListener(Event.COMPLETE,onLoadPgSync);
			latch.addLatch(svc.loadByState(OrderState.PRN_WAITE,OrderState.PRN_PRINT));
			latch.start();
		}
		private function onLoadPgSync(evt:Event):void{
			var latch:DbLatch= evt.target as DbLatch;
			if(latch){
				latch.removeEventListener(Event.COMPLETE,onLoadPgSync);
				if(!latch.complite) return;
				_reSync(latch.lastDataArr);
			}
		}

		private function _reSync(printGrps:Array):void{
			//PrintGroup to save
			var inProcess:Array=[];
			
			var o:Object;
			var oMap:Object;
			var order:Order;
			var pg:PrintGroup;
			
			if(!printGrps) printGrps=[];
			//add from web queue
			for each(oMap in webQueue){
				for (var key:String in oMap){
					order=oMap[key] as Order;
					if(order && order.printGroups){
						for each(o in order.printGroups){
							inProcess.push(o);
						}
					}
				}
			}

			////add from load queue
			//inProcess=inProcess.concat(loadQueue);
			//add from lock queue
			inProcess=inProcess.concat(lockQueue);
			//add from post queue
			inProcess=inProcess.concat(postQueue);
			
			var idx:int;
			for each(o in inProcess){
				pg= o as PrintGroup;
				if(pg){
					//replace
					idx=ArrayUtil.searchItemIdx('id',pg.id,printGrps);
					if(idx!=-1){
						printGrps[idx]=pg;
					}else{
						//add?
						trace('PrintManager.reSync printGroup not found, add');
						if(pg.state == OrderState.ERR_WRITE_LOCK 
							|| pg.state == OrderState.PRN_QUEUE
							|| pg.state == OrderState.PRN_WEB_CHECK
							|| pg.state == OrderState.PRN_WEB_OK
							|| pg.state == OrderState.PRN_PREPARE
							|| pg.state == OrderState.PRN_POST) printGrps.unshift(pg);
					}
				}
			}
			//set print queue 
			queue=printGrps.concat();
			//TODO recalc totals
		}
		
		/**
		 * deprecated
		public function autoPost():void{
			//labs is refreshed
			//queue is in sync
			
			if(labs.length==0 || !queue || queue.length==0) return;
			var avalLabs:Array=[];
			//check labs
			if (getAvailableLabs().length==0) return;
			
		}
		 */
		
		/**
		 * deprecated
		private function getAvailableLabs():Array{
			if(labs.length==0) return [];
			var lab:LabGeneric;
			var result:Array=[];
			for each(lab in labs){
				if(lab.is_active && lab.is_managed && 
					(lab.onlineState==LabGeneric.STATE_ON || lab.onlineState==LabGeneric.STATE_SCHEDULED_ON) && 
					lab.printQueue.printQueueLen<lab.queue_limit){
					result.push(lab);
				}
			}
			return result;
		}
		 */
		
		/*
		*ручная постановка в печать
		*
		*/
		public function postManual(printGrps:Vector.<Object>,lab:LabGeneric):void{
			if(forceStop) return;
			//log('PostManual start');
			if(!lab || !printGrps || printGrps.length==0){
				//log('PostManual wrong data');
				return;
			}
			//if(pg.isAutoPrint) log('Сарт постановки на печать'+pg+' (postManual)');
			//log('PostManual Лаба '+ lab.name+' hot '+ lab.hot+'; гуппы '+printGrps.join());
			
			//check lab hot folder
			if(lab.src_type!=SourceType.LAB_XEROX && lab.src_type!=SourceType.LAB_XEROX_LONG){
				var hot:File;
				try{
					hot= new File(lab.hot);
				}catch(e:Error){}
				if(!hot || !hot.exists || !hot.isDirectory){ // || hot.getDirectoryListing().length==0){ 
					dispatchManagerErr('Hot folder "'+lab.hot+'" лаборатории "'+lab.name+'" не доступен.');
					log('Hot folder "'+lab.hot+'" лаборатории "'+lab.name+'" не доступен.');
					return;
				}
			}

			//log('Hot OK');

			var pg:PrintGroup;
			var idx:int;

			//check can print
			var postList:Array=[];
			for each(pg in printGrps){
				if(pg.state<=OrderState.PRN_QUEUE){
					//log('lab.canPrint?');
					if(lab.canPrint(pg)){
						pg.destinationLab=lab;
						pg.state=OrderState.PRN_QUEUE;
						postList.push(pg);
						if(pg.isAutoPrint){
							log('Сарт постановки на печать'+pg+' (postManual)');
							StateLog.logByPGroup(OrderState.PRN_AUTOPRINTLOG,pg.id,'Сарт постановки на печать в '+ lab.name);
						}
					}else{
						if(pg.isAutoPrint) log(pg+' Не может быть распечатана в '+lab.name+' (postManual)');
					}
				}else{
					if(pg.isAutoPrint) log('Не верный статус '+pg+' '+pg.state.toString()+ ' (postManual)');
				}
			}
			if(postList.length!=printGrps.length){
				dispatchManagerErr('Часть заказов не может быть распечатана в ' +lab.name);
			}
			
			lab.addEventListener(PrintEvent.POST_COMPLETE_EVENT,onPostComplete);
			//check web state
			pushToWebQueue(postList);
		}

		public function isInWebQueue(pg:PrintGroup):Boolean{
			if(!pg) return false;
			if(pg.is_reprint) return false;
			var srcOrders:Object=webQueue[pg.source_id.toString()];
			if(!srcOrders) return false;
			var order:Order= srcOrders[pg.order_id] as Order;
			if(!order) return false;
			
			var p:PrintGroup;
			var remove:Boolean;
			//check if some pg i wrong state BUGGG 
			for each(p in order.printGroups){
				if(p.state==OrderState.PRN_WAITE){
					remove=true;
					break;
				}
			}
			if(remove){
				for each(p in order.printGroups) p.state=OrderState.PRN_WAITE;
				delete srcOrders[pg.order_id];
				return false;
			}
			
			if(order.printGroups && order.printGroups.length>0 ){
				for each(p in order.printGroups){
					if(p.id==pg.id) return true;
				}
			}
			return false;
		}
		
		/*
		push to webQueue (check print group state)
		*/
		private function pushToWebQueue(printGrps:Array):void{
			if(forceStop) return;
			if(!printGrps || printGrps.length==0) return;
			var pg:PrintGroup;
			var srcOrders:Object;
			var order:Order;
			var toLoad:Array=[];
			for each(pg in printGrps){
				if(pg.is_reprint){
					//skip if reprint
					pg.state=OrderState.PRN_WEB_OK;
					//add to loadQueue
					toLoad.push(pg);
				}else{
					srcOrders=webQueue[pg.source_id.toString()];
					if(!srcOrders){
						srcOrders=new Object();
						webQueue[pg.source_id.toString()]=srcOrders;
					}
					order= srcOrders[pg.order_id] as Order;
					if(!order){
						order=new Order();
						order.id=pg.order_id;
						order.source=pg.source_id;
						order.ftp_folder=pg.order_folder;
						order.printGroups=new ArrayCollection();
						order.state=OrderState.PRN_QUEUE;
						srcOrders[pg.order_id]=order;
					}
					if(order.printGroups.length==0 || order.printGroups.getItemIndex(pg)==-1) order.printGroups.addItem(pg);
				}
			}
			//start check web state
			//scan sources
			var src_id:String;
			for(src_id in webQueue){
				var svc:BaseWeb=webServices[src_id] as BaseWeb;
				if(!svc){
					svc= WebServiceBuilder.build(Context.getSource(int(src_id)));
					svc.addEventListener(Event.COMPLETE,serviceCompliteHandler);
					webServices[src_id]=svc;
				}
				if(!svc.isRunning) serviceCheckNext(svc);
			}
			
			//lock/load reprint pg
			capturePrintGroups(toLoad);
		}
		
		private function serviceCheckNext(service:BaseWeb):void{
			if(forceStop) return;
			if(service.isRunning) return;
			
			var oMap:Object;
			var src_id:String=service.source.id.toString();
			oMap=webQueue[src_id];
			if (!oMap){
				//complited return
				return;
			}
			var order:Order;
			for each(var o:Object in oMap){
				order=o as Order;
				if(order && order.state==OrderState.PRN_QUEUE) break;
			}
			if (order && order.state==OrderState.PRN_QUEUE){
				order.state=OrderState.PRN_WEB_CHECK;
				for each (var pg:Object in order.printGroups){
					pg.state=OrderState.PRN_WEB_CHECK;
				}
				service.getOrder(order);
			}
		}
		
		private function serviceCompliteHandler(e:Event):void{
			var svc:BaseWeb=e.target as BaseWeb;
			var prnGrp:PrintGroup;
			var toLoad:Array=[];
			var hasProductionErr:Boolean=false;
			var latch:DbLatch;
			
			if(forceStop) return;
			
			if(svc){
				var oMap:Object=webQueue[svc.source.id.toString()];
				var order:Order=oMap[svc.lastOrderId] as Order;
				
				if(order){
					//check web service err
					if(svc.hasError){
						dispatchManagerErr('Ошибка web сервиса: '+svc.errMesage);
						for each (prnGrp in order.printGroups){
							prnGrp.state=OrderState.ERR_WEB;
							StateLog.logByPGroup(OrderState.ERR_WEB,prnGrp.id,'Ошибка проверки на сайте: '+svc.errMesage);
						}
					}else{
						if(svc.isValidLastOrder()){
							//update extra info 4  FOTOKNIGA type
							if(svc.source.type==SourceType.SRC_FOTOKNIGA && svc.getLastOrder()){
								//check production
								if(Context.getProduction()!=Context.PRODUCTION_ANY){
									if(svc.getLastOrder().production==Context.PRODUCTION_NOT_SET){
										trace('PrintQueueManager.serviceCompliteHandler; order production not set '+svc.lastOrderId);
										hasProductionErr=true;
										dispatchManagerErr('Заказ #'+svc.lastOrderId+' не назначено производство. Размещение на печать отменено.');
										//mark vs error
										for each (prnGrp in order.printGroups){
											prnGrp.state=OrderState.ERR_PRODUCTION_NOT_SET;
											prnGrp.destinationLab=null;
											StateLog.logByPGroup(OrderState.ERR_PRODUCTION_NOT_SET,prnGrp.id,'Не назначено производство. Размещение на печать отменено.');
										}
									}else if(svc.getLastOrder().production!=Context.getProduction()){
										trace('PrintQueueManager.serviceCompliteHandler; wrong order production; cancel order '+svc.lastOrderId);
										hasProductionErr=true;
										dispatchManagerErr('Заказ #'+svc.lastOrderId+' неверное производство. Размещение на печать отменено.');
										//mark log canceled
										for each (prnGrp in order.printGroups){
											prnGrp.state=OrderState.CANCELED_PRODUCTION;
											prnGrp.destinationLab=null;
											StateLog.logByPGroup(OrderState.CANCELED_PRODUCTION, prnGrp.id,'Неверное производство ('+svc.getLastOrder().production.toString()+'). Размещение на печать отменено.');
										}
										//cancel order
										var bdSvc:OrderService=Tide.getInstance().getContext().byType(OrderService,true) as OrderService;
										latch= new DbLatch();
										latch.addLatch(bdSvc.cancelOrders([svc.lastOrderId], OrderState.CANCELED_PRODUCTION));
										latch.start();
									}
								}
								
								var ei:OrderExtraInfo=svc.getLastOrder().extraInfo;
								if(ei && !hasProductionErr){
									ei.persistState=AbstractEntity.PERSIST_CHANGED;
									var osvc:OrderService=Tide.getInstance().getContext().byType(OrderService,true) as OrderService;
									latch= new DbLatch(true);
									latch.addLatch(osvc.persistExtraInfo(ei));
									latch.start();
								}
							}
							if(!hasProductionErr){
								//set state 
								for each (prnGrp in order.printGroups){
									//prnGrp= pg as PrintGroup;
									if(prnGrp){
										if(prnGrp.state==OrderState.PRN_WEB_CHECK){
											prnGrp.state=OrderState.PRN_WEB_OK;
											if(prnGrp.isAutoPrint) log('Веб проверка выполнена '+prnGrp+' (serviceCompliteHandler)');
											//add to loadQueue
											toLoad.push(prnGrp);
										}else{
											StateLog.logByPGroup(OrderState.ERR_WEB,prnGrp.id,'Ошибка статуса при проверке на сайте ('+prnGrp.state.toString()+')');
										}
									}
								}
								//lock/load pg
								capturePrintGroups(toLoad);
							}
						}else{
							dispatchManagerErr('Заказ #'+svc.lastOrderId+' отменен на сайте. Обновите данные. Размещение заказа на печать отменено.');
							//mark as canceled
							for each (prnGrp in order.printGroups){
								prnGrp.state=OrderState.CANCELED_SYNC;
								prnGrp.destinationLab=null;
							}
						}
					}
				}
				delete oMap[svc.lastOrderId];
				//compact webQueue
				var key:String;
				for(key in oMap){
					if(key) break;
				}
				if(!key){
					delete webQueue[svc.source.id.toString()];
				}
				//check next
				serviceCheckNext(svc);
			}
			//check if any source in process
			//checkWebComplite();
		}

		private function capturePrintGroups(printGroups:Array):void{
			if(forceStop) return;
			if(!printGroups || printGroups.length==0) return;
			var prnGrp:PrintGroup;
			//set state
			for each (prnGrp in printGroups) prnGrp.state=OrderState.PRN_QUEUE;
			//call service
			var svc:PrintGroupService=Tide.getInstance().getContext().byType(PrintGroupService,true) as PrintGroupService;
			var latch:DbLatch= new DbLatch();
			latch.addEventListener(Event.COMPLETE,onPGLoad);
			latch.addLatch(svc.capturePrintState(new ArrayCollection(printGroups.concat()),true));
			latch.start();
			//push to lockQueue 
			if(!lockQueue) lockQueue=[];
			lockQueue=lockQueue.concat(printGroups);
		}

		private function onPGLoad(evt:Event):void{
			var pgBd:PrintGroup;
			var pg:PrintGroup;
			var latch:DbLatch= evt.target as DbLatch;
			if(latch) latch.removeEventListener(Event.COMPLETE,onPGLoad);
			if(forceStop) return;
			
			if(!latch || !latch.complite){
				//reset all ??
				for each(pg in lockQueue) pg.state=OrderState.PRN_WAITE;
				lockQueue=[];
			}
			var result:Array=latch.lastDataArr;
			var left:Array=[];
			var idx:int;
			var hasErr:Boolean;
			for each(pg in lockQueue){
				idx= ArrayUtil.searchItemIdx('id',pg.id,result);
				if(idx==-1){
					left.push(pg);
				}else{
					pgBd=result[idx] as PrintGroup;
					//autoPost will complite post ??
					/**/
					if(pgBd){
						if((pgBd.state!=OrderState.PRN_QUEUE) || !pgBd.files || pgBd.files.length==0){
							//wrong state or empty files
							pg.state=pgBd.state; 
							if(pg.isAutoPrint){
								log('Блокировка на печать не выполнена '+pg+' (capturePrintGroups)');
								StateLog.logByPGroup(OrderState.PRN_AUTOPRINTLOG,pg.id,'Блокировка на печать не выполнена');
							}
							hasErr=true;
						}else{
							//files loaded & state ok
							pg.files=pgBd.files;
							pg.alias=pgBd.alias;
							if(pg.destinationLab){
								//add to postQueue
								idx=ArrayUtil.searchItemIdx('id',pg.id,postQueue);
								if(idx==-1){
									postQueue.push(pg);
								}else{
									postQueue[idx]=pg;
								}
								StateLog.logByPGroup(pg.state, pg.id,'Блокирован (h) '+Context.appID);
								//post to lab
								var revers:Boolean=Context.getAttribute('reversPrint');
								if(pg.isAutoPrint){
									log('Блокирован и отправлен на печать '+pg+' в '+pg.destinationLab.name+' (capturePrintGroups)');
									StateLog.logByPGroup(OrderState.PRN_AUTOPRINTLOG, pg.id,'Отправлен на печать в '+pg.destinationLab.name);
								}
								pg.destinationLab.post(pg,revers);
							}
						}
					}
					/**/
				}
			}
			lockQueue=left;
			if(hasErr) dispatchManagerErr('Часть заказов не размещена из-за не сответствия статуса заказа (bd).');
		}
		
		private function checkWebComplite():Boolean{
			//check if any source in process
			var src_id:String='';
			for(src_id in webServices){
				//var svc:ProfotoWeb=webServices[src_id] as ProfotoWeb;
				var svc:BaseWeb=webServices[src_id] as BaseWeb;
				if(svc && svc.isRunning){
					return false;
				}
			}
			var result:Boolean=true;
			src_id='';
			for(src_id in webQueue){
				result=false;
				break;
			}
			if(result){
				//all sources completed
				trace('PrintManager: web check completed.');
			}
			return result;
		}
		

		private function onPostComplete(e:PrintEvent):void{
			//remove from postQueue
			var idx:int=ArrayUtil.searchItemIdx('id',e.printGroup.id,postQueue);
			while(idx!=-1){
				postQueue.splice(idx,1);
				idx=ArrayUtil.searchItemIdx('id',e.printGroup.id,postQueue);
			}
			if(!e.hasErr){
				//print ticket
				Printer.instance.printOrderTicket(e.printGroup);
				if(postQueue.length==0 && !forceStop){
					//complited refresh lab
					refreshLabs();
				}
			}
			
			if(forceStop){
				if(postQueue.length==0){
					//stop complited
					if(stopPopup) stopPopup.close();
					stopPopup=null;
					forceStop=false;
					//refreshLabs();
					dispatchEvent(new Event('stopComplited'));
				}
			}
			
		}
		/*
		private function onPostWrite(evt:Event):void{ 
			var latch:DbLatch=evt.target as DbLatch;
			if(latch){
				latch.removeEventListener(Event.COMPLETE,onPostWrite);
			}
			if(postQueue.length==0){
				//complited refresh lab
				refreshLabs();
			}
		}
		*/
		public function refreshLabs(recalcOnly:Boolean=false):void{
			var newqueueOrders:int;
			var newqueuePGs:int;
			var newqueuePrints:int;
			var lab:LabGeneric;

			refreshMeters();
			refreshStops();
			refreshSpeed();

			/*			
			//TODO closed while not in use
			return;

			for each(lab in _labs.source){
				if(!recalcOnly) lab.refresh();
				newqueueOrders+=lab.printQueue.queueOrders;
				newqueuePGs+=lab.printQueue.queuePGs;
				newqueuePrints+=lab.printQueue.queuePrints;
			}
			queueOrders=newqueueOrders;
			queuePGs=newqueuePGs;
			queuePrints=newqueuePrints;
			*/
		}
		

		public function setPrintedState(printGroups:Array):void{
			if(!printGroups || printGroups.length==0) return;
			var ids:Array=[];
			var pg:PrintGroup;
			for each(pg in printGroups) ids.push(pg.id);
			var svc:OrderStateService=Tide.getInstance().getContext().byType(OrderStateService,true) as OrderStateService;
			var latch:DbLatch= new DbLatch();
			//latch.addEventListener(Event.COMPLETE,onPostWrite);
			latch.addLatch(svc.printEndManual(ids));
			latch.start();
		}

		/************ cancel print ***********/
		private var cancelPostPrintGrps:Array;
		
		public function cancelPost(printGrps:Array):void{
			if(isBusy ||!printGrps || !labNamesMap) return;
			isBusy=true;
			//currentLab=lab;
			cancelPostPrintGrps=printGrps;
			var ids:Array=[];
			var pg:PrintGroup;
			for each(pg in cancelPostPrintGrps) ids.push(pg.id);
			var svc:OrderStateService=Tide.getInstance().getContext().byType(OrderStateService,true) as OrderStateService;
			var latch:DbLatch= new DbLatch();
			latch.addEventListener(Event.COMPLETE,onCancelPost);
			latch.addLatch(svc.printCancel(ids));
			latch.start();
		}
		private function onCancelPost(evt:Event):void{ 
			var latch:DbLatch= evt.target as DbLatch;
			if(latch){
				latch.removeEventListener(Event.COMPLETE,onCancelPost);
				if(latch.complite){
					trace('PrintManager cancel print write db completed.');
					clearHotFolder();
				}else{
					trace('PrintManager cancel print write db locked '+ '; err: '+latch.error);
					dispatchManagerErr('Отмена печати не выполнена.');
					cancelPostPrintGrps=null;
					isBusy=false;
				}
			}
		}
		private function clearHotFolder():void{
			var pg:PrintGroup;
			for each (var o:Object in cancelPostPrintGrps){
				pg=o as PrintGroup;
				if(pg) pg.state=OrderState.PRN_CANCEL;
			}
			deleteNextFolder();
		}
		private function deleteNextFolder():void{
			if(!cancelPostPrintGrps || cancelPostPrintGrps.length==0){
				//complited
				isBusy=false;
				cancelPostPrintGrps=null;
				return;
			}
			var pg:PrintGroup=cancelPostPrintGrps.pop() as PrintGroup;
			//build path
			var currentLab:LabGeneric=ArrayUtil.searchItem('id',pg.destination,labs.source) as LabGeneric;
			if(!currentLab){
				dispatchManagerErr('Не определена лаборатория id:'+pg.destination.toString()+'. Файлы заказа '+pg.id+' не удалены.');
				deleteNextFolder();
				return;
			}
			if(currentLab.src_type==SourceType.LAB_XEROX || currentLab.src_type==SourceType.LAB_XEROX_LONG){
				//TODO implement delete by fiie
				//skiped, xerox hasn't order folder, pdf is order container  
				deleteNextFolder();
				return;
			}
			if(!currentLab.orderFolderName(pg)){
				//skip  
				deleteNextFolder();
				return;
			}
			var prefix:String=SourceProperty.getProperty(currentLab.src_type,SourceProperty.HF_PREFIX);
			var sufix:String=SourceProperty.getProperty(currentLab.src_type,SourceProperty.HF_SUFIX_READY);
			var path:String=currentLab.hot+File.separator+prefix+currentLab.orderFolderName(pg)+sufix;
			var pathNHF:String;
			if(currentLab.src_type==SourceType.LAB_NORITSU && currentLab.hot_nfs){
				prefix=SourceProperty.getProperty(SourceType.LAB_NORITSU_NHF,SourceProperty.HF_PREFIX);
				sufix=SourceProperty.getProperty(SourceType.LAB_NORITSU_NHF,SourceProperty.HF_SUFIX_READY);
				pathNHF=currentLab.hot_nfs+File.separator+prefix+(currentLab as LabNoritsu).orderFolderNameNHF(pg)+sufix;
			}
			
			var dstFolder:File;
			//check dest folder
			try{
				dstFolder= new File(path);
			}catch(e:Error){}
			
			if((!dstFolder || !dstFolder.exists || !dstFolder.isDirectory) && pathNHF){
				try{
					dstFolder= new File(pathNHF);
				}catch(e:Error){}
			}
			if(!dstFolder || !dstFolder.exists || !dstFolder.isDirectory){
				dispatchManagerErr('Не найдена папка "'+path+'". Файлы заказа '+pg.id+' не удалены.');
				deleteNextFolder();
			}
			dstFolder.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onDelFault);
			dstFolder.addEventListener(IOErrorEvent.IO_ERROR, onDelIoFault);
			dstFolder.addEventListener(Event.COMPLETE,onDelete);
			dstFolder.deleteDirectoryAsync(true);
		}
		private function onDelFault(e:SecurityErrorEvent):void{
			var dstFolder:File=e.target as File;
			dstFolder.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onDelFault);
			dstFolder.removeEventListener(IOErrorEvent.IO_ERROR, onDelIoFault);
			dstFolder.removeEventListener(Event.COMPLETE,onDelete);
			dispatchManagerErr('Ошибка при удалении папки.'+e.text);
			deleteNextFolder();
		}
		private function onDelIoFault(e:IOErrorEvent):void{
			var dstFolder:File=e.target as File;
			dstFolder.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onDelFault);
			dstFolder.removeEventListener(IOErrorEvent.IO_ERROR, onDelIoFault);
			dstFolder.removeEventListener(Event.COMPLETE,onDelete);
			dispatchManagerErr('Ошибка при удалении папки.'+e.text);
			deleteNextFolder();
		}
		private function onDelete(e:Event):void{
			var dstFolder:File=e.target as File;
			dstFolder.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onDelFault);
			dstFolder.removeEventListener(IOErrorEvent.IO_ERROR, onDelIoFault);
			dstFolder.removeEventListener(Event.COMPLETE,onDelete);
			deleteNextFolder();
		}

		/*--------------------------- autoprint -------------------------*/
		
		//protected var printQueue:PrintQueue;

		public function getPrintReadyDevices(checkQueue:Boolean=false, devQueueLen:int=DEV_COMP_QUEUE_LEN):Array {
			var now:Date = new Date
			var readyDevices:Array = [];
			var tt:LabTimetable;
			var lab:LabGeneric;
			var devIsReady:Boolean;
			
			if(!labMap) return [];
			
			for each (var dev:LabDevice in devices){
				lab =  getLab(dev.lab);
				if(!lab || !lab.is_managed){
					// пропускает девайсы лаб, на которых идет ручная постановка в печать
					continue;
				}
				devIsReady = false;
				// если нет проверки очереди, то готовность определяем только по расписанию, иначе проверяем только лог простоя
				var lastStop:LabMeter=null; //=lab.getDeviceStopMeter(dev.id);
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
				// проверяем очередь
				if(devIsReady && (!checkQueue || !dev.compatiableQueue || dev.compatiableQueue.length<=devQueueLen)){
					readyDevices.push(dev);
				}
			}
			
			return readyDevices;
		}

		public function runAutoPrint():void{
			if(!autoPrint) return;
			if(forceStop) return;
			if(!isAutoPrintManager) return;


			var pqg:PrintQueueGeneric;
			var devs:Array;
			if(prnQueuesAC){
				for each(pqg in prnQueuesAC){
					//TODO run in sequence????
					if(pqg.isActive()){
						log("Проверяю очередь " +pqg.caption);
						if(pqg.isPusher()){
							devs=getPrintReadyDevices();
						}else{
							devs=getPrintReadyDevices(true,2);
						}
						if(devs.length==0){
							log("Нет свободных девайсов");
						}else{
							log("Cвободные девайсы: "+devs.join());
							log("Дергаю очередь");
							pqg.fetch();
						}
					}
				}
			}

			/*
			if(getPrintReadyDevices().length==0){
			log("Нет свободных девайсов (runAutoPrint)");
			return;
			}else{
			log("Есть свободные девайсы: проверяем очереди (runAutoPrint)");
			}
			if(!printQueue){
				printQueue= new PrintQueue(this);
				printQueue.addEventListener(Event.COMPLETE, onPrintQueueFetch);
			}
			printQueue.fetch();
			*/
		}

		public function runQueue(pqg:PrintQueueGeneric):void{
			if(!pqg){
				log("Пустая очередь" );
				return;
			}
			if(pqg.isPusher()){
				log("Пушер нельзя запускать" );
				return;
				
			}
				
			var devs:Array;
					if(pqg.isActive()){
						log("Проверяю очередь " +pqg.caption);
						devs=getPrintReadyDevices(true,2);
						if(devs.length==0){
							log("Нет свободных девайсов");
						}else{
							log("Cвободные девайсы: "+devs.join());
							log("Дергаю очередь");
							pqg.fetch();
						}
					}
		}
		
		protected function onPrintQueueFetch(event:Event):void{
			if(forceStop) return;

			var msg:String="";
			var printQueue:PrintQueueGeneric= event.target as PrintQueueGeneric; 
			if(!printQueue) return; 
			var toPost:Array=printQueue.getFetched();
			if(!toPost || toPost.length==0){
				msg=printQueue.caption;
				if(!printQueue.hasWaitingPG()){
					msg=msg+" Нечего печатать (onPrintQueueFetch)";
				}else{
					msg=msg+" Нет подходящей лабы (onPrintQueueFetch)";
				}
				log(msg);
				return;
			}else{
				log(printQueue.caption+ " Прилетело "+toPost.length.toString()+". (onPrintQueueFetch)");
			}
			
			var posts:Dictionary= new Dictionary();
			var v:Vector.<Object>;
			var pg:PrintGroup;
			
			//build posts by lab
			for each (pg in toPost){
				if(pg && pg.destinationLab){
					v=posts[pg.destinationLab] as Vector.<Object>;
					if(!v){
						v=new Vector.<Object>();
						posts[pg.destinationLab]=v;
					}
					//TODO replace in manager manual queue?
					pg.isAutoPrint=true;
					v.push(pg);
				}
			}

			//post
			var lab:LabGeneric;
			for(var key:Object in posts){
				lab=key as LabGeneric;
				if(lab){
					v=posts[key] as Vector.<Object>;
					if(v){
						log('Автопостановка. Лаба:'+lab.name+'. Гп: '+v.join()+'. (onPrintQueueFetch)');
						postManual(v,lab); 
					}
				}
			}
		}
		
		[Bindable]
		public var logText:String = '';
		
		private var dtFmt:DateTimeFormatter;
		
		public function log(mesage:String):void{
			if(!dtFmt){
				dtFmt=new DateTimeFormatter();
				dtFmt.timeStyle=DateTimeStyle.LONG;
				dtFmt.dateTimePattern='dd.MM.yy HH:mm:ss';
			}
			logText=dtFmt.format(new Date())+' '+ mesage+'\n'+logText;
			if(logText.length>5000) logText=logText.substr(0,5000);
		}
		public function clearLog():void{
			logText='';
		}

		
		public function deletePrnQueue(queueId:int):DbLatch{
			if(!queueId) return null;
			var svc:PrnStrategyService=Tide.getInstance().getContext().byType(PrnStrategyService,true) as PrnStrategyService;
			var latch:DbLatch=new DbLatch();
			latch.addEventListener(Event.COMPLETE,onDeleteQueue);
			latch.addLatch(svc.deleteQueue(queueId));
			latch.start();
			return latch;
		}
		private function onDeleteQueue(evt:Event):void{
			var latch:DbLatch= evt.target as DbLatch;
			if(latch){
				latch.removeEventListener(Event.COMPLETE,onDeleteQueue);
				trace('DeleteQueue result:'+latch.resultCode);
			}
			//send refresh
			MessengerGeneric.sendMessage(CycleMessage.createMessage(MessengerGeneric.TOPIC_PRNQUEUE,MessengerGeneric.CMD_PRNQUEUE_REFRESH));
		}
		
		/**
		 *отцепляет запущенную (started) очередь от лабы
		 * находит текущую группу печати и делает допечатку
		 *  
		 **/
		public function releasePrnQueue(queueId:int, subId:int):void{
			var svc:PrnStrategyService=Tide.getInstance().getContext().byType(PrnStrategyService,true) as PrnStrategyService;
			var latch:DbLatch=new DbLatch();
			latch.addEventListener(Event.COMPLETE,onLoadeQueue);
			latch.addLatch(svc.loadQueue(queueId,subId));
			latch.start();
		}
		private function onLoadeQueue(evt:Event):void{
			var latch:DbLatch= evt.target as DbLatch;
			latch.removeEventListener(Event.COMPLETE,onLoadeQueue);
			if(!latch.complite || !latch.lastDataArr || latch.lastDataArr.length==0) return;
			var pq:PrnQueue=latch.lastDataArr[0] as PrnQueue;
			if(!pq) return;
			if(pq.complited || !pq.started) return;
			//detect last printed pg
			var toComplite:PrintGroup;
			for each(var pg:PrintGroup in pq.printGroups){
				if(pg.state==OrderState.PRN_INPRINT) toComplite=pg;
			}
			
			if(toComplite){
				var pcTask:PrintCompleteTask= new PrintCompleteTask(toComplite);
				pcTask.addEventListener(Event.COMPLETE, onPrintCompleteTask);
				pcTask.run();
			}
		}
		private function onPrintCompleteTask(e:Event):void{
			var pcTask:PrintCompleteTask=e.target as PrintCompleteTask; 
			if(!pcTask) return;
			pcTask.removeEventListener(Event.COMPLETE, onPrintCompleteTask);
			if(pcTask.hasError){
				Alert.show(pcTask.err_msg);
			}else{
				//Alert.show('Допечатка подготовлена');
			}
		}

		private var createPrnQueueParams:PrintGroup;
		public function createPrnQueue(params:PrintGroup):DbLatch{
			if(!params || !params.prn_queue || !params.destination) return null;
			createPrnQueueParams=params;
			//get soft lock
			var latch:DbLatch=OrderService.getPrnQueueLock();
			latch.addEventListener(Event.COMPLETE,onPrnQueueLock);
			latch.start();
			return latch;
		}
		private function onPrnQueueLock(evt:Event):void{
			var latch:DbLatch= evt.target as DbLatch;
			latch.removeEventListener(Event.COMPLETE,onPrnQueueLock);
			if(!createPrnQueueParams) return;
			if(latch.resultCode>0){
				//ok
				var svc:PrnStrategyService=Tide.getInstance().getContext().byType(PrnStrategyService,true) as PrnStrategyService;
				latch=new DbLatch();
				latch.addEventListener(Event.COMPLETE,onCreateQueue);
				latch.addLatch(svc.createQueue(createPrnQueueParams.prn_queue, createPrnQueueParams.destination,createPrnQueueParams));
				latch.start();
			}else{
				//already locked
			}
		}
		private function onCreateQueue(evt:Event):void{
			createPrnQueueParams=null;
			var latch:DbLatch= evt.target as DbLatch;
			if(latch){
				latch.removeEventListener(Event.COMPLETE,onCreateQueue);
				trace('CreateQueue result:'+latch.resultCode);
				if(latch.complite && latch.resultCode!=0){
					//send refresh
					MessengerGeneric.sendMessage(CycleMessage.createMessage(MessengerGeneric.TOPIC_PRNQUEUE,MessengerGeneric.CMD_PRNQUEUE_REFRESH));
				}
				/*
				if(latch.complite && latch.resultCode!=0 && latch.lastDataArr.length>0){
					//mark queue
					var pgStart:PrintGroup=latch.lastDataArr[0] as PrintGroup;
					var pgEnd:PrintGroup;
					if(latch.lastDataArr.length>1) pgEnd=latch.lastDataArr[1] as PrintGroup;
					var qmTask:QueueMarkTask= new QueueMarkTask(pgStart, pgEnd);
					qmTask.addEventListener(Event.COMPLETE, onqmTask);
					qmTask.run();
				}
				*/
			}
			//unlock
			OrderService.releasePrnQueueLock();
		}
		/*
		private function onqmTask(evt:Event):void{
			var qmTask:QueueMarkTask=evt.target as QueueMarkTask;
			if(qmTask){
				qmTask.removeEventListener(Event.COMPLETE, onqmTask);
				if(qmTask.hasError){
					Alert.show('Ошибка маркировки партии '+qmTask.error);
				}
			}
			//send refresh
			MessengerGeneric.sendMessage(CycleMessage.createMessage(MessengerGeneric.TOPIC_PRNQUEUE,MessengerGeneric.CMD_PRNQUEUE_REFRESH));
		}
		*/
		
		public function getMessage(message:CycleMessage):void{
			if(!isAutoPrintManager) return;
			if(message){
				if(message.command==MessengerGeneric.CMD_PRNQUEUE_REFRESH) loadPrnQueues();
			}
		}
		
	}
}