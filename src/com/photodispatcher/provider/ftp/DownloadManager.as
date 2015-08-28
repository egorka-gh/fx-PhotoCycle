package com.photodispatcher.provider.ftp{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.event.ImageProviderEvent;
	import com.photodispatcher.model.mysql.DbLatch;
	import com.photodispatcher.model.mysql.entities.Order;
	import com.photodispatcher.model.mysql.entities.OrderState;
	import com.photodispatcher.model.mysql.entities.Source;
	import com.photodispatcher.model.mysql.entities.SourceType;
	import com.photodispatcher.model.mysql.entities.SubOrder;
	import com.photodispatcher.model.mysql.services.OrderService;
	import com.photodispatcher.provider.fbook.download.FBookDownloadManager;
	import com.photodispatcher.util.ArrayUtil;
	import com.photodispatcher.util.StrUtil;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.TimerEvent;
	import flash.filesystem.File;
	import flash.utils.Timer;
	
	import mx.collections.ArrayCollection;
	import mx.events.FlexEvent;
	
	import org.granite.tide.Tide;
	
	[Event(name="dataChange", type="mx.events.FlexEvent")]
	public class DownloadManager extends EventDispatcher{

		[Bindable]
		public  var queue:Array;
		[Bindable]
		public var lastLoadTime:Date;

		private var writeOrders:Array=[];

		private var _servicesList:ArrayCollection=new ArrayCollection();
		[Bindable(event="servicesListChange")]
		public function get servicesList():ArrayCollection{
			return _servicesList;
		}
		
		private var _sources:Array;
		public function get sources():Array{
			return _sources;
		}
		public function set sources(value:Array):void{
			//cleanup / remove listeners for old
			_sources = value;
			var f:DownloadQueueManager
			if(services && services.length>0){
				for each (f in services){
					if(f){
						if(f.isStarted) f.stop(); 
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
							f= new DownloadQueueManager(s);
						}
						if(f){
							f.addEventListener(ImageProviderEvent.ORDER_LOADED_EVENT,onOrderLoaded);
							services.push(f);
						}
					}
				}
			}
			
			_servicesList.source=services;
			dispatchEvent(new Event('servicesListChange'));
		}

		
		private var services:Array;
		
		public function DownloadManager(){
			super(null);
			queue=[];
		}
		
		private var timer:Timer;
		
		private var _autoLoadInterval:int=10; //min
		public function get autoLoadInterval():int{
			return _autoLoadInterval;
		}
		public function set autoLoadInterval(value:int):void{
			if(value<=0){
				autoLoad=false;
				_autoLoadInterval=10;
			}else{
				_autoLoadInterval = value;
			}
			if(timer) timer.delay=_autoLoadInterval*60*1000;
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
				timer= new Timer(autoLoadInterval*60*1000);
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
			if(!services || services.length==0) return;
			autoLoadInterval=Context.getAttribute('syncInterval');
			FBookDownloadManager.cacheClipart=Context.getAttribute('cacheClipart');
			_isStarted=true;
			var f:DownloadQueueManager;
			for each(f in services){
				if(f) f.start();
			}
			reLoad();
		}
		
		private function stop():void{
			_isStarted=false;
			stopTimer();
			
			if(!services || services.length==0) return;
			var f:DownloadQueueManager;
			for each(f in services){
				if(f) f.stop();
			}
		}
		
		public function clearCache():void{
			if(!services || services.length==0) return;
			FBookDownloadManager.cacheClipart=false;
			var f:DownloadQueueManager;
			for each(f in services){
				if(f) f.clearCache();
			}
			FBookDownloadManager.cacheClipart=Context.getAttribute('cacheClipart');
		}

		public function reLoad():void{
			stopTimer();
			//TODO reset errors ?
			
			var svc:OrderService=Tide.getInstance().getContext().byType(OrderService,true) as OrderService;
			var latch:DbLatch= new DbLatch(true);
			latch.addEventListener(Event.COMPLETE,onloadFromDB);
			latch.addLatch(svc.loadByState(OrderState.FTP_WAITE, OrderState.FTP_COMPLETE+1));
			latch.start();
		}

		private function onloadFromDB(evt:Event):void{
			var latch:DbLatch= evt.target as DbLatch;
			if(latch) latch.removeEventListener(Event.COMPLETE,onloadFromDB);
			lastLoadTime=new Date();
			if(!latch || !latch.complite){
				if(autoLoad) startTimer();
				return;
			}
			queue=latch.lastDataArr;
			if(!queue){
				if(autoLoad) startTimer();
				return;
			}
			resync(queue);
			startTimer();
			dispatchEvent(new FlexEvent(FlexEvent.DATA_CHANGE));
		}

		private function resync(orders:Array):void{
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
			
			var f:DownloadQueueManager;
			if(services){
				//resync services
				for each(f in services){
					if(f) f.reSync(orders);
				}
			}
		}
		
		private function onOrderLoaded(e:ImageProviderEvent):void{ //(e:OrderLoadedEvent):void{
			var source:Source=ArrayUtil.searchItem('id',e.order.source,sources) as Source;
			var dstFolder:String=source.getWrkFolder();
			var order:Order=e.order;
			saveOrder(order);
		}

		private function saveOrder(order:Order):void{
			
			if(order.state<OrderState.CANCELED_SYNC){
				if(order.forward_state>0){
					order.state=order.forward_state;
				}else{
					order.state=OrderState.PREPROCESS_WAITE;
				}
			}
			trace('Save order '+order.id+' State:'+order.state.toString()+'('+order.forward_state.toString()+')');
			
			order.state_date=new Date();
			if(order.hasSuborders){
				for each(var so:SubOrder in order.suborders) if(so.state<OrderState.CANCELED_SYNC) so.state=order.state;
			}
			
			writeOrders.push(order);
			var svc:OrderService=Tide.getInstance().getContext().byType(OrderService,true) as OrderService;
			var latch:DbLatch= new DbLatch();
			latch.debugName='Заказ "'+order.id+'" (saveVsSuborders)';
			latch.addEventListener(Event.COMPLETE,onOrderSave);
			latch.addLatch(svc.saveVsSuborders(order),order.id);
			latch.start();
		}
		private function onOrderSave(evt:Event):void{
			var latch:DbLatch= evt.target as DbLatch;
			if(latch){
				latch.removeEventListener(Event.COMPLETE,onOrderSave);
				var id:String= latch.lastTag;
				if(id){
					var idx:int=ArrayUtil.searchItemIdx('id',id,writeOrders);
					var order:Order;					
					if(idx!=-1){
						order= writeOrders[idx] as Order;
						writeOrders.splice(idx,1);
					}
				}
			}
		}

	}
}