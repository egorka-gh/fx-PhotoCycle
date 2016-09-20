package com.photodispatcher.provider.check{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.event.ImageProviderEvent;
	import com.photodispatcher.factory.WebServiceBuilder;
	import com.photodispatcher.model.mysql.DbLatch;
	import com.photodispatcher.model.mysql.entities.Order;
	import com.photodispatcher.model.mysql.entities.OrderLoad;
	import com.photodispatcher.model.mysql.entities.OrderState;
	import com.photodispatcher.model.mysql.entities.Source;
	import com.photodispatcher.model.mysql.entities.StateLog;
	import com.photodispatcher.model.mysql.services.OrderLoadService;
	import com.photodispatcher.service.web.BaseWeb;
	import com.photodispatcher.util.ArrayUtil;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.filesystem.File;
	
	import mx.collections.ArrayCollection;
	
	import org.granite.tide.Tide;
	
	[Event(name="orderLoaded", type="com.photodispatcher.event.ImageProviderEvent")]
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
			lastError='';
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
			//reset states
			for each (var order:Order in queue.source){
				if(order){
					if(order.state>OrderState.FTP_WAITE_CHECK) order.restoreState();
				}
			}
			//DON'T reset queue, setOrderStateWeb can be in process 
		}

		public function CheckManager(){
			super(null);
			queue= new ArrayCollection();
			//init checkers
			md5Checker= new MD5Checker();
			md5Checker.addEventListener(Event.COMPLETE, onMD5Complite);
			imChecker=new IMChecker();
			imChecker.addEventListener(Event.COMPLETE, onImComplite);
			
		}
		
		public function sync(orders:Array):void{
			if(!_isStarted) return;
			if(!orders) return;

			lastError='';

			var toKill:Array=[];
			//var toAdd:Array=[];
			var idx:int;
			var order:Order;
			
			//search to remove or replace
			for each(order in queue.source){
				idx=ArrayUtil.searchItemIdx('id',order.id,orders);
				if(idx!=-1){
					//replace
					orders[idx]=order;
				}else{
					if(order.state<=OrderState.FTP_CHECK && !md5Checker.isAtCheck(order.id) && !imChecker.isAtCheck(order.id)){
						toKill.push(order.id);
					}else{
						//in process?
						orders.push(order);
					}
				}
			}
			
			if(toKill.length>0){
				var arr:Array=queue.source;
				for each(var id:String in toKill){
					idx=ArrayUtil.searchItemIdx('id',id,arr);
					if(idx!=-1) arr.splice(idx,1);
					//removeOrder(id);
				}
				queue=new ArrayCollection(arr);
			}

			//search to add
			var syncOrders:Array=orders.filter(reSyncFilter);
			for each(order in syncOrders){
				idx=ArrayUtil.searchItemIdx('id',order.id,queue.source);
				if(idx==-1) queue.addItem(order);
			}
			
			queue.refresh();
			
			startNext();
		}
		private function reSyncFilter(element:*, index:int, arr:Array):Boolean {
			var o:Order=element as Order;
			return o!=null && o.state>=OrderState.FTP_WAITE_CHECK && o.state<=OrderState.FTP_CHECK;
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
							order.saveState();
							md5Checker.check(order);
						}
						break;
					}
				}
			}
			
			//start IM checker
			if(!imChecker.isBusy){
				for each(order in queue.source){
					if(order.state==OrderState.FTP_CHECK && !md5Checker.isAtCheck(order.id)){
						if(!order.files || order.files.length==0){
							loadFromBD(order);
						}else{
							order.saveState();
							imChecker.check(order);
						}
						break;
					}
				}
			}
		}
		
		private function loadFromBD(order:Order):void{
			if(!order) return;
			order.saveState();
			order.state=OrderState.FTP_GET_PROJECT;
			var latch:DbLatch= new DbLatch(true);
			latch.addEventListener(Event.COMPLETE, onloadFromBD);
			latch.addLatch(bdService.loadById(order.id),order.id);
			latch.start();
		}
		private function onloadFromBD(evt:Event):void{
			var latch:DbLatch=evt.target as DbLatch;
			var result:OrderLoad;
			if(latch){
				latch.removeEventListener(Event.COMPLETE, onloadFromBD);
				if(latch.complite) result=latch.lastDataItem as OrderLoad;
				if(!result || (result.state!=OrderState.FTP_WAITE_CHECK && result.state!=OrderState.FTP_CHECK)){
					removeOrder(latch.lastTag);
					return;
				}
				var order:Order=ArrayUtil.searchItem('id',latch.lastTag,queue.source) as Order;
				if(!order) return;
				order.files=result.files as ArrayCollection;
				if(!order.files || order.files.length==0){
					lastError='Ошибка загрузки '+order.id;
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
						lastError='Ошибка MD5 '+md5Checker.currentOrder.id+'; '+md5Checker.error;
						StateLog.log(OrderState.ERR_CHECK_MD5,md5Checker.currentOrder.id,'',md5Checker.error);
						md5Checker.currentOrder.state=OrderState.FTP_WAITE;
						md5Checker.currentOrder.saveState();
						latch= new DbLatch(true);
						latch.addEventListener(Event.COMPLETE,onSave);
						latch.addLatch(bdService.save(OrderLoad.fromOrder(md5Checker.currentOrder),0));
						latch.start();
					}
					removeOrder(md5Checker.currentOrder.id);
				}
			}else if(md5Checker.currentOrder && md5Checker.currentOrder.state==OrderState.FTP_CHECK){
				//save in bd
				md5Checker.currentOrder.saveState();
				latch= new DbLatch(true);
				latch.addEventListener(Event.COMPLETE,onSave);
				latch.addLatch(bdService.save(OrderLoad.fromOrder(md5Checker.currentOrder),OrderState.FTP_WAITE_CHECK),md5Checker.currentOrder.id);
				latch.start();
			}
		}

		private function onSave(evt:Event):void{
			var latch:DbLatch=evt.target as DbLatch;
			if(latch){
				latch.removeEventListener(Event.COMPLETE, onSave);
				if(!latch.complite){
					if(latch.lastErrCode==OrderState.ERR_WRONG_STATE && latch.lastTag){
						StateLog.log(OrderState.ERR_WRONG_STATE,latch.lastTag,'',latch.lastError);
					}
				}
			}
			startNext();
		}
		
		private function onImComplite(evt:Event):void{
			//TODO implement
			var latch:DbLatch;
			if(imChecker.hasError){
				lastError='Ошибка IM '+imChecker.currentOrder.id+'; '+imChecker.error;
				if(imChecker.currentOrder.state==OrderState.FTP_INCOMPLITE){
					//update on site
					//then save in bd
					//then remove
					setOrderStateWeb(imChecker.currentOrder,OrderLoad.REMOTE_STATE_ERROR,imChecker.error);
				}else{
					/*
					if(imChecker.currentOrder.state<0 && !imChecker.currentOrder.exceedErrLimit){
						//reset & save?
						imChecker.currentOrder.state=OrderState.FTP_CHECK;
						imChecker.currentOrder.saveState();
						latch= new DbLatch(true);
						latch.addLatch(bdService.save(OrderLoad.fromOrder(imChecker.currentOrder)));
						latch.start();
					}
					*/
					removeOrder(imChecker.currentOrder.id);
				}
			}else if(imChecker.currentOrder.state==OrderState.FTP_COMPLETE){
				//same exept remote state done on site
				setOrderStateWeb(imChecker.currentOrder,OrderLoad.REMOTE_STATE_DONE);
			}else{
				//her poime
				removeOrder(imChecker.currentOrder.id);
				return;
			}
			startNext();
		}

		private function setOrderStateWeb(order:Order, remoteState:int, comment:String=''):void{
			if(!order) return;
			var source:Source=Context.getSource(order.source);
			var webService:BaseWeb=WebServiceBuilder.build(source);
			var ord:Order=new Order();
			ord.id=order.id;
			ord.src_id=order.src_id;
			ord.src_state=remoteState.toString();
			ord.errStateComment=comment;
			webService.addEventListener(Event.COMPLETE,onSetOrderStateWeb);
			webService.setLoaderOrderState(ord);
		}
		
		private function onSetOrderStateWeb(e:Event):void{
			var pw:BaseWeb=e.target as BaseWeb;
			pw.removeEventListener(Event.COMPLETE,onSetOrderStateWeb);
			//finde order 4 save
			var order:Order;
			if(pw.lastOrderId){
				order=ArrayUtil.searchItem('id',pw.lastOrderId,queue.source) as Order;
			}
			//remove anyway
			removeOrder(pw.lastOrderId);
			if(pw.hasError){
				trace('setOrderStateWeb web err: '+pw.errMesage);
				lastError='Ошибка сайта: '+pw.errMesage;
				if(pw.lastOrderId) StateLog.log(OrderState.ERR_WEB,pw.lastOrderId,'','Ошибка сайта: '+pw.errMesage);
				//web err, can't save
			}else{
				if(order){
					//save
					dispatchEvent(new ImageProviderEvent(ImageProviderEvent.ORDER_LOADED_EVENT,order));
					/*
					var latch:DbLatch= new DbLatch(true);
					latch.addLatch(bdService.save(OrderLoad.fromOrder(order)));
					latch.start();
					*/
				}
			}
		}

		protected function removeOrder(id:String):void{
			if(!id || !queue ) return;
			var arr:Array=queue.source;
			var idx:int=ArrayUtil.searchItemIdx('id',id,arr);
			if(idx!=-1) arr.splice(idx,1);
			queue= new ArrayCollection(arr);
			//queue.refresh();
		}

		private function get bdService():OrderLoadService{
			return Tide.getInstance().getContext().byType(OrderLoadService,true) as OrderLoadService;
		}
		

			
	}
}