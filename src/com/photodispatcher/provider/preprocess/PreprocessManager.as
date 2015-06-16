package com.photodispatcher.provider.preprocess{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.event.OrderBuildEvent;
	import com.photodispatcher.event.OrderBuildProgressEvent;
	import com.photodispatcher.factory.OrderBuilder;
	import com.photodispatcher.factory.WebServiceBuilder;
	import com.photodispatcher.model.mysql.DbLatch;
	import com.photodispatcher.model.mysql.entities.Order;
	import com.photodispatcher.model.mysql.entities.OrderState;
	import com.photodispatcher.model.mysql.entities.Source;
	import com.photodispatcher.model.mysql.entities.SourceType;
	import com.photodispatcher.model.mysql.entities.StateLog;
	import com.photodispatcher.model.mysql.entities.SubOrder;
	import com.photodispatcher.model.mysql.services.OrderService;
	import com.photodispatcher.model.mysql.services.OrderStateService;
	import com.photodispatcher.service.web.BaseWeb;
	import com.photodispatcher.util.ArrayUtil;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.ProgressEvent;
	import flash.events.TimerEvent;
	import flash.sampler.NewObjectSample;
	import flash.utils.Dictionary;
	import flash.utils.Timer;
	
	import mx.collections.ArrayCollection;
	import mx.controls.Alert;
	import mx.events.FlexEvent;
	
	import org.granite.tide.Tide;

	[Event(name="orderPreprocessed", type="com.photodispatcher.event.OrderBuildEvent")]
	[Event(name="dataChange", type="mx.events.FlexEvent")]
	public class PreprocessManager extends EventDispatcher{

		public static const WEB_ERRORS_LIMIT:int=3;

		[Bindable]
		public var lastError:String='';
		[Bindable]
		public var progressCaption:String='';
		
		public var builder:OrderBuilderLocal;

		[Bindable]
		public  var queue:ArrayCollection;

		private var webErrCounter:int=0;
		
		public function PreprocessManager(){
			super();
			queue= new ArrayCollection();
			builder= new OrderBuilderLocal();
			listenBuilder(builder);
		}
		
		private function get orderService():OrderService{
			return Tide.getInstance().getContext().byType(OrderService,true) as OrderService;
		}
		
		public function reLoad():void{
			stopTimer();
			//reset errors
			for each(var o:Order in queue.source){
				if(o && o.state<0) o.state=OrderState.PREPROCESS_WAITE;
			}

			var latch:DbLatch= new DbLatch(true);
			latch.addEventListener(Event.COMPLETE,onloadFromDB);
			latch.addLatch(orderService.loadByState(OrderState.PREPROCESS_WAITE, OrderState.PREPROCESS_CAPTURED));
			latch.start();
		}
		private function onloadFromDB(evt:Event):void{
			var latch:DbLatch= evt.target as DbLatch;
			if(latch) latch.removeEventListener(Event.COMPLETE,onloadFromDB);
			if(autoLoad) startTimer();
			if(!latch || !latch.complite) return;
			var toAdd:Array=latch.lastDataArr;
			if(!toAdd || toAdd.length==0) return;
			var newItems:Array=[];
			if(currOrder) newItems.push(currOrder);
			for each(var order:Order in toAdd){
				if(order){
					if(!currOrder || order.id!=currOrder.id){
						if(order.state!=OrderState.PREPROCESS_WAITE) order.state=OrderState.PREPROCESS_WAITE;
						var oldOrder:Order=ArrayUtil.searchItem('id',order.id,queue.source) as Order;
						if(oldOrder){
							newItems.push(oldOrder);
						}else{
							newItems.push(order);
						}
					}
				}
			}
			queue = new ArrayCollection(newItems);
			webErrCounter=0;
			dispatchEvent(new FlexEvent(FlexEvent.DATA_CHANGE));
			startNext();
		}

		private var currOrder:Order;

		private function startNext():void{
			progressCaption='';
			if(!isStarted){
				currOrder=null;
				return;
			}
			if(currOrder) return;
			if(builder.isBusy) return;
			if(queue.source.length==0) return;
			
			//get order
			var o:Order;
			var order:Order;
			//var faultOrder:Order;
			
			for each(o in queue.source){
				if(o){
					if(o.state==OrderState.PREPROCESS_FORVARD){
						order=o;
						break;
					}else if(o.state==OrderState.PREPROCESS_WAITE){
						if(!order) order=o;
						/*
					}else if(!faultOrder && o.state<0 && o.state!=OrderState.ERR_PREPROCESS && o.state!=OrderState.ERR_LOCK_FAULT){
						faultOrder=o;
						*/
					}
				}
			}
			//if(!order) order=faultOrder;
			if(!order) return;
			
			currOrder=order;
			if(currOrder.state!=OrderState.PREPROCESS_WAITE) currOrder.state=OrderState.PREPROCESS_WAITE;
			
			getLock();
		}

		private function getLock():void{
			if(!isStarted) currOrder=null;
			if(!currOrder) return;
			progressCaption='Захват на обработку '+currOrder.id;
			var latch:DbLatch=OrderService.getPreprocessLock(currOrder.id);
			latch.addEventListener(Event.COMPLETE,ongetLock);
			latch.start();
		}
		private function ongetLock(evt:Event):void{
			var latch:DbLatch= evt.target as DbLatch;
			latch.removeEventListener(Event.COMPLETE,ongetLock);
			if(!currOrder) return;
			if(latch.resultCode>0){
				checkWebState();
			}else{
				lastError='Заказ '+currOrder.id+' обрабатывается на другой станции';
				currOrder.state= OrderState.ERR_LOCK_FAULT;
				currOrder=null;
				startNext();
			}
		}

		private function releaseLock():void{
			if(!currOrder) return;
			//TODO can release another's lock
			OrderService.releasePreprocessLock(currOrder.id);
		}

		
		private function checkWebState():void{
			if(!currOrder) return;
			progressCaption='Проверка Web '+currOrder.id;
			trace('PreprocessManager.checkQueue web request '+currOrder.ftp_folder);
			//check state on site
			var source:Source= Context.getSource(currOrder.source);
			if(!source) return;
			var webService:BaseWeb=WebServiceBuilder.build(source);
			if(!webService) return;
			currOrder.state=OrderState.PREPROCESS_WEB_CHECK;
			webService.addEventListener(Event.COMPLETE,getOrderHandle);
			webService.getOrder(currOrder);
		}
		
		private function getOrderHandle(e:Event):void{
			var pw:BaseWeb=e.target as BaseWeb;
			pw.removeEventListener(Event.COMPLETE,getOrderHandle);
			if(!currOrder) return;
			
			if(pw.hasError){
				webErrCounter++;
				trace('getOrderHandle web check order err: '+pw.errMesage);
				lastError='Заказ '+currOrder.id+'. Ошибка проверки на сайте: '+pw.errMesage;
				currOrder.state=OrderState.ERR_WEB;
				StateLog.log(OrderState.ERR_WEB,currOrder.id,'','Ошибка проверки на сайте: '+pw.errMesage);
				//releaseLock();
				currOrder= null;
				//to prevent cycle web check when network error or offline
				if(webErrCounter<WEB_ERRORS_LIMIT) startNext();
				return;
			}
			webErrCounter=0;
			if(pw.isValidLastOrder(true)){
				//check production
				if(pw.source.type==SourceType.SRC_FOTOKNIGA && Context.getProduction()!=Context.PRODUCTION_ANY){
					currOrder.production=pw.getLastOrder().production;
					if(currOrder.production==Context.PRODUCTION_NOT_SET){
						trace('PreprocessManager.getOrderHandle; order production not set '+currOrder.id);
						currOrder.state=OrderState.ERR_PRODUCTION_NOT_SET;
						//releaseLock();
						currOrder= null;
						return;
					}
					if(currOrder.production!=Context.getProduction()){
						trace('PreprocessManager.getOrderHandle; wrong order production; cancel order '+currOrder.id);
						currOrder.state=OrderState.CANCELED_PRODUCTION;
						//releaseLock();
						currOrder= null;
						return;
					}
				}
				trace('PreprocessManager.getOrderHandle: web check Ok'+currOrder.ftp_folder);
				currOrder.state=OrderState.PREPROCESS_WEB_OK;
				//fill extra info
				if(pw.getLastOrder().extraInfo) currOrder.extraInfo=pw.getLastOrder().extraInfo;
				
				//forvard
				fillFromDb();
			}else{
				//mark as canceled
				trace('PreprocessManager.getOrderHandle; web check fault; order canceled '+currOrder.ftp_folder);
				currOrder.state=OrderState.CANCELED_SYNC;
				releaseLock();
				releaseOrder();
				currOrder= null;
				startNext();
			}
		}

		
		private function fillFromDb():void{
			if(!currOrder) return;
			progressCaption='Загрузка из БД '+currOrder.id;
			var latch:DbLatch=new DbLatch(true);
			latch.addEventListener(Event.COMPLETE,onfillFromDb);
			latch.addLatch(orderService.loadOrderVsChilds(currOrder.id));
			latch.start();
		}
		private function onfillFromDb(evt:Event):void{
			var latch:DbLatch= evt.target as DbLatch;
			var dbOrder:Order;
			if(latch){
				latch.removeEventListener(Event.COMPLETE,onfillFromDb);
				if (latch.complite){
					dbOrder=latch.lastDataItem as Order;
				}else{
					trace('PreprocessManager.fillFromDb: db error '+latch.lastError);
					lastError='Ошибка базы данных заказ: '+currOrder.id+'. '+latch.lastError;
				}
			}
			if(!currOrder) return;
			if(!dbOrder){
				currOrder.state= OrderState.ERR_READ_LOCK;
				releaseLock();
				currOrder= null;
				startNext();
				return;
			}
			
			currOrder.suborders=dbOrder.suborders;
			//forvard
			//restore from filesystem
			if(OrderBuilder.restoreFromFilesystem(currOrder)<0){
				//releaseLock();
				currOrder= null;
				startNext();
				return;
			}

			//forvard
			//capturestate
			progressCaption='Блокировка на обработку '+currOrder.id;
			currOrder.state=OrderState.PREPROCESS_CAPTURED;
			latch= new DbLatch(true);
			latch.addEventListener(Event.COMPLETE,oncaptureState);
			latch.addLatch(orderService.captureState(currOrder));
			latch.start();
		}
		private function oncaptureState(evt:Event):void{
			releaseLock();
			var latch:DbLatch= evt.target as DbLatch;
			if(latch){
				latch.removeEventListener(Event.COMPLETE,oncaptureState);
				if(!currOrder) return;
				if (latch.complite && latch.resultCode==OrderState.PREPROCESS_CAPTURED){
					//forvard
					//build
					builder.build(currOrder);
					//TODO remove currOrder from queue after complite
				}else{
					trace('PreprocessManager.captureState: db error '+latch.lastError);
					lastError='Заказ: '+currOrder.id+' блокирован другим процессом '+latch.lastError;
					currOrder.state= OrderState.ERR_LOCK_FAULT;
					currOrder=null;
					startNext();
				}
			}
		}

		private function releaseOrder():void{
			if(!currOrder) return;
			var idx:int=ArrayUtil.searchItemIdx('id',currOrder.id, queue.source);
			if(idx==-1) return;
			queue.source.splice(idx,1);
			queue.refresh();
			currOrder=null;
		}

		private var timer:Timer;

		private var _autoLoadInterval:int=10*60*1000;
		public function get autoLoadInterval():int{
			return _autoLoadInterval;
		}
		public function set autoLoadInterval(value:int):void{
			if(value<=0){
				autoLoad=false;
				_autoLoadInterval=10*60*1000;
			}else{
				_autoLoadInterval = value;
			}
			if(timer) timer.delay=_autoLoadInterval;
		}

		
		private var _autoLoad:Boolean;
		public function set autoLoad(load:Boolean):void{
			if(!load) stopTimer();
			_autoLoad=load;
			if(_autoLoad) startTimer();
		}
		public function get autoLoad():Boolean{
			return _autoLoad;
		}
		
		private function startTimer():void{
			if(!timer){
				timer= new Timer(autoLoadInterval);
				timer.addEventListener(TimerEvent.TIMER, onTimer);
			}
			if(isStarted) timer.start();
		}
		private function stopTimer():void{
			if(timer) timer.stop();
		}
		private function onTimer(evt:TimerEvent):void{
			reLoad();
		}

		private var _isStarted:Boolean;
		[Bindable]
		public function get isStarted():Boolean{
			return _isStarted;
		}
		public function set isStarted(value:Boolean):void{
			if(value){ 
				start();
			}else{
				stop();
			}
			_isStarted = value;
		}

		
		private function start():void{
			if(_isStarted) return;
			_isStarted=true;
			autoLoadInterval=Context.getAttribute('syncInterval');
			reLoad();
		}
		
		private function stop():void{
			_isStarted=false;
			stopTimer();
			progressCaption='';
			if(currOrder){ 
				currOrder.state=OrderState.PREPROCESS_WAITE;
				releaseLock();
				if(currOrder.state < OrderState.PREPROCESS_CAPTURED){
					currOrder=null;
				}else{
					builder.stop();
					//unlock
					var latch:DbLatch= new DbLatch(true);
					//latch.addEventListener(Event.COMPLETE,onOrderSave);
					latch.addLatch(orderService.setState(currOrder));
					latch.start();
				}
			}
			//reset states
			for each (var order:Order in queue.source){
				if(order){
					if(!currOrder || (currOrder.id!=order.id)){
						if(order.state!=OrderState.PREPROCESS_WAITE && order.state!=OrderState.PREPROCESS_FORVARD ){
							order.state=OrderState.PREPROCESS_WAITE;
						}
					}
				}
			}

		}

		public function destroy():void{
			//TODO implement
		}
		
		private function listenBuilder(builder:OrderBuilderBase):void{
			if(!builder) return;
			builder.addEventListener(OrderBuildEvent.BUILDER_ERROR_EVENT,onBuilderError);
			builder.addEventListener(OrderBuildEvent.ORDER_PREPROCESSED_EVENT, onOrderPreprocessed);
			builder.addEventListener(ProgressEvent.PROGRESS, onPreprocessProgress);
		}
		private function destroyBuilder(builder:OrderBuilderBase):void{
			if(!builder) return;
			builder.removeEventListener(OrderBuildEvent.BUILDER_ERROR_EVENT,onBuilderError);
			builder.removeEventListener(OrderBuildEvent.ORDER_PREPROCESSED_EVENT, onOrderPreprocessed);
			builder.removeEventListener(ProgressEvent.PROGRESS, onPreprocessProgress);
		}
		
		private function onPreprocessProgress(e:OrderBuildProgressEvent):void{
			progressCaption=e.caption;
			dispatchEvent(e.clone());
		}
		private function onBuilderError(evt:OrderBuildEvent):void{
			//builder error
			lastError=evt.err_msg;
			if(!currOrder) return;
			currOrder.state=OrderState.PREPROCESS_INCOMPLETE;
			saveOrder(currOrder);
			currOrder=null;
			startNext();
		}
		private function onOrderPreprocessed(evt:OrderBuildEvent):void{
			if(!currOrder) return;
			//order complited
			//remove from queue
			if(evt.err<0){
				//completed vs error
				currOrder.state=OrderState.PREPROCESS_INCOMPLETE;
			}else{
				if(currOrder.is_preload){
					currOrder.state=OrderState.PRN_WAITE_ORDER_STATE;
				}else{
					currOrder.state=OrderState.PRN_WAITE;
				}
			}
			//clean
			if(currOrder.hasSuborders){
				for each(var so:SubOrder in currOrder.suborders) so.destroyChilds();
			}
			saveOrder(currOrder);
			releaseOrder();
			startNext();
		}
		
		private function saveOrder(order:Order):void{
			var latch:DbLatch= new DbLatch();
			latch.addEventListener(Event.COMPLETE,onsaveOrder);
			if(order.state<0){
				//save error state
				latch.addLatch(orderService.setState(order));
			}else{
				//persist
				latch.addLatch(orderService.fillUpOrder(order), order.id);
			}
			latch.start();
		}
		private function onsaveOrder(evt:Event):void{
			var latch:DbLatch= evt.target as DbLatch;
			if(latch){
				latch.removeEventListener(Event.COMPLETE,onsaveOrder);
				var id:String= latch.lastTag;
				if (latch.complite && id){
					//set extra state
					//if(!order || order.state!=OrderState.PRN_WAITE) return;
					var svc:OrderStateService=Tide.getInstance().getContext().byType(OrderStateService,true) as OrderStateService;
					latch=new DbLatch();
					//latch.addEventListener(Event.COMPLETE,onCompleteOrder);
					//set PRN_WAITE extra state 
					latch.addLatch(svc.extraStateFix(id, OrderState.PRN_WAITE, new Date()));
					latch.start();
				}
			}
			dispatchEvent(new FlexEvent(FlexEvent.DATA_CHANGE));
		}

	}
} 