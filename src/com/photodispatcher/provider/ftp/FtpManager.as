package com.photodispatcher.provider.ftp{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.event.AsyncSQLEvent;
	import com.photodispatcher.event.ImageProviderEvent;
	import com.photodispatcher.event.OrderBuildEvent;
	import com.photodispatcher.event.OrderLoadedEvent;
	import com.photodispatcher.event.OrderPreprocessEvent;
	import com.photodispatcher.factory.SuborderBuilder;
	import com.photodispatcher.model.mysql.DbLatch;
	import com.photodispatcher.model.mysql.entities.Order;
	import com.photodispatcher.model.mysql.entities.OrderState;
	import com.photodispatcher.model.mysql.entities.PrintGroup;
	import com.photodispatcher.model.mysql.entities.Source;
	import com.photodispatcher.model.mysql.entities.SourceType;
	import com.photodispatcher.model.mysql.entities.SubOrder;
	import com.photodispatcher.model.mysql.services.OrderService;
	import com.photodispatcher.provider.preprocess.CaptionSetter;
	import com.photodispatcher.provider.preprocess.PreprocessManager;
	import com.photodispatcher.util.ArrayUtil;
	import com.photodispatcher.util.StrUtil;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.filesystem.File;
	
	import mx.collections.ArrayCollection;
	
	import org.granite.tide.Tide;
	
	public class FtpManager extends EventDispatcher{

		private var _preprocessManager:PreprocessManager;
		
		/*
		[Bindable]
		public var writeOrdersList:ArrayCollection;
		[Bindable]
		public var isWriting:Boolean=false;
		*/
		private var writeOrders:Array=[];

		private var _servicesList:ArrayCollection=new ArrayCollection();
		[Bindable(event="servicesListChange")]
		public function get servicesList():ArrayCollection{
			return _servicesList;
		}
		
		[Bindable]
		public var remoteLoadManager:LoadHelpersManager;
		
		private var _sources:Array;
		public function get sources():Array{
			return _sources;
		}
		public function set sources(value:Array):void{
			//cleanup / remove listeners for old
			_sources = value;
			//var f:FtpService;
			var f:QueueManager
			if(services && services.length>0){
				for each (f in services){
					if(f){
						if(f.isStarted) f.stop(); 
						//f.removeEventListener(OrderLoadedEvent.ORDER_LOADED_EVENT,onOrderLoaded);
						f.removeEventListener(ImageProviderEvent.ORDER_LOADED_EVENT,onOrderLoaded);
					}
				}
			}
			services=[];
			if(_sources){
				var s:Source;
				for each(s in sources){
					if(s && s.online){
						f=null;
						if(s.type==SourceType.SRC_FBOOK_MANUAL){
							f= new QueueManagerFBManual(s);
						}else if(s.ftpService){
							f= new QueueManager(s);
						}
						if(f){
							f.addEventListener(ImageProviderEvent.ORDER_LOADED_EVENT,onOrderLoaded);
							services.push(f);
						}
					}
				}
			}
			
			//create remote helpers manager
			if(!remoteLoadManager){
				remoteLoadManager= new LoadHelpersManager();
				remoteLoadManager.addEventListener(ImageProviderEvent.ORDER_LOADED_EVENT,onOrderLoaded);
			}
			remoteLoadManager.localQueues=services;
			services.unshift(remoteLoadManager);
			
			_servicesList.source=services;
			dispatchEvent(new Event('servicesListChange'));
		}

		
		private var services:Array;
		
		public function FtpManager(){
			super(null);
			/*
			writeOrdersList=new ArrayCollection();
			writeOrdersList.source=writeOrders;
			*/
		}
		
		
		public function set preprocessManager(manager:PreprocessManager):void{
			if(_preprocessManager){
				_preprocessManager.removeEventListener(OrderBuildEvent.ORDER_PREPROCESSED_EVENT, onOrderPreprocessed);
			}
			_preprocessManager=manager;	
			if(_preprocessManager){
				_preprocessManager.addEventListener(OrderBuildEvent.ORDER_PREPROCESSED_EVENT, onOrderPreprocessed);
			}
		}
		public function get preprocessManager():PreprocessManager{
			return _preprocessManager;	
		}
		
		public function resync(orders:Array):void{
			if(!orders) return;
			//resync write orders
			var a:Array=new Array();
			if(writeOrders.length>0) a=a.concat(writeOrders);
			var order:Order;
			var wOrder:Order;
			var idx:int;
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
			preprocessManager.resync(orders);
			
			var f:QueueManager;
			if(services){
				//resync services
				for each(f in services){
					if(f) f.reSync(orders);
				}
			}
			//flushWriteQueue();
		}
		
		public function start(resetErrors:Boolean=false):void{
			if(!services || services.length==0) return;
			//var f:FtpService;
			var f:QueueManager;
			for each(f in services){
				if(f) f.start(resetErrors);
			}
		}

		public function stop():void{
			if(!services || services.length==0) return;
			var f:QueueManager;
			for each(f in services){
				if(f) f.stop();
			}
			//flushWriteQueue();
		}
		
		private function onOrderLoaded(e:ImageProviderEvent):void{ //(e:OrderLoadedEvent):void{
			var source:Source=ArrayUtil.searchItem('id',e.order.source,sources) as Source;
			var dstFolder:String=source.getWrkFolder();
			var order:Order=e.order;
			try{
				CaptionSetter.restoreFileCaption(order,dstFolder);
			}catch(err:Error){
			}
			//resize
			preprocessOrder(order);
		}

		private function preprocessOrder(order:Order):void{
			//chek if order skipped
			var minState:int=OrderState.SKIPPED;
			var pg:PrintGroup;
			var so:SubOrder;
			if(order.printGroups){
				for each(pg in order.printGroups) minState=Math.min(minState,pg.state);
			}
			if(order.suborders){
				for each(so in order.suborders) minState=Math.min(minState,so.state);
			}
			if(minState<OrderState.CANCELED){
				preprocessManager.build(order);
			}else{
				order.state=OrderState.SKIPPED;
				saveOrder(order);
			}
		}
		private function onOrderPreprocessed(evt:OrderBuildEvent):void{
			saveOrder(evt.order);
		}

		private function saveOrder(order:Order):void{
			//TODO set order state
			if(order.state<OrderState.CANCELED) order.state=order.is_preload?OrderState.PRN_WAITE_ORDER_STATE:OrderState.PRN_WAITE;
			if(order.hasSuborders){
				for each(var so:SubOrder in order.suborders) if(so.state<OrderState.CANCELED) so.state=order.state;
			}
			if(order.printGroups){
				for each(var pg:PrintGroup in order.printGroups) if(pg.state<OrderState.CANCELED) pg.state=order.state;
			}
			writeOrders.push(order);
			var svc:OrderService=Tide.getInstance().getContext().byType(OrderService,true) as OrderService;
			var latch:DbLatch= new DbLatch();
			latch.addEventListener(Event.COMPLETE,onOrderSave);
			latch.addLatch(svc.fillUpOrder(order),order.id);
			latch.start();
		}
		private function onOrderSave(evt:Event):void{
			var latch:DbLatch= evt.target as DbLatch;
			if(latch){
				latch.removeEventListener(Event.COMPLETE,onOrderSave);
				var id:String= latch.lastTag;
				if(id){
					var idx:int=ArrayUtil.searchItemIdx('id',id,writeOrders);
					if(idx!=-1) writeOrders.splice(idx,1);
				}
			}
		}

	}
}