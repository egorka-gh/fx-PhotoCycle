package com.photodispatcher.provider.preprocess{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.event.OrderBuildEvent;
	import com.photodispatcher.event.OrderBuildProgressEvent;
	import com.photodispatcher.factory.WebServiceBuilder;
	import com.photodispatcher.model.mysql.DbLatch;
	import com.photodispatcher.model.mysql.entities.Order;
	import com.photodispatcher.model.mysql.entities.OrderState;
	import com.photodispatcher.model.mysql.entities.Source;
	import com.photodispatcher.model.mysql.entities.SourceType;
	import com.photodispatcher.model.mysql.entities.StateLog;
	import com.photodispatcher.model.mysql.services.OrderService;
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
			latch.addLatch(orderService.loadByState(OrderState.PREPROCESS_WAITE, OrderState.PREPROCESS_CAPTURED);
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
						newItems.push(order);
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
					}else if(!faultOrder){
						faultOrder=order;
					}
				}
			}
			if(!order) order=faultOrder;
			if(!order) return;
			
			currOrder=order;
			if(currOrder.state!=OrderState.PREPROCESS_WAITE) currOrder.state=OrderState.PREPROCESS_WAITE;
			
			//TODO add manager start /stop ?
			getLock();
			//TODO restore order from filesystem
			//TODO remove currOrder from queue after complite
			
			//builder.build(order);
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
			OrderService.releasePreprocessLock(currOrder.id);
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
		}

		
		private function releaseOrder():void{
			if(!currOrder) return;
			var idx:int=queue.getItemIndex(currOrder);
			if(idx==-1) return;
			queue.removeItemAt(idx);
			currOrder=null;
		}


/********************************************************/		
		
		public function resync(orders:Array):void{
			if(!orders) return;
			
			var a:Array=[];
			var wOrder:Order;
			var idx:int;

			//resync resize orders
			if(queue.length>0) a=a.concat(queue);
			if(a.length>0){
				for each(wOrder in a){
					if(wOrder){
						idx=ArrayUtil.searchItemIdx('id',wOrder.id,orders);
						if(idx!=-1){
							//replace in sync array
							orders[idx]=wOrder;
						}else{
							//add to sync array
							orders.unshift(wOrder);
						}
					}
				}
			}
			
			//restart resizeErrOrders
			if(errOrders.length>0){
				for each(wOrder in errOrders){
					if(wOrder){
						idx=ArrayUtil.searchItemIdx('id',wOrder.id,orders);
						if(idx!=-1){
							//reset ??
							//replace in sync array
							orders[idx]=wOrder;
						}
					}
				}
				errOrders=[];
			}
			dispatchEvent(new Event('queueLenthChange'));
			//wake up
			startNext();
		}
		
		public function destroy():void{
			//TODO implement
		}
		
		private function resetOrder(order:Order):void{
			if(order && order.state!=OrderState.PREPROCESS_WAITE){
				order.state=OrderState.PREPROCESS_WAITE;
			}
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
			//builder internal error
			resetOrder(evt.order);
			var builder:OrderBuilderBase=evt.target as OrderBuilderBase;
			var msg:String='';
			if(builder){
				if(builder.type==OrderBuilderBase.TYPE_LOCAL){
					msg='Local builder: ';
				}else if(builder is OrderBuilderRemote){
					msg=(builder as OrderBuilderRemote).client.username+': ';
				}
			}
			lastError=msg+evt.err_msg;
			//TODO do something vs builder
			startNext();
		}
		private function onOrderPreprocessed(evt:OrderBuildEvent):void{
			//order complited
			//remove from queue
			var idx:int=-1;
			if(evt.order) idx=queue.indexOf(evt.order);
			if(idx!=-1) queue.splice(idx,1);
			if(evt.err<0){
				//completed vs error
				if(evt.order){
					//evt.order.resetPreprocess();
					errOrders.push(evt.order);
				}
			}else{
				dispatchEvent(evt.clone());
			}
			dispatchEvent(new Event('queueLenthChange'));
			startNext();
		}

	}
} 