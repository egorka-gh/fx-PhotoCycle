package com.photodispatcher.tech{
	import com.photodispatcher.event.BarCodeEvent;
	import com.photodispatcher.event.ControllerMesageEvent;
	import com.photodispatcher.interfaces.ISimpleLogger;
	import com.photodispatcher.service.barcode.ComInfo;
	import com.photodispatcher.service.barcode.GlueController;
	import com.photodispatcher.service.barcode.SerialProxy;
	import com.photodispatcher.service.barcode.Socket2Com;
	import com.photodispatcher.tech.picker.PickerLatch;
	import com.photodispatcher.tech.register.TechBook;
	
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.TimerEvent;
	import flash.utils.Timer;
	
	import mx.collections.ArrayCollection;
	import mx.controls.Alert;
	
	[Event(name="error", type="flash.events.ErrorEvent")]
	[Event(name="complete", type="flash.events.Event")]
	[Event(name="controllerMesage", type="com.photodispatcher.event.ControllerMesageEvent")]
	public class GlueHandler extends EventDispatcher{

		public function GlueHandler(){
			super(null);
		}
		
		
		//feeder
		public var hasFeeder:Boolean=false;
		private var _feederEmpty:Boolean=false;
		public function get reamEmpty():Boolean{
			return false;
		}
		public function feederPower(on:Boolean):void{
		}
		public function feederPump(on:Boolean):void{
		}
		public function feederFeed():void{
		}
		public function feederGetReamState():void{
		}
		
		[Bindable]
		public var isRunning:Boolean;
		
		public var nonStopMode:Boolean;
		
		//requests feeder pause
		[Bindable]
		public var hasPauseRequest:Boolean;

		[Bindable]
		public var latches:Array;
		private var latchPushBook:PickerLatch;
		private var latchPressOff:PickerLatch;

		[Bindable]
		public var currentBookView:TechBook;
		[Bindable]
		public var bookQueue:ArrayCollection;
		//protected var bookQueue:Array=[];
		
		private var _pushDelay:int;
		public function get pushDelay():int{
			return _pushDelay;
		}
		public function set pushDelay(value:int):void{
			_pushDelay = value;
		}
		
		public var repeatedSignalGap:uint=0;
		
		public var logger:ISimpleLogger;

		private var _controller:GlueController;
		private function get controller():GlueController{
			return _controller;
		}
		private function set controller(value:GlueController):void{
			if(_controller){
				_controller.removeEventListener(ErrorEvent.ERROR, onControllerErr);
				_controller.removeEventListener(BarCodeEvent.BARCODE_DISCONNECTED, onControllerDisconnect);
				_controller.removeEventListener(Event.COMPLETE, onControllerCommandComplite);
				_controller.removeEventListener(ControllerMesageEvent.CONTROLLER_MESAGE_EVENT,onControllerMsg);
				_controller.stop();
			}
			_controller = value;
			if(_controller){
				_controller.logger=logger;
				_controller.addEventListener(ErrorEvent.ERROR, onControllerErr);
				_controller.addEventListener(BarCodeEvent.BARCODE_DISCONNECTED, onControllerDisconnect);
				_controller.addEventListener(Event.COMPLETE, onControllerCommandComplite);
				_controller.addEventListener(ControllerMesageEvent.CONTROLLER_MESAGE_EVENT,onControllerMsg);
			}
		}

		
		public function init(serialProxy:SerialProxy):void{
			createLatches();
			var proxy:Socket2Com=serialProxy.getProxy(ComInfo.COM_TYPE_GLUECONTROLLER);
			if(!proxy){
				controller=null;
				return;
			}
			if(!controller) controller= new GlueController();
			controller.start(proxy);
		}
		
		public function createLatches():Array{
			if(latches) return latches;

			latchPushBook= new PickerLatch(PickerLatch.TYPE_ACL, 1,'Контроллер','Ожидание подтверждения команды', 500+pushDelay);
			latchPressOff= new PickerLatch(PickerLatch.TYPE_PRESSOFF, 1,'Контроллер','Ожидание пресса', 3000);
			latchPushBook.addEventListener(ErrorEvent.ERROR, onLatchTimeout);
			latchPressOff.addEventListener(ErrorEvent.ERROR, onLatchTimeout);
			//l.addEventListener(Event.COMPLETE, onLatchRelease);

			return latches;
		}
		
		public function get isPrepared():Boolean{
			return checkPrepared();
		}
		
		protected function checkPrepared(alert:Boolean=false):Boolean{
			var prepared:Boolean= controller && controller.connected;
			if(!prepared && alert){
				//Alert.show('Не инициализирован контролер склейки');
				log('Не инициализирован контролер склейки');
				//dispatchEvent(new ErrorEvent(ErrorEvent.ERROR,false,false,'Не инициализирован контролер склейки'));
			}
			return 	prepared;
		}
		
		private var startTimer:Timer;
		public function start(startDelay:int=0):Boolean{
			createLatches();
			if(isRunning) return true;
			if(startDelay<=100){
				return startInternal();
			}else{
				startTimer= new Timer(startDelay,1);
				startTimer.addEventListener(TimerEvent.TIMER, onStartTimer);
				startTimer.start();
				return true;
			}
		}
		private function onStartTimer(e:TimerEvent):void{
			startTimer.removeEventListener(TimerEvent.TIMER, onStartTimer);
			startTimer= null;
			startInternal();
		}

		private function startInternal():Boolean{
			if(!checkPrepared(true)) return false;
			log('Старт');
			//reset state
			bookQueue=new ArrayCollection();
			latchPushBook.reset();
			latchPressOff.reset();
			stopBook=null;
			
			isRunning=true;
			hasPauseRequest=false;
			return true;
		}
		
		public function reset():void{
			log('Сброс очереди склейки');
			//reset state
			bookQueue=new ArrayCollection();
			latchPushBook.reset();
			latchPressOff.reset();
			stopBook=null;
			hasPauseRequest=false;
		}
		
		
		public function resume():void{
			if(!isRunning) return;
			hasPauseRequest=false;
			checkPrepared(true);
			//reset state
		}
		protected function pauseRequest(err:String):void{
			//ask feeder pause
			if(!isRunning || hasPauseRequest) return;
			if(!nonStopMode) hasPauseRequest=true;
			//log(err);
			dispatchEvent(new ErrorEvent(ErrorEvent.ERROR,false,false,err));
		}
		public function stop(err:String='', engineStop:Boolean=false):void{
			if(!isRunning) return;
			if(!nonStopMode){
				isRunning=false;
				hasPauseRequest=false;
				if(engineStop) controller.engineStop();
			}
			if(err){
				log(err);
				dispatchEvent(new ErrorEvent(ErrorEvent.ERROR,false,false,err));
			}
		}

		protected var stopBook:TechBook;
		public function pauseOnBook(printGroupId:String='lastAdded', book:int=-1):void{
			if(!isRunning) return;
			if(nonStopMode) return;
			if(printGroupId=='lastAdded' && book==-1){
				//get last added
				var tb:TechBook;
				if(bookQueue && bookQueue.length>0) tb=bookQueue.getItemAt(bookQueue.length-1) as TechBook;
				if(tb){
					printGroupId=tb.printGroupId;
					book=tb.book;
				}else{
					return;
				}
			}
			log('Запрошена остановка на книге '+printGroupId+' '+book)
			stopBook= new TechBook(book, printGroupId);
			checkStopBook();
		}
		
		protected function checkStopBook():Boolean{
			if(!stopBook) return false;
			if(!isRunning){
				stopBook=null;
				return false;
			}
			if(nonStopMode) return false;
			
			var tb:TechBook=currentBook;
			if(!tb){
				stopBook=null;
				return false;
			}
			if(tb.printGroupId==stopBook.printGroupId && tb.book==stopBook.book){
				/*
				log('Остановка на книге '+tb.printGroupId+' '+tb.book)
				controller.engineStop();
				*/
				log('Возможно брак. Книга '+tb.printGroupId+' '+tb.book)
				stopBook=null;
				//return true;
			}
			return false;
		}
		
		public function await(printGroupId:String, book:int, sheet:int, sheetTotal:int, barcode:String=''):void{
			if(!isRunning ) return;
			var tb:TechBook;
			//add to last book or create new
			if(bookQueue && bookQueue.length>0) tb=bookQueue.getItemAt(bookQueue.length-1) as TechBook;
			if(tb && tb.printGroupId==printGroupId && tb.book==book){
				if(tb.sheetsFeeded<tb.sheetsTotal) tb.sheetsFeeded++;
			}else{
				tb=new TechBook(book,printGroupId);
				tb.sheetsTotal=sheetTotal;
				tb.sheetsFeeded++;
				tb.barcode=barcode;
				if(!bookQueue) bookQueue=new ArrayCollection();
				bookQueue.addItem(tb);
			}
			
		}
		
		public function get currentBook():TechBook{
			var tb:TechBook;
			if(bookQueue && bookQueue.length>0) tb=bookQueue.getItemAt(0) as TechBook;
			currentBookView=tb;
			return tb;
		}
		
		private function onControllerDisconnect(event:BarCodeEvent):void{
			log('Отключен контролер склейки '+event.barcode);
			//TODO err?
		}
		protected function onControllerErr(event:ErrorEvent):void{
			pauseRequest('Ошибка контролера: '+event.text);
		}
		private function onControllerCommandComplite(event:Event):void{
			latchPushBook.forward();
			checkStopBook();
		}
		
		private function onLatchTimeout(event:ErrorEvent):void{
			if(!isRunning) return;
			var l:PickerLatch=event.target as PickerLatch;
			if(!l) return; 
			pauseRequest('Таймаут ожидания. '+l.label+':'+l.caption);
			/*
			switch(l.type){
				case PickerLatch.TYPE_ACL:
				case PickerLatch.TYPE_PRESSOFF:
					pause('Таймаут ожидания. '+l.label+':'+l.caption);
					break;
			}
			*/
		}

		protected function onControllerMsg(event:ControllerMesageEvent):void{
			if(!isRunning ) return;
			var tb:TechBook=currentBook;//refresh view
			if(event.state==GlueController.STATE_SENSOR0_OFF){
				//press is opened
				if(latchPressOff.isOn){
					latchPressOff.forward();
				}else{
					pauseRequest('Не ожидаемое срабатывание '+latchPressOff.label);
					return;
				}

			}else if(event.state==GlueController.STATE_SENSOR0_ON){
				//press is pushed
				if (checkStopBook()) return;
				if(latchPressOff.isOn){
					//press still closed???? 
					log('Не получено событие пресс отпущен ('+latchPressOff.label+')');
				}else{
					latchPressOff.setOn();
				}

				//check sheet/book
				if(tb){
					tb.sheetsDone++;
					if(tb.sheetsDone>tb.sheetsFeeded){
						stop('Ошибка контроля книги (подано<склеено) '+tb.printGroupId+' '+tb.book);
						if(!nonStopMode) return;
					}
					if(tb.sheetsDone==tb.sheetsTotal && (tb.sheetsFeeded==tb.sheetsTotal || nonStopMode)){
						//book complited
						if(latchPushBook.isOn){
							stop('Ошибка не убрана предидущая книга');
							if(!nonStopMode) return;
						}
						pushBook();
					}
				}else{
					stop('Нет данных о текущей книге');
					return;
				}
			}
		}

		private var timer:Timer;
		protected function pushBook():void{
			//var tb:TechBook=bookQueue.shift() as TechBook;
			var tb:TechBook;
			if(bookQueue.length>0) tb=bookQueue.removeItemAt(0) as TechBook;
			if(!tb) return;
			log('Убираю книгу '+tb.printGroupId+' '+tb.book);
			latchPushBook.setOn();
			if(pushDelay>100){
				if(!timer){
					timer=new Timer(pushDelay,1);
					timer.addEventListener(TimerEvent.TIMER_COMPLETE, onPushTimer);
				}
				timer.delay=pushDelay;
				timer.reset();
				timer.start();
			}else{
				onPushTimer(null);
			}
		}
		private function onPushTimer(e:TimerEvent):void{
			if(!isRunning ) return;
			if(!latchPushBook.isOn) return;
			controller.pushBook();
			//refresh view
			currentBook;
		}
		
		public function removeBook():void{
			if(isRunning && !nonStopMode) return;
			if(isRunning){
				//var tb:TechBook=bookQueue.shift() as TechBook;
				var tb:TechBook;
				if(bookQueue.length>0) tb=bookQueue.removeItemAt(0) as TechBook;
				if(tb){
					log('Убираю книгу '+tb.printGroupId+' '+tb.book);
					//refresh view
					currentBook;
				}
			}
			if(controller) controller.pushBook();
		}
		
		protected function log(msg:String, level:int=0):void{
			if(logger) logger.log('Контролер склейки. '+msg, level);
		}

		public function destroy():void{
			
		}
	}
}