package com.photodispatcher.tech{
	import com.photodispatcher.event.BarCodeEvent;
	import com.photodispatcher.event.ControllerMesageEvent;
	import com.photodispatcher.interfaces.ISimpleLogger;
	import com.photodispatcher.model.mysql.DbLatch;
	import com.photodispatcher.model.mysql.entities.Order;
	import com.photodispatcher.model.mysql.entities.OrderExtraInfo;
	import com.photodispatcher.model.mysql.entities.PrintGroup;
	import com.photodispatcher.model.mysql.entities.SubOrder;
	import com.photodispatcher.model.mysql.entities.TechLog;
	import com.photodispatcher.model.mysql.entities.TechPoint;
	import com.photodispatcher.model.mysql.services.OrderService;
	import com.photodispatcher.model.mysql.services.OrderStateService;
	import com.photodispatcher.model.mysql.services.TechService;
	import com.photodispatcher.service.barcode.ComReader;
	import com.photodispatcher.service.modbus.controller.BookJoinMBController;
	import com.photodispatcher.service.modbus.controller.MBController;
	import com.photodispatcher.tech.register.TechBook;
	import com.photodispatcher.util.ArrayUtil;
	
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.TimerEvent;
	import flash.utils.Timer;
	
	import mx.collections.ArrayCollection;
	
	import org.granite.tide.Tide;
	
	[Event(name="error", type="flash.events.ErrorEvent")]
	public class BookJoinHandler extends EventDispatcher{
		
		public function BookJoinHandler(){
			super(null);
		}
		
		public var serverIP:String='';
		public var serverPort:int=503;
		public var clientIP:String='';
		public var clientPort:int=502;
		
		public var techPoint:TechPoint;
		public var logger:ISimpleLogger;
		public var useTechBarcode:Boolean;

		public var splineCalibrationSteps:int;
		public var splineCalibrationMM:int;
		public var splineOffset:int;

		public var timeoutBlockOutAfterCoverBarcode:int=0;
		public var timeoutBlockPass:int=0;
		
		[Bindable]
		public var isRunning:Boolean;
		
		[Bindable]
		public var blockQueue:ArrayCollection;
		[Bindable]
		public var lastBookName:String;
		[Bindable]
		public var currentCoverName:String;
		
		
		[Bindable('readyChange')]
		public function set isReady(val:Boolean):void{dispatchEvent(new Event('readyChange'));}
		public function get isReady():Boolean{
			return controller && controller.connected && controller.hasReference 
				&& barcodeReaderCover && barcodeReaderCover.connected
				&& barcodeReaderBlock && barcodeReaderBlock.connected;
		}

		private var _controller:BookJoinMBController;
		[Bindable]
		public function get controller():BookJoinMBController{
			return _controller;
		}
		public function set controller(value:BookJoinMBController):void{
			if(_controller){
				_controller.removeEventListener(ErrorEvent.ERROR, onControllerErr);
				_controller.removeEventListener(ControllerMesageEvent.CONTROLLER_MESAGE_EVENT,onControllerMsg);
				_controller.removeEventListener("connectChange",onControllerConect);
				_controller.stop();
			}
			_controller = value;
			if(_controller){
				_controller.addEventListener(ErrorEvent.ERROR, onControllerErr);
				_controller.addEventListener(ControllerMesageEvent.CONTROLLER_MESAGE_EVENT,onControllerMsg);
				_controller.addEventListener("connectChange",onControllerConect);
			}
		}
		
		private var _barcodeReaderCover:ComReader;
		public function get barcodeReaderCover():ComReader{
			return _barcodeReaderCover;
		}
		public function set barcodeReaderCover(value:ComReader):void{
			if(_barcodeReaderCover){
				_barcodeReaderCover.removeEventListener(BarCodeEvent.BARCODE_READED,onBarCodeCover);
				_barcodeReaderCover.removeEventListener(BarCodeEvent.BARCODE_CONNECTED, onBarConnected);
				_barcodeReaderCover.removeEventListener(BarCodeEvent.BARCODE_DISCONNECTED, onBarDisconnected);
				_barcodeReaderCover.removeEventListener(BarCodeEvent.BARCODE_ERR, onBarError);
			}
			_barcodeReaderCover = value;
			if(_barcodeReaderCover){
				_barcodeReaderCover.addEventListener(BarCodeEvent.BARCODE_READED,onBarCodeCover);
				_barcodeReaderCover.addEventListener(BarCodeEvent.BARCODE_CONNECTED, onBarConnected);
				_barcodeReaderCover.addEventListener(BarCodeEvent.BARCODE_DISCONNECTED, onBarDisconnected);
				_barcodeReaderCover.addEventListener(BarCodeEvent.BARCODE_ERR, onBarError);
			}
		}
		
		private var _barcodeReaderBlock:ComReader;
		public function get barcodeReaderBlock():ComReader{
			return _barcodeReaderBlock;
		}
		public function set barcodeReaderBlock(value:ComReader):void{
			if(_barcodeReaderBlock){
				_barcodeReaderBlock.removeEventListener(BarCodeEvent.BARCODE_READED,onBarCodeBlock);
				_barcodeReaderBlock.removeEventListener(BarCodeEvent.BARCODE_CONNECTED, onBarConnected);
				_barcodeReaderBlock.removeEventListener(BarCodeEvent.BARCODE_DISCONNECTED, onBarDisconnected);
				_barcodeReaderBlock.removeEventListener(BarCodeEvent.BARCODE_ERR, onBarError);
			}
			_barcodeReaderBlock = value;
			if(_barcodeReaderBlock){
				_barcodeReaderBlock.addEventListener(BarCodeEvent.BARCODE_READED,onBarCodeBlock);
				_barcodeReaderBlock.addEventListener(BarCodeEvent.BARCODE_CONNECTED, onBarConnected);
				_barcodeReaderBlock.addEventListener(BarCodeEvent.BARCODE_DISCONNECTED, onBarDisconnected);
				_barcodeReaderBlock.addEventListener(BarCodeEvent.BARCODE_ERR, onBarError);
			}
		}

		
		public function init():void{
			if(!serverIP || !serverPort || !clientIP || !clientPort){
				controller=null;
				return;
			}
			if(controller && controller.connected){
				controller.stop();
			}else{
				controller= new BookJoinMBController();
			}
			controller.serverIP=serverIP;
			controller.serverPort=serverPort;
			controller.clientIP=clientIP;
			controller.clientPort=clientPort;
			//TODO set other props
			/*
			controller.sideStopOffDelay=glueSideStopOffDelay;
			controller.sideStopOnDelay=glueSideStopOnDelay;
			*/
			controller.start();
			if(barcodeReaderBlock) barcodeReaderBlock.start();
			if(barcodeReaderCover) barcodeReaderCover.start();
			dispatchEvent(new Event('readyChange'));
		}
		
		public function start():Boolean{
			if(isRunning) return true;
			//check prepared
			if(!controller || !controller.serverStarted){
				log('Не инициализирован контролер склейки');
				return false;
			}
			if(!barcodeReaderBlock){
				log('Не инициализирован сканер блока');
				return false;
			}
			if(!barcodeReaderCover){
				log('Не инициализирован сканер обложки');
				return false;
			}
			blockQueue=new ArrayCollection();
			orderCache= new Object;
			lastBookName='';
			currentCoverName='';
			
			log('Старт');
			log('Ожидаю подключение контролера');
			//TODO reset state
			
			isRunning=true;
			dispatchEvent(new Event('readyChange'));
			return true;
		}
		
		public function stop():void{
			if(!isRunning) return;
			isRunning=false;
			blockQueue=null;
			orderCache= null;

			if(blockOutTimer){
				blockOutTimer.reset();
				blockOutTimer.removeEventListener(TimerEvent.TIMER,onblockOutTimer);
				blockOutTimer=null;
			}
			if(blockPassTimer){
				blockPassTimer.reset();
				blockPassTimer.removeEventListener(TimerEvent.TIMER,onblockPassTimer);
				blockPassTimer=null;
			}
			
			if(controller) controller.stop();
			if(barcodeReaderBlock) barcodeReaderBlock.stop();
			if(barcodeReaderCover) barcodeReaderCover.stop();
			dispatchEvent(new Event('readyChange'));
		}

		private function onBarError(event:BarCodeEvent):void{
			logErr('Ошибка сканера: '+event.error);
		}
		
		private function onBarDisconnected(event:BarCodeEvent):void{
			logErr('Сканер отключен '+event.barcode);
			dispatchEvent(new Event('readyChange'));
		}
		
		private function onBarConnected(event:BarCodeEvent):void{
			log('Подключен '+event.barcode);
			dispatchEvent(new Event('readyChange'));
		}

		private var lastScanId:String='';
		private var lastBook:int;
		
		private function onBarCodeBlock(event:BarCodeEvent):void{
			var barcode:String=event.barcode;
			var newScanId:String=PrintGroup.idFromBookBarcode(barcode);
			var newOrderId:String=PrintGroup.orderIdFromBookBarcode(barcode);
			var newBook:int=PrintGroup.bookFromBookBarcode(barcode);
			
			if(!newScanId || !newOrderId){
				logErr('Не верный штрих код блока: '+barcode);
				return;
			}
			if(newBook<=0){
				logErr('Не верный номер книги блока: '+newBook.toString());
				return;
			}
			if(newScanId==lastScanId && newBook==lastBook){
				//doublescan?
				return;
			}
			lastScanId=newScanId;
			lastBook=newBook;
			
			//TODO check sequence
			
			//add to queue
			var block:TechBook= new TechBook(newBook, newScanId);
			block.orderId=newOrderId;
			blockQueue.addItem(block);
			if(!applyOrderInfo(block)){
				//load order from bd
				var latch:DbLatch=new DbLatch();
				var svc:OrderService=Tide.getInstance().getContext().byType(OrderService,true) as OrderService;
				latch.addEventListener(Event.COMPLETE,onOrderLoad);
				latch.addLatch(svc.loadOrderVsChilds(newOrderId));
				latch.start();
			}
			log('Блок поставлен в очередь '+getBlockName(block));
			if(blockQueue.length==1) adjustSpline();
		}

		private var lastCoverScanId:String='';
		private var lastCoverBook:int;

		private function onBarCodeCover(event:BarCodeEvent):void{
			var barcode:String=event.barcode;
			//parce barcode
			var pgId:String;
			
			var newScanId:String;
			var newOrderId:String;
			var newBook:int;
			
			if(useTechBarcode && PrintGroup.isTechBarcode(barcode)){
				newScanId=PrintGroup.idFromDigitId(barcode.substr(10));
				newOrderId=PrintGroup.orderIdFromTechBarcode(barcode);
				newBook=PrintGroup.bookFromTechBarcode(barcode);
			}else{
				newScanId=PrintGroup.idFromBookBarcode(barcode);
				newOrderId=PrintGroup.orderIdFromBookBarcode(barcode);
				newBook=PrintGroup.bookFromBookBarcode(barcode);
			}
			
			if(!newScanId || !newOrderId){
				logErr('Не верный штрих код обложки: '+barcode);
				return;
			}
			if(newBook<=0){
				logErr('Не верный номер книги обложки: '+newBook.toString());
				return;
			}
			
			//check doble scan
			if(newScanId==lastCoverScanId && newBook==lastCoverBook){
				return;
			}
			lastCoverScanId=newScanId;
			lastCoverBook=newBook;
			
			log('Сканер обложки: '+newScanId+' книга '+newBook.toString());
			currentCoverName=newScanId+':'+newBook.toString();
			if(techPoint){
				//log to data base
				var tl:TechLog= new TechLog();
				tl.log_date=new Date();
				tl.setSheet(newBook,0);
				tl.print_group=newScanId;
				tl.src_id= techPoint.id;
				var latch:DbLatch=new DbLatch(true);
				var svc:TechService=Tide.getInstance().getContext().byType(TechService,true) as TechService;
				latch.addLatch(svc.logByPg(tl,1));
				latch.start();
			}
			
			//check top block
			var topBlock:TechBook;
			if(blockQueue.length>0) topBlock=blockQueue.getItemAt(0) as TechBook;
			if(!topBlock){
				logErr('Не определен текущий блок (onBarCodeCover)');
				return;
			}
			if(!getBlockThickness(topBlock)){
				logErr('Не определена толщина текущего блока (onBarCodeCover)');
				return;
			}
			
			//check cover order id
			if(topBlock.orderId!=newOrderId){
				log2bd(topBlock.printGroupId,'Неверный заказ обложки '+newOrderId);
				logErr('Неверный заказ обложки '+ newOrderId+', заказ блока '+topBlock.orderId);
				return;
			}
			
			//check cover order subid
			if(topBlock.order && topBlock.order.hasSuborders){
				var pg:PrintGroup=ArrayUtil.searchItem('id',newScanId,topBlock.order.printGroups.toArray()) as PrintGroup;
				if(pg && pg.sub_id!=topBlock.subId){
					logErr('Неверный подзаказ обложки '+pg.sub_id+', подзаказ блока '+topBlock.subId);
					log2bd(topBlock.printGroupId,'Неверный подзаказ обложки '+pg.sub_id +'('+topBlock.subId+')');
					return;
				}
			}
			
			//check cover book
			if(topBlock.book!=newBook){
				logErr('Неверная книга обложки '+newBook.toString() +', книга блока '+topBlock.book.toString());
				log2bd(topBlock.printGroupId,'Неверная книга обложки '+newBook.toString() +'('+topBlock.book.toString()+')');
				return;
			}
			
			log('Книга заказа '+getBlockName(topBlock)+' - OK');
			startBlockOutTimer();
		}

		private function log2bd(pgId:String, msg:String):void{
			if(!techPoint || !pgId || !msg) return;
			var latch:DbLatch=new DbLatch(true);
			var svc:OrderStateService=Tide.getInstance().getContext().byType(OrderStateService,true) as OrderStateService;
			latch.addLatch(svc.logStateByPGroup(pgId, techPoint.tech_type, msg));
			latch.start();
		}
		
		private var orderCache:Object;
		
		private function applyOrderInfo(block:TechBook):Boolean{
			if(!block || !block.orderId) return false;
			if(!isNaN(block.thickness) && block.thickness!=0){
				return true;
			}
			var order:Order=orderCache[block.orderId] as Order;
			if(!order) return false;
			//last used 4 cache
			order.state_date= new Date();
			block.order=order;
			var eInf:OrderExtraInfo;
			if(order.hasSuborders){
				var pg:PrintGroup=ArrayUtil.searchItem('id',block.printGroupId,order.printGroups.toArray()) as PrintGroup;
				if(!pg) return false;
				block.subId=pg.sub_id;
				var subo:SubOrder= order.getSuborder(pg.sub_id);
				if(subo) eInf=subo.extraInfo;
			}else{
				block.subId='';
				eInf=order.extraInfo;
			}
			if(eInf && !isNaN(eInf.bookThickness)) block.thickness=eInf.bookThickness;
			return true;
		}
		
		private function onOrderLoad(event:Event):void{
			var latch:DbLatch=event.target as DbLatch;
			var order:Order;
			if(latch){
				latch.removeEventListener(Event.COMPLETE,onOrderLoad);
				if(!latch.complite){
					log('Ошибка базы данных '+latch.error);
				}else{
					//get first block thickness
					var thickness:int=0;
					var topBlock:TechBook;
					if(blockQueue.length>0) topBlock=blockQueue.getItemAt(0) as TechBook;
					thickness=getBlockThickness(topBlock);
					order=latch.lastDataItem as Order;
					if(order){
						//mark last used
						order.state_date= new Date();
						//put to cache
						orderCache[order.id]=order;
						var block:TechBook;
						for each(block in blockQueue){
							applyOrderInfo(block);
						}
					}
					//move spline
					if(thickness!=getBlockThickness(topBlock)) adjustSpline();
				}
			}
			
			// clear cache? not in use more then 20min
			var key:String;
			var toDel:Array=[];
			var currDate:Date=new Date();
			for(key in orderCache){
				order=orderCache[key] as Order;
				if(!order || !order.state_date || (currDate.time-order.state_date.time)>20*60*1000) toDel.push(key);
			}
			for each(key in toDel){
				if(key) delete orderCache[key];
			}
		}

		private function shiftBlock():void{
			var block:TechBook;
			currentCoverName='';
			if(blockQueue && blockQueue.length>0){
				block=blockQueue.removeItemAt(0) as TechBook;
				if(block){
					log('Блок '+ getBlockName(block)+' вышел');
					lastBookName=getBlockName(block);
				}
			}
			if(!block){
				logErr('Не определен текущий блок (shiftBlock)');
				return;
			}
			adjustSpline();
		}
		
		private function adjustSpline():void{
			var block:TechBook;
			if(splineCalibrationMM<=0 || splineCalibrationSteps<=0){
				logErr('Нет данных калибровки (adjustSpline)');
				return;
			}
			if(blockQueue && blockQueue.length>0){
				block=blockQueue.getItemAt(0) as TechBook;
			}
			if(!block || getBlockThickness(block)==0) return;

			if(!controller || !controller.connected || controller.currPosition==-1){
				logErr('Не инициализирован контролер (adjustSpline)');
				return;
			}
			var steps:int=(block.thickness+splineOffset)*splineCalibrationSteps/splineCalibrationMM;
			log('Настройка планки для блока '+ getBlockName(block));
			if(steps==controller.currPosition){
				//same thickness
				log('Положение рейки не меняется '+steps.toString());
				return;
			}
			controller.gotoPosition(steps);
		}
		
		protected function onControllerMsg(event:ControllerMesageEvent):void{
			if(!isRunning ) return;
			//if(event.chanel==MBController.MESSAGE_CHANEL_SERVER) return;
			if(event.chanel==MBController.MESSAGE_CHANEL_CLIENT){
				log('Котролер: положение рейки '+event.state.toString());
			}else{
				//MESSAGE_CHANEL_SERVER
				switch(event.state){
					case BookJoinMBController.CONTROLLER_FIND_REFERENCE_COMPLITE:
						log('Котролер: поиск исходной позиции выполнен');
						dispatchEvent(new Event('readyChange'));
						break;
					case BookJoinMBController.CONTROLLER_PAPER_SENSOR_IN:
						log('Котролер: блок пошел');
						startBlockPassTimer();
						break;
					case BookJoinMBController.CONTROLLER_PAPER_SENSOR_OUT:
						log('Котролер: блок вышел');
						if(blockPassTimer) blockPassTimer.reset();
						if(blockOutTimer) blockOutTimer.reset();
						shiftBlock();
						break;
					case BookJoinMBController.CONTROLLER_GOTO_RELATIVE_POSITION_COMPLITE:
						log('Котролер: переход на позицию выполнен');
						break;
					case BookJoinMBController.CONTROLLER_ERR_HASNO_REFERENCE:
						logErr('Ошибка контролера: Не определена исходная позиция');
						dispatchEvent(new Event('readyChange'));
						break;
					case BookJoinMBController.CONTROLLER_ERR_GOTO_TIMEOUT:
						logErr('Ошибка контролера: Таймаут перехода на заданную позицию');
						dispatchEvent(new Event('readyChange'));
						break;
				}
			}
			//TODO implement
		}
		
		protected function onControllerErr(event:ErrorEvent):void{
			if(event.errorID!=0){
				logErr('Ошибка контролера: '+event.text);
			}else{
				log(event.text);
			}
		}

		protected function onControllerConect(event:Event):void{
			dispatchEvent(new Event('readyChange'));
		}
		
		protected function log(msg:String):void{
			if(logger) logger.log('Контролер. '+msg);
		}

		private function logErr(msg:String):void{
			dispatchEvent(new ErrorEvent(ErrorEvent.ERROR,false,false,msg));
		}

		private function getBlockName(block:TechBook):String{
			if(!block) return '';
			return block.printGroupId+':'+block.book.toString()+'/'+getBlockThickness(block).toFixed(2)+'мм';
		}
		
		private function getBlockThickness(block:TechBook):Number{
			if(!block || isNaN(block.thickness)) return 0;
			return block.thickness;
		}

		private var blockOutTimer:Timer;
		private function startBlockOutTimer():void{
			if(!controller || !controller.connected) return;
			if(timeoutBlockOutAfterCoverBarcode<=0) return;
			if(!blockOutTimer){
				blockOutTimer= new Timer(timeoutBlockOutAfterCoverBarcode*1000,1);
				blockOutTimer.addEventListener(TimerEvent.TIMER,onblockOutTimer);
			}else{
				blockOutTimer.reset();
				blockOutTimer.delay=timeoutBlockOutAfterCoverBarcode*1000;
			}
			blockOutTimer.start();
		}
		private function onblockOutTimer(evt:TimerEvent):void{
			logErr('Таймаут выхода блока после сканирования обложки');
		}

		private var blockPassTimer:Timer;
		private function startBlockPassTimer():void{
			if(!controller || !controller.connected) return;
			if(timeoutBlockPass<=100) return;
			if(!blockPassTimer){
				blockPassTimer= new Timer(timeoutBlockPass,1);
				blockPassTimer.addEventListener(TimerEvent.TIMER,onblockPassTimer);
			}else{
				blockPassTimer.reset();
				blockPassTimer.delay=timeoutBlockPass;
			}
			blockPassTimer.start();
		}
		private function onblockPassTimer(evt:TimerEvent):void{
			logErr('Застрял блок');
		}

	}
}