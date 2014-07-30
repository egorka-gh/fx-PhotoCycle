package com.photodispatcher.provider.ftp{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.event.AsyncSQLEvent;
	import com.photodispatcher.event.ImageProviderEvent;
	import com.photodispatcher.event.OrderBuildEvent;
	import com.photodispatcher.event.OrderLoadedEvent;
	import com.photodispatcher.event.OrderPreprocessEvent;
	import com.photodispatcher.factory.SuborderBuilder;
	import com.photodispatcher.model.Order;
	import com.photodispatcher.model.mysql.entities.OrderState;
	import com.photodispatcher.model.PrintGroup;
	import com.photodispatcher.model.mysql.entities.Source;
	import com.photodispatcher.model.SourceType;
	import com.photodispatcher.model.Suborder;
	import com.photodispatcher.model.dao.BaseDAO;
	import com.photodispatcher.model.dao.OrderDAO;
	import com.photodispatcher.model.dao.StateLogDAO;
	import com.photodispatcher.provider.preprocess.CaptionSetter;
	import com.photodispatcher.provider.preprocess.PreprocessManager;
	import com.photodispatcher.util.ArrayUtil;
	import com.photodispatcher.util.StrUtil;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.filesystem.File;
	
	import mx.collections.ArrayCollection;
	
	public class FtpManager extends EventDispatcher{

		private var _preprocessManager:PreprocessManager;
		
		[Bindable]
		public var writeOrdersList:ArrayCollection;
		[Bindable]
		public var isWriting:Boolean=false;
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
			writeOrdersList=new ArrayCollection();
			writeOrdersList.source=writeOrders;
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
			//if(writeOrder) a.push(writeOrder);
			if(writeOrders.length>0) a=a.concat(writeOrders);
			var order:Order;
			var wOrder:Order;
			var idx:int;
			//var newWriteOrders:Array=[];
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
			
			//var f:FtpService;
			var f:QueueManager;
			if(services){
				//resync services
				for each(f in services){
					if(f) f.reSync(orders);
				}
			}
			
			flushWriteQueue();
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
			//var f:FtpService;
			var f:QueueManager;
			for each(f in services){
				if(f) f.stop();
			}
			flushWriteQueue();
		}
		
		private function onOrderLoaded(e:ImageProviderEvent):void{ //(e:OrderLoadedEvent):void{
			var source:Source=ArrayUtil.searchItem('id',e.order.source,sources) as Source;
			//var dstFolder:String=Context.getAttribute('workFolder')+File.separator+StrUtil.toFileName(source.name);
			var dstFolder:String=source.getWrkFolder();
			var order:Order=e.order;
			try{
				CaptionSetter.restoreFileCaption(order,dstFolder);
			}catch(err:Error){
			}
			//resize
			preprocessOrder(order);
		}

		//private var writeOrder:Order;
		private function currWriteOrder():Order{
			if(writeOrders.length==0) return null;
			return writeOrders[0] as Order;
		}

		private function saveOrder(order:Order):void{
			writeOrders.push(order);
			flushWriteQueue();
		}
		private function flushWriteQueue():void{
			if(isWriting) return;
			writeNext();
		}
		private function writeNext():void{
			if(writeOrders.length==0){
				isWriting=false;
				return;
			}
			isWriting=true;
			//var order:Order= writeOrders.shift() as Order;
			//if(!order || order.state!=OrderState.FTP_LOAD) return;
			//if(!order) return;
			var order:Order=currWriteOrder();
			if(!order){
				//dumy skip null obj
				writeOrders.shift();
				writeOrdersList.refresh();
				writeNext();
				return;
			}
			//writeOrder=order;
			var oDAO:OrderDAO= new OrderDAO();
			oDAO.addEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT, onWrite);
			trace('FtpManager write order to db '+ order.id);
			oDAO.createChilds(order);
		}
		private function onWrite(e:AsyncSQLEvent):void{
			var oDAO:OrderDAO=e.target as OrderDAO;
			if(oDAO) oDAO.removeEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT, onWrite);
			var order:Order=currWriteOrder();
			if(!order){
				//????
				isWriting=false;
				if(writeOrders.length>0){
					writeOrders.shift();
					writeOrdersList.refresh();
				}
				return;
			}
			if(e.result==AsyncSQLEvent.RESULT_COMLETED){
				trace('FtpManager write completed '+ order.id)
				//writeOrder.state=OrderState.PRN_WAITE;
				//dispatchEvent(new OrderLoadedEvent(writeOrder));
				//writeOrder=null;
				writeOrders.shift();
				writeOrdersList.refresh();
				writeNext();
			}else{
				trace('FtpManager write err '+ order.id+'; err: '+BaseDAO.lastErrMsg);
				order.state=OrderState.ERR_WRITE_LOCK;
				if (BaseDAO.lastErr==3119){
					//write lock
					isWriting=false;
				}else{
					//sql err
					StateLogDAO.logState(OrderState.ERR_WRITE_LOCK,order.id, '','FtpManager write err '+ order.id+'; err: '+BaseDAO.lastErrMsg);
					writeOrders.shift();
					writeOrdersList.refresh();
					writeNext();
				}
			}
			dispatchEvent(new Event('processingLenthChange'));
		}

		private function preprocessOrder(order:Order):void{
			//chek if order skipped
			var minState:int=OrderState.SKIPPED;
			var pg:PrintGroup;
			var so:Suborder;
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
	}
}