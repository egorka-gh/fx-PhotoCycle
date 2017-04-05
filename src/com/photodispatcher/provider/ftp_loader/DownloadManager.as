package com.photodispatcher.provider.ftp_loader{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.event.ImageProviderEvent;
	import com.photodispatcher.model.mysql.DbLatch;
	import com.photodispatcher.model.mysql.entities.Order;
	import com.photodispatcher.model.mysql.entities.OrderLoad;
	import com.photodispatcher.model.mysql.entities.OrderState;
	import com.photodispatcher.model.mysql.entities.Source;
	import com.photodispatcher.model.mysql.entities.SourceType;
	import com.photodispatcher.model.mysql.entities.StateLog;
	import com.photodispatcher.model.mysql.entities.SubOrder;
	import com.photodispatcher.model.mysql.services.OrderLoadService;
	import com.photodispatcher.provider.check.CheckManager;
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
	
	/*
	* Top level load manager
	 manage full orders queue
	 create and manage loaders (4 each source) 
	*/
	//TODO refactor to base class
	[Event(name="dataChange", type="mx.events.FlexEvent")]
	public class DownloadManager extends EventDispatcher{

		[Bindable]
		public  var queue:ArrayCollection;
		[Bindable]
		public var lastLoadTime:Date;
		
		[Bindable('dataChange')]
		public function get queueLength():int{
			return queue?queue.length:0;
		}

		[Bindable]
		public var checker:CheckManager;
		protected var skipMD5:Boolean; 

		
		//private var writeOrders:Array=[];

		private function get bdService():OrderLoadService{
			return Tide.getInstance().getContext().byType(OrderLoadService,true) as OrderLoadService;
		}
		
		private var _servicesList:ArrayCollection=new ArrayCollection();
		[Bindable(event="servicesListChange")]
		public function get servicesList():ArrayCollection{
			return _servicesList;
		}
		
		private var services:Array;
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
						if(s.type==SourceType.SRC_FOTOKNIGA && s.ftpService){
							f= new DownloadQueueManager(s);
							f.addEventListener(ImageProviderEvent.ORDER_LOADED_EVENT,onOrderLoaded);
							services.push(f);
						}
					}
				}
			}
			
			_servicesList.source=services;
			dispatchEvent(new Event('servicesListChange'));
		}

		
		public function DownloadManager(){
			super(null);
			queue=new ArrayCollection();
			checker=new CheckManager();
			//listen
			checker.addEventListener(ImageProviderEvent.ORDER_LOADED_EVENT, onCheckerComplite)
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
			//writeOrders=[];
			autoLoadInterval=Context.getAttribute('syncInterval');
			skipMD5=Context.getAttribute('skipMD5');
			_isStarted=true;
			var f:DownloadQueueManager;
			for each(f in services){
				if(f) f.start();
			}
			checker.skipMD5=skipMD5;
			checker.isStarted=true;
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
			if(checker) checker.isStarted=false;
			//writeOrders=[];
		}
		
		public function reLoad():void{
			stopTimer();
			//TODO reset errors ?
			
			var latch:DbLatch= new DbLatch(true);
			latch.addEventListener(Event.COMPLETE,onloadFromDB);
			latch.addLatch(bdService.loadByState(OrderState.FTP_WAITE, OrderState.FTP_COMPLETE));
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
			var arr:Array =latch.lastDataArr;
			if(!arr){
				if(autoLoad) startTimer();
				return;
			}
			resync(arr);
			startTimer();
			dispatchEvent(new FlexEvent(FlexEvent.DATA_CHANGE));
		}

		private function resync(orders:Array):void{
			if(!orders) return;
			/*
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
			*/
			
			//TODO resync error orders??

			checker.sync(orders);

			var f:DownloadQueueManager;
			if(services){
				//resync services
				for each(f in services){
					if(f) f.reSync(orders);
				}
			}
			
			queue=new ArrayCollection(orders);
		}
		
		private function onOrderLoaded(e:ImageProviderEvent):void{ 
			//saveOrder(e.order, OrderState.FTP_CAPTURED);
			//order is loaded & saved vs state FTP_WAITE_CHECK
			checker.check(e.order);
		}

		private function onCheckerComplite(e:ImageProviderEvent):void{ 
			//saveOrder(e.order, OrderState.FTP_CHECK);
		}

		/*
		private function saveOrder(order:Order, fromState:int):void{
			if(!order) return;
			trace('Save order '+order.id+' State:'+order.state.toString());
			
			order.state_date=new Date();

			var idx:int=ArrayUtil.searchItemIdx('id',order.id,writeOrders);
			if(idx!=-1){
				writeOrders[idx]=order;
			}else{
				writeOrders.push(order);
			}
			
			var latch:DbLatch= new DbLatch();
			latch.addEventListener(Event.COMPLETE,onOrderSave);
			latch.addLatch(bdService.save(OrderLoad.fromOrder(order),fromState),order.id);
			latch.start();
		}
		private function onOrderSave(evt:Event):void{
			var latch:DbLatch= evt.target as DbLatch;
			if(latch){
				latch.removeEventListener(Event.COMPLETE,onOrderSave);
				var id:String= latch.lastTag;
				if(latch.complite){
					if(id){
						var idx:int=ArrayUtil.searchItemIdx('id',id,writeOrders);
						if(idx!=-1) writeOrders.splice(idx,1);
					}
					//if(writeOrders.length>0) saveOrder(writeOrders[0] as Order);	
				}else{
					if(latch.lastErrCode==OrderState.ERR_WRONG_STATE && id){
						StateLog.log(OrderState.ERR_WRONG_STATE,id,'',latch.lastError);
					}
				}
			}
		}
		*/

	}
}