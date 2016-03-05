package com.photodispatcher.provider.preprocess{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.event.OrderBuildEvent;
	import com.photodispatcher.event.OrderBuildProgressEvent;
	import com.photodispatcher.factory.OrderBuilder;
	import com.photodispatcher.factory.WebServiceBuilder;
	import com.photodispatcher.model.mysql.DbLatch;
	import com.photodispatcher.model.mysql.entities.BookPgAltPaper;
	import com.photodispatcher.model.mysql.entities.BookSynonym;
	import com.photodispatcher.model.mysql.entities.Order;
	import com.photodispatcher.model.mysql.entities.OrderExtraInfo;
	import com.photodispatcher.model.mysql.entities.OrderState;
	import com.photodispatcher.model.mysql.entities.PrintGroup;
	import com.photodispatcher.model.mysql.entities.Source;
	import com.photodispatcher.model.mysql.entities.SourceType;
	import com.photodispatcher.model.mysql.entities.StateLog;
	import com.photodispatcher.model.mysql.entities.SubOrder;
	import com.photodispatcher.model.mysql.services.OrderService;
	import com.photodispatcher.model.mysql.services.OrderStateService;
	import com.photodispatcher.model.mysql.services.TechRejecService;
	import com.photodispatcher.service.web.BaseWeb;
	import com.photodispatcher.util.ArrayUtil;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.ProgressEvent;
	import flash.events.TimerEvent;
	import flash.filesystem.File;
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
		public var lastLoadTime:Date;
		[Bindable]
		public var progressCaption:String='';
		
		protected var orderBuilder:OrderBuilderLocal;
		protected var reprintBuilder:ReprintOrderBuilder;

		[Bindable]
		public  var queue:ArrayCollection;

		private var webErrCounter:int=0;
		
		public function PreprocessManager(){
			super();
			queue= new ArrayCollection();
			orderBuilder= new OrderBuilderLocal();
			listenBuilder(orderBuilder);
			
			reprintBuilder=new ReprintOrderBuilder();
			listenReprint(reprintBuilder);
		}
		
		private function get orderService():OrderService{
			return Tide.getInstance().getContext().byType(OrderService,true) as OrderService;
		}
		private function get rejectService():TechRejecService{
			return Tide.getInstance().getContext().byType(TechRejecService,true) as TechRejecService;
		}
		
		public function reLoad():void{
			stopTimer();
			//reset errors
			for each(var o:Order in queue.source){
				if(o && o.state<0){
					if(o.tag==Order.TAG_REPRINT){
						o.state=OrderState.REPRINT_WAITE;
					}else{
						o.state=OrderState.PREPROCESS_WAITE;
					}
				}
			}

			//preprocess order
			var latch:DbLatch= new DbLatch(true);
			latch.addEventListener(Event.COMPLETE,onloadFromDB);
			latch.addLatch(orderService.loadByState(OrderState.PREPROCESS_WAITE, OrderState.PREPROCESS_CAPTURED));
			latch.start();

			//reprint orders
			var rLatch:DbLatch= new DbLatch(true);
			rLatch.addEventListener(Event.COMPLETE,onloadReprintOrders);
			rLatch.addLatch(rejectService.loadReprintWaiteAsOrder());
			rLatch.join(latch);
			rLatch.start();
			

		}

		private function onloadReprintOrders(evt:Event):void{
			var latch:DbLatch= evt.target as DbLatch;
			if(latch) latch.removeEventListener(Event.COMPLETE,onloadReprintOrders);
			if(autoLoad) startTimer();
			lastLoadTime= new Date();
			if(!latch || !latch.complite) return;
			var toAdd:Array=latch.lastDataArr;
			//if(toAdd && toAdd.length>0){
			if(toAdd){
				var newItems:Array=[];
				var order:Order;
				if(currOrder) newItems.push(currOrder);
				
				//save preprocess oreders
				for each(order in queue){
					if(order && (!currOrder || order.id!=currOrder.id) && !order.tag){
						newItems.push(order);
					}
				}
				
				// add reprint orders
				for each(order in toAdd){
					if(order){
						if(!currOrder || order.id!=currOrder.id){
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
				dispatchEvent(new FlexEvent(FlexEvent.DATA_CHANGE));
			}
			
			startNext();
		}
		
		private function onloadFromDB(evt:Event):void{
			var latch:DbLatch= evt.target as DbLatch;
			if(latch) latch.removeEventListener(Event.COMPLETE,onloadFromDB);
			//if(autoLoad) startTimer();
			//lastLoadTime= new Date();
			if(!latch || !latch.complite) return;
			var toAdd:Array=latch.lastDataArr;
			//if(!toAdd || toAdd.length==0) return;
			if(!toAdd) return;
			
			var newItems:Array=[];
			if(currOrder) newItems.push(currOrder);
			var order:Order;
			//save reprint oreders
			for each(order in queue){
				if(order && (!currOrder || order.id!=currOrder.id) && order.tag==Order.TAG_REPRINT){
					newItems.push(order);
				}
			}

			// add preprocess orders
			for each(order in toAdd){
				if(order){
					if(!currOrder || order.id!=currOrder.id){
						if(order.state!=OrderState.PREPROCESS_WAITE && order.state!=OrderState.PREPROCESS_FORWARD) order.state=OrderState.PREPROCESS_WAITE;
						var oldOrder:Order=ArrayUtil.searchItem('id',order.id,queue.source) as Order;
						//reprint can't be before regular build
						if(oldOrder && order.tag!=Order.TAG_REPRINT){
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
			//startNext();
		}

		private var currOrder:Order;

		private function startNext():void{
			if(!isStarted){
				//progressCaption='';
				currOrder=null;
				return;
			}
			
			if(currOrder) return;

			progressCaption='';
			if(orderBuilder.isBusy || reprintBuilder.isBusy) return;
			if(queue.source.length==0) return;
			
			var o:Order;
			var order:Order;

			//get reprint order
			for each(o in queue.source){
				if(o && o.tag==Order.TAG_REPRINT && o.state==OrderState.REPRINT_WAITE){
					order=o;
					break;
				}
			}
			
			//get preprocess order
			if(!order){
				for each(o in queue.source){
					if(o && !o.tag){
						if(o.state==OrderState.PREPROCESS_FORWARD){
							order=o;
							break;
						}else if(o.state==OrderState.PREPROCESS_WAITE){
							if(!order) order=o;
						}
					}
				}
				if(order && order.state!=OrderState.PREPROCESS_WAITE) order.state=OrderState.PREPROCESS_WAITE;
			}

			if(!order) return;
			
			currOrder=order;
			//if(currOrder.state!=OrderState.PREPROCESS_WAITE) currOrder.state=OrderState.PREPROCESS_WAITE;
			
			getLock();
		}

		//get soft lock
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
				StateLog.log(currOrder.state, currOrder.id,'','Получена мягкая блокировка ' + Context.appID);
				if(!currOrder.tag && currOrder.state==OrderState.PREPROCESS_WAITE){
					//preprocess web check
					checkWebState();
				}else if(currOrder.tag==Order.TAG_REPRINT){
					//TODO build reprint
					reprintBuilder.build(currOrder);
				}
			}else{
				lastError='Заказ '+currOrder.id+' обрабатывается на другой станции';
				//StateLog.log(OrderState.ERR_LOCK_FAULT, currOrder.id,'','soft lock');
				currOrder.state= OrderState.ERR_LOCK_FAULT;
				currOrder=null;
				startNext();
			}
		}

		//release soft lock
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
			latch.addLatch(orderService.captureState(currOrder.id, OrderState.PREPROCESS_WAITE, OrderState.PREPROCESS_CAPTURED, Context.appID));
			latch.start();
		}
		private function oncaptureState(evt:Event):void{
			releaseLock();
			var latch:DbLatch= evt.target as DbLatch;
			if(latch){
				latch.removeEventListener(Event.COMPLETE,oncaptureState);
				if(!currOrder) return;
				if (latch.complite && latch.resultCode==OrderState.PREPROCESS_CAPTURED){
					StateLog.log(currOrder.state, currOrder.id,'','Получена жесткая блокировка ' + Context.appID);
					//build
					orderBuilder.build(currOrder);
					//TODO remove currOrder from queue after complite
				}else{
					trace('PreprocessManager.captureState: db error '+latch.lastError);
					lastError='Заказ: '+currOrder.id+' блокирован другим процессом '+latch.lastError;
					//StateLog.log(OrderState.ERR_LOCK_FAULT, currOrder.id,'','hard lock');
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

			//perfom checks
			//check IM & wrk folders
			if(!Context.getAttribute('imPath') || ! Context.getAttribute('imThreads')){
				progressCaption='Не настроен ImageMagick';
				return;
			}
			
			var dstFolder:String=Context.getAttribute('workFolder');
			if(!dstFolder){
				progressCaption='Не задана рабочая папка';
				return;
			}
			var file:File=new File(dstFolder);
			if(!file.exists || !file.isDirectory){
				progressCaption='Рабочая папка не доступна';
				return;
			}
			dstFolder=Context.getAttribute('prtPath');
			if(!dstFolder){
				progressCaption='Не задана папка печати';
				return;
			}
			file=new File(dstFolder);
			if(!file.exists || !file.isDirectory){
				progressCaption='Папка печати не доступна';
				return;
			}
			

			_isStarted=true;
			autoLoadInterval=Context.getAttribute('syncInterval');
			reLoad();
		}
		
		private function stop():void{
			_isStarted=false;
			stopTimer();
			progressCaption='';
			releaseLock();
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
			//reset states
			for each (var order:Order in queue.source){
				if(order){
					if(!order.tag){
						if(order.state!=OrderState.PREPROCESS_WAITE && order.state!=OrderState.PREPROCESS_FORWARD ){
							order.state=OrderState.PREPROCESS_WAITE;
						}
					}else if(order.tag==Order.TAG_REPRINT){
						order.state=OrderState.REPRINT_WAITE;
					}
				}
			}
		}

		public function destroy():void{
			//TODO implement
		}

		private function listenReprint(builder:OrderBuilderBase, listen:Boolean=true):void{
			if(!builder) return;
			if(listen){
				builder.addEventListener(OrderBuildEvent.BUILDER_ERROR_EVENT,onReprintError);
				builder.addEventListener(OrderBuildEvent.ORDER_PREPROCESSED_EVENT, onReprint);
				builder.addEventListener(ProgressEvent.PROGRESS, onPreprocessProgress);
			}else{
				builder.removeEventListener(OrderBuildEvent.BUILDER_ERROR_EVENT,onReprintError);
				builder.removeEventListener(OrderBuildEvent.ORDER_PREPROCESSED_EVENT, onReprint);
				builder.removeEventListener(ProgressEvent.PROGRESS, onPreprocessProgress);
			}
		}
		private function onReprintError(evt:OrderBuildEvent):void{
			//builder error
			lastError=evt.err_msg;
			if(!currOrder) return;
			releaseLock();
			currOrder.state=OrderState.ERR_REPRINT;
			currOrder=null;
			startNext();
		}
		private function onReprint(evt:OrderBuildEvent):void{
			if(!currOrder) return;
			//order complited
			//remove from queue
			releaseLock();
			if(evt.err<0){
				//completed vs error
				currOrder.state=OrderState.ERR_REPRINT;
				currOrder=null;
			}else{
				releaseOrder();
			}
			startNext();
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
			releaseLock();
			currOrder.state=OrderState.PREPROCESS_INCOMPLETE;
			saveOrder(currOrder);
			currOrder=null;
			startNext();
		}
		private function onOrderPreprocessed(evt:OrderBuildEvent):void{
			if(!currOrder) return;
			releaseLock();
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
			
			//apply alt paper
			var so:SubOrder;
			var pg:PrintGroup;
			var newPaper:int=-1;
			var newInterlayer:String;
			for each(pg in currOrder.printGroups){
				if(pg.book_type==0 || !pg.bookTemplate) continue;
				if(pg.book_part!= BookSynonym.BOOK_PART_BLOCK && pg.book_part!= BookSynonym.BOOK_PART_BLOCKCOVER) continue;
				newPaper=0;
				newInterlayer="";
				if(pg.bookTemplate.altPaper){
					for each (var ap:BookPgAltPaper in pg.bookTemplate.altPaper){
						if(pg.sheet_num>=ap.sh_from && pg.sheet_num<=ap.sh_to){
							if(ap.paper>0 && newPaper==0) newPaper=ap.paper;
							if(ap.interlayer_name && !newInterlayer) newInterlayer=ap.interlayer_name;
							if(newPaper>0 && newInterlayer) break;
						}
					}
				}
				if(newPaper>0) pg.paper=newPaper;
				if(newInterlayer){
					var ei:OrderExtraInfo;
					if(!pg.sub_id){
						//get order extrainfo
						if(!currOrder.extraInfo){
							currOrder.extraInfo= new OrderExtraInfo();
							currOrder.extraInfo.id=currOrder.id;
							currOrder.extraInfo.sub_id='';
						}
						ei=currOrder.extraInfo;
					}else{
						//get suborder extraInfo
						so=currOrder.getSuborder(pg.sub_id);
						if(so){
							if(!so.extraInfo){
								so.extraInfo= new OrderExtraInfo();
								so.extraInfo.id=currOrder.id;
								so.extraInfo.sub_id=pg.sub_id;
							}
							ei=so.extraInfo;
						}
					}
					if(ei) ei.interlayer=newInterlayer;
				}
			}
			
			//clean
			if(currOrder.hasSuborders){
				for each(so in currOrder.suborders) so.destroyChilds();
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
				var tag:String;
				if(order.state==OrderState.PRN_WAITE) tag=order.id;
				latch.addLatch(orderService.fillUpOrder(order), tag);
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