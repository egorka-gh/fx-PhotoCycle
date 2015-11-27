package com.photodispatcher.print{
	import com.akmeful.util.Exception;
	import com.photodispatcher.context.Context;
	import com.photodispatcher.event.PrintEvent;
	import com.photodispatcher.factory.LabBuilder;
	import com.photodispatcher.factory.WebServiceBuilder;
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
	import com.photodispatcher.model.mysql.entities.SourceProperty;
	import com.photodispatcher.model.mysql.entities.SourceType;
	import com.photodispatcher.model.mysql.entities.StateLog;
	import com.photodispatcher.model.mysql.services.LabService;
	import com.photodispatcher.model.mysql.services.OrderService;
	import com.photodispatcher.model.mysql.services.OrderStateService;
	import com.photodispatcher.model.mysql.services.PrintGroupService;
	import com.photodispatcher.printer.Printer;
	import com.photodispatcher.service.web.BaseWeb;
	import com.photodispatcher.util.ArrayUtil;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.filesystem.File;
	import flash.utils.Dictionary;
	import flash.utils.flash_proxy;
	
	import mx.collections.ArrayCollection;
	
	import org.granite.tide.Tide;
	
	[Event(name="managerError", type="com.photodispatcher.event.PrintEvent")]
	public class PrintQueueManager extends EventDispatcher{
		
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
		public var autoPrint:Boolean;

		//print queue (printgroups)
		private var queue:Array;
		
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
		}
		
		public function init(rawLabs:Array=null):void{
			if(!rawLabs && initCompleted) return;
			if(rawLabs){
				fillLabs(rawLabs);
				return;
			}
			//read from bd
			var svc:LabService=Tide.getInstance().getContext().byType(LabService,true) as LabService;
			var latch:DbLatch= new DbLatch();
			latch.addEventListener(Event.COMPLETE,onLabsLoad);
			latch.addLatch(svc.loadAll(false));
			latch.start();
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
			if(!lab || !printGrps || printGrps.length==0) return;
			
			//check lab hot folder
			if(lab.src_type!=SourceType.LAB_XEROX){
				var hot:File;
				try{
					hot= new File(lab.hot);
				}catch(e:Error){}
				if(!hot || !hot.exists || !hot.isDirectory || hot.getDirectoryListing().length==0){ 
					dispatchManagerErr('Hot folder "'+lab.hot+'" лаборатории "'+lab.name+'" не доступен.');
					return;
				}
			}

			var pg:PrintGroup;
			var idx:int;

			//check can print
			var postList:Array=[];
			for each(pg in printGrps){
				if(pg.state<=OrderState.PRN_QUEUE){
					if(lab.canPrint(pg)){
						pg.destinationLab=lab;
						pg.state=OrderState.PRN_QUEUE;
						postList.push(pg);
					}
				}
			}
			if(postList.length!=printGrps.length){
				dispatchManagerErr('Часть заказов не может быть распечатана в ' +lab.name);
			}
			
			lab.addEventListener(PrintEvent.POST_COMPLETE_EVENT,onPostComplete);
			//check web state
			pushToWebQueue(postList);
		}

		/*
		push to webQueue (check print group state)
		*/
		private function pushToWebQueue(printGrps:Array):void{
			if(!printGrps || printGrps.length==0) return;
			var pg:PrintGroup;
			var srcOrders:Object;
			var order:Order
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
			if(svc){
				var oMap:Object=webQueue[svc.source.id.toString()];
				var order:Order=oMap[svc.lastOrderId] as Order;
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
							hasErr=true;
						}else{
							//files loaded & state ok
							pg.files=pgBd.files;
							pg.alias=pgBd.alias;
							if(pg.destinationLab){
								//add to postQueue
								postQueue.push(pg);
								//post to lab
								var revers:Boolean=Context.getAttribute('reversPrint');
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
			var idx:int;
			idx=ArrayUtil.searchItemIdx('id',e.printGroup.id,postQueue);
			if(idx!=-1){
				postQueue.splice(idx,1);
			}
			if(!e.hasErr){
				//print ticket
				Printer.instance.printOrderTicket(e.printGroup);
				if(postQueue.length==0){
					//complited refresh lab
					refreshLabs();
				}
			}
		}
		
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
			if(currentLab.src_type==SourceType.LAB_XEROX){
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
		
		protected var printQueue:PrintQueue;

		public function getPrintReadyDevices(checkQueue:Boolean=true):Array {
			var now:Date = new Date
			var readyDevices:Array = [];
			var tt:LabTimetable;
			var lab:LabGeneric;
			var devIsReady:Boolean;
			
			if(!labMap) return [];
			
			for each (var dev:LabDevice in devices){
				lab = (labMap[dev.lab] as LabGeneric);
				if(!lab.is_managed){
					// пропускает девайсы лаб, на которых идет ручная постановка в печать
					continue;
				}
				devIsReady = false;
				// если нет проверки очереди, то готовность определяем только по расписанию, иначе проверяем только лог простоя
				var lastStop:LabMeter=lab.getDeviceStopMeter(dev.id);
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
				if(devIsReady && (!checkQueue || !dev.compatiableQueue || dev.compatiableQueue.length<2)){
					readyDevices.push(dev);
				}
			}
			
			return readyDevices;
		}

		public function runAutoPrint():void{
			if(!autoPrint) return;
			if(getPrintReadyDevices().length==0) return;
			
			if(!printQueue){
				printQueue= new PrintQueue(this);
				printQueue.addEventListener(Event.COMPLETE, onPrintQueueFetch);
			}
			printQueue.fetch();
		}
		
		protected function onPrintQueueFetch(event:Event):void{
			if(!printQueue) return; 
			var toPost:Array=printQueue.getFetched();
			if(!toPost || toPost.length==0) return;
			
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
					v.push(pg);
				}
			}
			
			//post
			var lab:LabGeneric;
			for(var key:Object in posts){
				lab=key as LabGeneric;
				if(lab){
					v=posts[key] as Vector.<Object>;
					if(v) postManual(v,lab);
				}
			}
		}
		
	}
}