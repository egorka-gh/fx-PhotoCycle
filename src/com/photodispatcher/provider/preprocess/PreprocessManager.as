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
	import flash.sampler.NewObjectSample;
	import flash.utils.Dictionary;
	
	import mx.collections.ArrayCollection;
	import mx.controls.Alert;
	
	import org.granite.tide.Tide;

	[Event(name="orderPreprocessed", type="com.photodispatcher.event.OrderBuildEvent")]
	public class PreprocessManager extends EventDispatcher{

		/*
		[Bindable(event="queueLenthChange")]
		public function get queueLenth():int{
			return queue.length;
		}

		[Bindable(event="queueLenthChange")]
		public function get errorOrdersLenth():int{
			return errOrders.length;
		}

		[Bindable(event="remoteBuildersCountChange")]
		public function get remoteBuildersCount():int{
			var result:int=0;
			if(buildesMap){
				var b:OrderBuilderBase;
				for each(b in buildesMap){
					if(b && b.type!=OrderBuilderBase.TYPE_LOCAL) result++;
				}
			}
			return result;
		}

		[Bindable]
		public  var orderList:ArrayCollection=new ArrayCollection();
		
		private function refreshOrderList(e:Event):void{
			//orderList.source=queue.concat(errOrders);
			orderList.source=queue.concat();
			orderList.refresh();
			
		}
		*/

		public static const WEB_ERRORS_LIMIT:int=3;

		[Bindable]
		public var lastError:String='';
		[Bindable]
		public var progressCaption:String='';
		
		public var builder:OrderBuilderLocal;

		//private var buildesMap:Dictionary;
		[Bindable]
		public  var queue:ArrayCollection;
		//private var errOrders:Array=[];
		private var webErrCounter:int=0;
		
		public function PreprocessManager(){
			super();
			queue= new ArrayCollection();
			//addEventListener('queueLenthChange',refreshOrderList);
		}
		
		public function init():void{
			if(builder) destroyBuilder(builder);
			builder= new OrderBuilderLocal();
			listenBuilder(builder);
		}
		
		private function get orderService():OrderService{
			return Tide.getInstance().getContext().byType(OrderService,true) as OrderService;
		}
		
		public function addFromDB():void{
			var latch:DbLatch= new DbLatch(true);
			latch.addEventListener(Event.COMPLETE,onloadFromDB);
			latch.addLatch(orderService.loadByState(OrderState.PREPROCESS_WAITE, OrderState.PREPROCESS_CAPTURED));
			latch.start();
		}
		private function onloadFromDB(evt:Event):void{
			var latch:DbLatch= evt.target as DbLatch;
			if(latch) latch.removeEventListener(Event.COMPLETE,onloadFromDB);
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
			startNext();
		}

		private var currOrder:Order;

		private function startNext():void{
			if(currOrder) return;
			if(builder.isBusy) return;
			if(queue.length==0) return;
			
			//get order
			var o:Order;
			var order:Order;
			var faultOrder:Order;
			
			for each(o in queue){
				if(o){
					if(o.state==OrderState.PREPROCESS_WAITE){
						order=o;
						break;
					}else if(!faultOrder && o.state<0 && o.state!=OrderState.ERR_PREPROCESS){
						faultOrder=o;
					}
				}
			}
			if(!order) order=faultOrder;
			if(!order) return;
			
			currOrder=order;
			if(currOrder.state!=OrderState.PREPROCESS_WAITE) currOrder.state=OrderState.PREPROCESS_WAITE;
			
			//TODO add manager start /stop ?
			getLock();
		}

		private function getLock():void{
			if(!currOrder) return;
			var latch:DbLatch=OrderService.getPreprocessLock(currOrder.id);
			latch.addEventListener(Event.COMPLETE,ongetLock);
			latch.start();
		}
		private function ongetLock(evt:Event):void{
			var latch:DbLatch= evt.target as DbLatch;
			if(latch) latch.removeEventListener(Event.COMPLETE,ongetLock);
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
			//OrderService.releasePreprocessLock(currOrder.id);
		}

		
		private function checkWebState():void{
			if(!currOrder) return;
			trace('PreprocessManager.checkQueue web request '+currOrder.ftp_folder);
			//check state on site
			currOrder.state=OrderState.PREPROCESS_WEB_CHECK;
			var source:Source= Context.getSource(currOrder.source);
			if(!source) return;
			var webService:BaseWeb=WebServiceBuilder.build(source);
			if(!webService) return;
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
				releaseLock();
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
						releaseLock();
						currOrder= null;
						return;
					}
					if(currOrder.production!=Context.getProduction()){
						trace('PreprocessManager.getOrderHandle; wrong order production; cancel order '+currOrder.id);
						currOrder.state=OrderState.CANCELED_PRODUCTION;
						releaseLock();
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
				currOrder.state=OrderState.CANCELED;
				releaseLock();
				releaseOrder();
				currOrder= null;
				startNext();
			}
		}

		
		private function fillFromDb():void{
			if(!currOrder) return;
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
				releaseLock();
				currOrder= null;
				startNext();
				return;
			}

			//forvard
			//capturestate
			currOrder.state=OrderState.PREPROCESS_CAPTURED;
			latch= new DbLatch(true);
			latch.addEventListener(Event.COMPLETE,oncaptureState);
			latch.addLatch(orderService.captureState(currOrder));
		}
		private function oncaptureState(evt:Event):void{
			var latch:DbLatch= evt.target as DbLatch;
			if(latch){
				latch.removeEventListener(Event.COMPLETE,oncaptureState);
				if (latch.complite && latch.resultCode==OrderState.PREPROCESS_CAPTURED){
					//forvard
					//build
					builder.build(currOrder);
					//TODO remove currOrder from queue after complite
				}else{
					trace('PreprocessManager.captureState: db error '+latch.lastError);
					lastError='Заказ: '+currOrder.id+' блокирован другим процессом '+latch.lastError;
					releaseLock();
					currOrder.state= OrderState.ERR_LOCK_FAULT;
					currOrder=null;
					startNext();
				}
			}
		}

		private function releaseOrder():void{
			if(!currOrder) return;
			var idx:int=queue.getItemIndex(currOrder);
			if(idx==-1) return;
			queue.removeItemAt(idx);
			currOrder=null;
		}

		public function start():void{
			//TODO implement
		}
		public function stop():void{
			//TODO implement
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
			currOrder.state=OrderState.ERR_PREPROCESS;
			saveOrder(currOrder);
			currOrder=null;
			startNext();
		}
		private function onOrderPreprocessed(evt:OrderBuildEvent):void{
			//order complited
			//remove from queue
			if(evt.err<0){
				//completed vs error
				currOrder.state=OrderState.ERR_PREPROCESS;
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
		}

	}
} 