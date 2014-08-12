package com.photodispatcher.provider{
	import com.photodispatcher.event.ImageProviderEvent;
	import com.photodispatcher.model.mysql.entities.Order;
	import com.photodispatcher.model.mysql.entities.Source;
	import com.photodispatcher.util.ArrayUtil;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.TimerEvent;
	import flash.utils.Timer;
	
	[Event(name="progress", type="flash.events.ProgressEvent")]
	[Event(name="orderLoaded", type="com.photodispatcher.event.OrderLoadedEvent")]
	[Event(name="flowError", type="com.photodispatcher.event.ImageProviderEvent")]
	public class ImageProvider extends EventDispatcher{
		//TODO not in use, refactored to QueueManager
		public static const TYPE_FTP:int=1;
		public static const SPEED_METER_INTERVAL:int=10;//sek

		public function ImageProvider(source:Source=null){
			super(null);
			this.source=source;
		}

		
		protected var _isStarted:Boolean=false;
		[Bindable(event="isStartedChange")]
		public function get isStarted():Boolean{
			return _isStarted;
		}
		
		[Bindable(event="queueLenthChange")]
		public function get queueLenth():int{
			return queue.length;
		}
		[Bindable(event="connectionsLenthChange")]
		public function get connectionsLenth():int{
			return 0;
		}
		[Bindable(event="processingLenthChange")]
		public function get processingLenth():int{
			return downloadOrders.length;
		}
		
		protected var _loadProgressOrders:String='';
		[Bindable(event="loadProgressOrdersChange")]
		public function get loadProgressOrders():String{
			return _loadProgressOrders;
		}
		
		protected var localFolder:String;
		
		/*
		*orders Queue
		*/
		protected var queue:Array=[];
		/*
		*in proccess orders 
		*/
		protected var downloadOrders:Array=[];
		
		[Bindable]
		public var source:Source;
		[Bindable]
		public var speed:int;//mb/sek

		protected var forceStop:Boolean;

		private var meterTimer:Timer;
		protected var meter:Array=[0];
		protected var meterIndex:int=0;
		
		protected function startMeter():void{
			meter=[0]; meterIndex=0; speed=0;
			meterTimer= new Timer(1000,0);
			meterTimer.addEventListener(TimerEvent.TIMER, onMeterTimer);
			meterTimer.start();
		}
		private function onMeterTimer(e:TimerEvent):void{
			meterIndex++;
			if (meterIndex>=SPEED_METER_INTERVAL) meterIndex=0;
			if(meter.length<(meterIndex+1)){
				meter.push(0);
			}else{
				meter[meterIndex]=0;
			}
			var newSpeed:int=0;
			for each (var o:Object in meter) newSpeed+=int(o);
			speed=Math.round(newSpeed/(meter.length*1024));
		}

		protected function stopMeter():void{
			meter=[0]; meterIndex=0; speed=0;
			if(meterTimer){
				meterTimer.stop();
				meterTimer.removeEventListener(TimerEvent.TIMER, onMeterTimer);
				meterTimer=null;
			}
		}

		public function start(resetErrors:Boolean=false):void{
			throw new Error("You need to override start() in your concrete Provider");
		}
		public function stop():void{
			throw new Error("You need to override start() in your concrete Provider");
		}

		public function reSync(orders:Array):void{
			throw new Error("You need to override start() in your concrete Provider");
		}
		
		protected function getOrderById(orderId:String, pop:Boolean=false):Order{
			var result:Order;
			var idx:int;
			if(pop){
				idx=ArrayUtil.searchItemIdx('id', orderId, queue);
				if(idx!=-1){
					var o:Object=queue.splice(idx,1)[0];
					result=o as Order;
				}
				dispatchEvent(new Event('queueLenthChange'));
			}else{
				result=ArrayUtil.searchItem('id', orderId, queue) as Order;
			}
			
			return result;
		}
		
	}
}