package com.photodispatcher.provider.check{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.model.mysql.DbLatch;
	import com.photodispatcher.model.mysql.entities.Order;
	import com.photodispatcher.model.mysql.entities.OrderLoad;
	import com.photodispatcher.model.mysql.entities.OrderState;
	import com.photodispatcher.model.mysql.entities.StateLog;
	import com.photodispatcher.model.mysql.services.OrderLoadService;
	import com.photodispatcher.util.ArrayUtil;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.filesystem.File;
	
	import mx.collections.ArrayCollection;
	
	import org.granite.tide.Tide;
	
	public class CheckManager extends EventDispatcher{
		
		[Bindable]
		public var lastError:String='';
		[Bindable]
		public var lastLoadTime:Date;
		
		[Bindable]
		public  var queue:ArrayCollection;

		[Bindable]
		public var md5Checker:MD5Checker;

		[Bindable]
		public var imChecker:IMChecker;
		
		[Bindable]
		public var imThreads:int;

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
			//_isStarted = value;
		}
		
		private function start():void{
			if(_isStarted) return;
			
			//perfom checks
			//check IM & wrk folders
			if(!Context.getAttribute('imPath') || ! Context.getAttribute('imThreads')){
				lastError='Не настроен ImageMagick';
				return;
			}
			
			imThreads=Context.getAttribute('imThreads');
			if(imThreads<=0) imThreads=1;
			
			var dstFolder:String=Context.getAttribute('workFolder');
			if(!dstFolder){
				lastError='Не задана рабочая папка';
				return;
			}
			var file:File=new File(dstFolder);
			if(!file.exists || !file.isDirectory){
				lastError='Рабочая папка не доступна';
				return;
			}
			
			md5Checker.init();
			imChecker.init();
			
			_isStarted=true;
			startNext();
		}
		
		private function stop():void{
			_isStarted=false;
			md5Checker.stop();
			imChecker.stop();
			/*
			if(currOrder){
				reprintBuilder.stop();
				if(!currOrder.tag){
					if(currOrder.state < OrderState.PREPROCESS_CAPTURED){
						currOrder.state=OrderState.PREPROCESS_WAITE;
					}else{
						orderBuilder.stop();
						//unlock
						currOrder.state=OrderState.PREPROCESS_WAITE;
						var latch:DbLatch= new DbLatch(true);
						//latch.addEventListener(Event.COMPLETE,onOrderSave);
						latch.addLatch(orderService.setState(currOrder));
						latch.start();
					}
				}else if(currOrder.tag==Order.TAG_REPRINT){
					currOrder.state=OrderState.REPRINT_WAITE;
				}
				currOrder=null;
			}
			*/
			//reset states
			for each (var order:Order in queue.source){
				if(order){
					if(order.state>OrderState.FTP_WAITE_CHECK) order.restoreState();
				}
			}
		}

		public function CheckManager(){
			super(null);
			queue= new ArrayCollection();
			//TODO init checkers
			md5Checker= new MD5Checker();
			md5Checker.addEventListener(Event.COMPLETE, onMD5Complite);
			imChecker=new IMChecker();
			imChecker.addEventListener(Event.COMPLETE, onImComplite);
			
		}
		
		public function check(order:Order):void{
			if(order && (order.state==OrderState.FTP_WAITE_CHECK || order.state==OrderState.FTP_CHECK)){
				trace('CheckManager added order '+order.id);
				//check if already in queue
				var idx:int=ArrayUtil.searchItemIdx('id',order.id,queue.source);
				if(idx==-1){
					queue.addItem(order);
				}
			}
			startNext();
		}

		private function startNext():void{
			if(!isStarted) return;
			if(queue.source.length==0) return;
			var order:Order;
			
			//start  md5Checker
			if(!md5Checker.isBusy){
				for each(order in queue.source){
					if(order.state==OrderState.FTP_WAITE_CHECK){
						if(!order.files || order.files.length==0){
							loadFromBD(order);
						}else{
							md5Checker.check(order);
							order=null;
						}
						break;
					}
				}
			}
			
			//start IM checker
			if(!imChecker.isBusy){
				for each(order in queue.source){
					if(order.state==OrderState.FTP_CHECK && (!md5Checker.isBusy || !md5Checker.currentOrder || order.id!=md5Checker.currentOrder.id)){
						if(!order.files || order.files.length==0){
							loadFromBD(order);
						}else{
							imChecker.check(order);
							order=null;
						}
						break;
					}
				}
			}
		}
		
		private function loadFromBD(order:Order):void{
			if(!order) return;
			order.state=OrderState.FTP_GET_PROJECT;
			var latch:DbLatch= new DbLatch(true);
			latch.addEventListener(Event.COMPLETE, onloadFromBD);
			latch.addLatch(bdService.loadById(order.id),order.id);
			latch.start();
		}
		private function onloadFromBD(evt:Event):void{
			var latch:DbLatch=evt as DbLatch;
			var result:OrderLoad;
			if(latch){
				latch.removeEventListener(Event.COMPLETE, onloadFromBD);
				if(latch.complite) result=latch.lastDataItem as OrderLoad;
				if(!result){
					removeOrder(latch.lastTag);
					return;
				}
				var order:Order=ArrayUtil.searchItem('id',latch.lastTag,queue.source) as Order;
				if(!order) return;
				order.files=result.files as ArrayCollection;
				if(!order.files || order.files.length==0){
					order.state=OrderState.ERR_GET_PROJECT;
					removeOrder(order.id);
					return;
				}
				order.restoreState();
				startNext();
			}
		}
		
		private function onMD5Complite(evt:Event):void{
			var latch:DbLatch;
			if(md5Checker.hasError){
				if(md5Checker.currentOrder){
					if(md5Checker.currentOrder.state==OrderState.ERR_CHECK_MD5){
						//save in bd
						//send to reload
						StateLog.log(OrderState.ERR_CHECK_MD5,md5Checker.currentOrder.id,'',md5Checker.error);
						md5Checker.currentOrder.state=OrderState.FTP_WAITE;
						md5Checker.currentOrder.saveState();
						latch= new DbLatch(true);
						latch.addLatch(bdService.save(OrderLoad.fromOrder(md5Checker.currentOrder)));
						latch.start();
					}
					removeOrder(md5Checker.currentOrder.id);
				}
			}else if(md5Checker.currentOrder && md5Checker.currentOrder.state==OrderState.FTP_CHECK){
				//save in bd
				md5Checker.currentOrder.saveState();
				latch= new DbLatch(true);
				latch.addLatch(bdService.save(OrderLoad.fromOrder(md5Checker.currentOrder)));
				latch.start();
			}
			startNext();
		}

		private function onImComplite(evt:Event):void{
			//TODO implement
			var latch:DbLatch;
			if(imChecker.hasError){
				//update on site
				//then save in bd
				//then remove
			}else{
				//same exept remote state on site
			}
		}

		protected function removeOrder(id:String):void{
			if(!id || !queue) return;
			var arr:Array=queue.source;
			var idx:int=ArrayUtil.searchItemIdx('id',id,arr);
			if(idx!=-1) arr.splice(idx,1);
			//queue= new ArrayCollection(arr);
			queue.refresh();
		}

		private function get bdService():OrderLoadService{
			return Tide.getInstance().getContext().byType(OrderLoadService,true) as OrderLoadService;
		}
		

			
	}
}