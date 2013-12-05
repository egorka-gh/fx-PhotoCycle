package com.photodispatcher.tech{
	import com.photodispatcher.event.BarCodeEvent;
	import com.photodispatcher.event.ControllerMesageEvent;
	import com.photodispatcher.interfaces.ISimpleLogger;
	import com.photodispatcher.model.Layer;
	import com.photodispatcher.model.LayerSequence;
	import com.photodispatcher.model.Layerset;
	import com.photodispatcher.model.TechPoint;
	import com.photodispatcher.service.barcode.ComReader;
	import com.photodispatcher.service.barcode.ValveController;
	
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.TimerEvent;
	import flash.utils.Timer;
	
	[Event(name="error", type="flash.events.ErrorEvent")]
	public class TechPicker extends EventDispatcher{
		public static const COMMAND_GROUP_START:int			=-1;
		public static const COMMAND_GROUP_BOOK_START:int	=1;
		public static const COMMAND_GROUP_BOOK_SHEET:int	=2;
		public static const COMMAND_GROUP_BOOK_BETWEEN_SHEET:int	=3;
		public static const COMMAND_GROUP_BOOK_END:int		=4;
		public static const COMMAND_GROUP_STOP:int			=1000;
		
		private static const BD_TIMEOUT_MIN:int=300;
		private static const BD_TIMEOUT_MAX:int=1000;
		private static const BD_MAX_WAITE:int=10000;

 
		public var techPoint:TechPoint;
		public var reversOrder:Boolean;
		
		private var _logger:ISimpleLogger;
		public function get logger():ISimpleLogger{
			return _logger;
		}
		public function set logger(value:ISimpleLogger):void{
			_logger = value;
			if(controller) controller.logger=value;
		}

		
		private var _turnInterval:int=1000; //1sec
		public function get turnInterval():int{
			return _turnInterval;
		}

		public function set turnInterval(value:int):void{
			_turnInterval = value;
			layerLatch.setTimeout(_turnInterval);
			barLatch.setTimeout(_turnInterval);
		}
 
		[Bindable]
		public var prepared:Boolean; 

		public function TechPicker(){
			super(null);

			aclLatch = new PickerLatch(PickerLatch.TYPE_ACL, 1,'Контроллер','Ожидание подтверждения команды', ValveController.ACKNOWLEDGE_TIMEOUT*2);
			layerLatch= new PickerLatch(PickerLatch.TYPE_LAYER, 2,'Фотодатчик','Ожидание листа',turnInterval)
			barLatch = new PickerLatch(PickerLatch.TYPE_BARCODE, 1,'Сканер','Ожидание штрихкода',turnInterval);
			registerLatch = new PickerLatch(PickerLatch.TYPE_REGISTER, 1,'Книга','Контроль очередности',ValveController.ACKNOWLEDGE_TIMEOUT*2);
			latches=[aclLatch,layerLatch,barLatch,registerLatch];
			var l:PickerLatch;
			for each(l in latches){
				l.addEventListener(ErrorEvent.ERROR, onLatchTimeout);
				l.addEventListener(Event.COMPLETE, onLatchRelease);
			}
		}

		public function destroy():void{
			var l:PickerLatch;
			for each(l in latches){
				l.removeEventListener(ErrorEvent.ERROR, onLatchTimeout);
				l.removeEventListener(Event.COMPLETE, onLatchRelease);
			}
			latches=null;
			logger=null;
			barcodeReader=null;
			controller=null;
			register=null;
			if(bdTimer){
				bdTimer.reset();
				bdTimer.removeEventListener(TimerEvent.TIMER,onBdTimer);
				bdTimer=null;
			}
		}
		
		private var _layerset:Layerset;
		[Bindable]
		public function get layerset():Layerset{
			return _layerset;
		}
		public function set layerset(value:Layerset):void{
			_layerset = value;
			prepared=false;
			if(_layerset) prepareTemplate();
		}
		[Bindable]
		public var currentSequence:Array;

		
		private var engineOn:Boolean;
		private var vacuumOn:Boolean;
		[Bindable]
		public var isRunning:Boolean;
		[Bindable]
		public var isPaused:Boolean;

		//Latches
		[Bindable]
		public var latches:Array;
		private var aclLatch:PickerLatch;
		private var layerLatch:PickerLatch;
		private var barLatch:PickerLatch;
		private var registerLatch:PickerLatch;
		
		//print group params
		[Bindable]
		public var currPgId:String='';
		private var currBarcode:String;
		[Bindable]
		public var currBookTot:int;
		[Bindable]
		public var currBookIdx:int;
		[Bindable]
		public var currSheetTot:int;
		[Bindable]
		public var currSheetIdx:int;
		
		private var currentLayer:Layer;
		[Bindable]
		public  var currentTray:int=-1;
		private var waiteTraySwitch:Boolean;
		

		[Bindable]
		public var currentGroupStep:int;

		private var _currentGroup:int;
		[Bindable]
		public function get currentGroup():int{
			return _currentGroup;
		}
		public function set currentGroup(value:int):void{
			if(_currentGroup != value){
				currentGroupStep=0;
				//if(logger) logger.clear();
				currentTray=-1;
				switch(value){
					/*
					case COMMAND_GROUP_START:
						break;
					*/
					case COMMAND_GROUP_BOOK_START:
						currentSequence=layerset.sequenceStart;
						break;
					case COMMAND_GROUP_BOOK_SHEET:
						var ls:LayerSequence= new LayerSequence();
						ls.layer_group=COMMAND_GROUP_BOOK_SHEET;
						ls.seqlayer=Layer.LAYER_SHEET;
						ls.seqlayer_name='Разворот';
						ls.seqorder=1;
						currentSequence=[ls];
						break;
					case COMMAND_GROUP_BOOK_BETWEEN_SHEET:
						currentSequence=layerset.sequenceMiddle;
						break;
					case COMMAND_GROUP_BOOK_END:
						currentSequence=layerset.sequenceEnd;
						break;
					default:
						currentSequence=[];
						break;
				}

				log('group: '+value.toString());
			}
			_currentGroup = value;
		}


		private var _barcodeReader:ComReader;
		public function get barcodeReader():ComReader{
			return _barcodeReader;
		}
		public function set barcodeReader(value:ComReader):void{
			if(_barcodeReader){
				_barcodeReader.removeEventListener(BarCodeEvent.BARCODE_READED,onBarCode);
				_barcodeReader.removeEventListener(BarCodeEvent.BARCODE_ERR, onBarError);
			}
			_barcodeReader = value;
			if(_barcodeReader){
				_barcodeReader.addEventListener(BarCodeEvent.BARCODE_READED,onBarCode);
				_barcodeReader.addEventListener(BarCodeEvent.BARCODE_ERR, onBarError);
			}
		}

		private var _controller:ValveController;
		public function get controller():ValveController{
			return _controller;
		}
		public function set controller(value:ValveController):void{
			if(_controller){
				_controller.removeEventListener(ErrorEvent.ERROR, onControllerErr);
				_controller.removeEventListener(Event.COMPLETE, onControllerCommandComplite);
				_controller.removeEventListener(ControllerMesageEvent.CONTROLLER_MESAGE_EVENT,onControllerMsg);
			}
			_controller = value;
			if(_controller){
				_controller.addEventListener(ErrorEvent.ERROR, onControllerErr);
				_controller.addEventListener(Event.COMPLETE, onControllerCommandComplite);
				_controller.addEventListener(ControllerMesageEvent.CONTROLLER_MESAGE_EVENT,onControllerMsg);
			}
		}

		private var _register:TechRegisterPicker;
		public function get register():TechRegisterPicker{
			return _register;
		}
		public function set register(value:TechRegisterPicker):void{
			if(_register){
				//stop listen
				_register.removeEventListener(ErrorEvent.ERROR, onRegisterErr);
				_register.removeEventListener(Event.COMPLETE, onRegisterComplite);
			}
			_register = value;
			if(_register){
				//listen
				_register.addEventListener(ErrorEvent.ERROR, onRegisterErr);
				_register.addEventListener(Event.COMPLETE, onRegisterComplite);
			}
		}

		private function prepareTemplate():void{
			if(!_layerset) return;
			prepared=_layerset.prepareTamplate();
			if(!prepared) callDbLate(prepareTemplate); 
		}
		
		private var bdWait:int=0;
		private var bdAttempt:int=0;
		private var bdTimer:Timer;
		private var bdFunction:Function;
		
		private function callDbLate(func:Function):void{
			if(func==null) return;
			bdFunction=func;
			if (bdWait>=BD_MAX_WAITE){
				//max wait reached
				//TODO pause vs err
				pause('Блокировка при чтении базы данных');
				log('!database locked');
				//clean up
				bdWait=0;
				bdAttempt=0;
			}
			if(!bdTimer){
				bdTimer=new Timer(getTimeout(),1);
			}else{
				bdTimer.reset();
			}
			bdTimer.addEventListener(TimerEvent.TIMER,onBdTimer);
			var sleep:int=getTimeout();
			bdWait+=sleep;
			bdTimer.delay=sleep;
			bdAttempt++;
			bdTimer.start();
		}
		private function getTimeout():int{
			var timeout:int=0;
			while (timeout<BD_TIMEOUT_MIN){
				timeout=Math.random()*(BD_TIMEOUT_MAX+BD_TIMEOUT_MIN*bdAttempt);
			}
			return timeout;
		}
		private function onBdTimer(e:Event):void{
			bdTimer.removeEventListener(TimerEvent.TIMER,onBdTimer);
			bdFunction();
		}


		public function start():void{
			if(!prepared) return;
			if(isRunning) return;
			if(!barcodeReader || ! controller){
				//TODO err?
				return;
			}
			log('start');
			currBarcode=null;
			currPgId='';
			currBookTot=-1;
			currBookIdx=-1;
			currSheetTot=-1;
			currSheetIdx=-1;

			currentGroup= COMMAND_GROUP_START;
			isRunning=true;
			isPaused=false;
			nextStep();
		}

		public function resume():void{
			if(!isRunning) return;
			log('resume');
			resetLatches();
			isPaused=false;
			nextStep();
		}

		public function pause(alert:String):void{
			log('pause: '+alert);
			controller.close(currentTray);
			currentTray=-1;
			isPaused=true;
			dispatchEvent(new ErrorEvent(ErrorEvent.ERROR,false,false,alert));
		}

		public function stop():void{
			log('stop');
			controller.close(currentTray);
			currentTray=-1;
			isRunning=false;
			isPaused=false;
			resetLatches();
		}
		
		private function nextStep():void{
			if(!isRunning || isPaused) return
			switch(currentGroup){
				case COMMAND_GROUP_START:
					/*
					switch(currentGroupStep){
						case 0:
							//close all
							aclLatch.setOn();
							controller.closeAll();
							break;
						case 1:
							//vacuum
							aclLatch.setOn();
							controller.vacuumOn();
							break;
						case 2:
							//engine
							aclLatch.setOn();
							controller.engineOn();
							break;
						default:
							currentGroup= COMMAND_GROUP_BOOK_START;
							nextStep();
							break;
					}
					*/
					currentGroup= COMMAND_GROUP_BOOK_START;
					nextStep();
					return;
				case COMMAND_GROUP_BOOK_START:
					//check completed
					if(currentGroupStep>=layerset.sequenceStart.length){
						//complited
						currentGroup= COMMAND_GROUP_BOOK_SHEET;
						nextStep();
						return;
					}
					feedLayer(layerset.sequenceStart[currentGroupStep] as LayerSequence);
					break;
				case COMMAND_GROUP_BOOK_SHEET:
					//check completed
					if(currentGroupStep>=1){
						//complited
						if (currSheetIdx>=currSheetTot){ 
							//book complited
							currentGroup= COMMAND_GROUP_BOOK_END;
						}else{
							currentGroup= COMMAND_GROUP_BOOK_BETWEEN_SHEET;
						}
						nextStep();
						return;
					}
					feedSheet();
					break;
				case COMMAND_GROUP_BOOK_BETWEEN_SHEET:
					//check completed
					if(currentGroupStep>=layerset.sequenceMiddle.length){
						//complited
						currentGroup= COMMAND_GROUP_BOOK_SHEET;
						nextStep();
						return;
					}
					feedLayer(layerset.sequenceMiddle[currentGroupStep] as LayerSequence);
					break;
				case COMMAND_GROUP_BOOK_END:
					//check completed
					if(currentGroupStep>=layerset.sequenceEnd.length){
						if(logger) logger.clear();
						if (currBookIdx>=currBookTot){ 
							//order complited
							//TODO check finalise?
							register.finalise();
							currBookTot=-1;
							currBookIdx=-1;
							currSheetTot=-1;
							currSheetIdx=-1;
							pause('Заказ '+currPgId+' завершен.');
						}else{
							//current book complited
							currentGroup= COMMAND_GROUP_BOOK_START;
							nextStep();
						}
						return;
					}
					feedLayer(layerset.sequenceEnd[currentGroupStep] as LayerSequence);
					break;
				default:
					break;
			}
		}

		private function feedLayer(ls:LayerSequence):void{
			if(!ls) return;
			waiteTraySwitch=false;
			currentLayer=layerset.getLayer(ls.seqlayer);
			if(!currentLayer){
				pause('Ошибка выполнения. Слой не определен.');
				return;
			}
			var ct:int=currentLayer.currentTray;
			if(ct<=0){
				pause('Не назначен лоток для слоя '+ currentLayer.name);
				return;
			}
			currentTray=ct-1;
			//set latches
			layerLatch.layer=currentLayer.id;
			layerLatch.startingTray=currentTray;
			layerLatch.setOn();
			aclLatch.setOn();
			controller.open(currentTray);
		}

		private function feedSheet():void{
			waiteTraySwitch=false;
			currentLayer=layerset.getLayer(Layer.LAYER_SHEET);
			if(!currentLayer){
				pause('Ошибка выполнения. Слой не определен.');
				return;
			}
			var ct:int=currentLayer.currentTray;
			if(ct<=0){
				pause('Не назначен лоток для слоя '+ currentLayer.name);
				return;
			}
			currentTray=ct-1;
			//set latches
			layerLatch.layer=currentLayer.id;
			layerLatch.startingTray=currentTray;
			layerLatch.setOn();
			barLatch.setOn();
			aclLatch.setOn();
			controller.open(currentTray);
		}

		private function onLatchTimeout(event:ErrorEvent):void{
			if(!isRunning || isPaused) return;
			var l:PickerLatch=event.target as PickerLatch;
			if(!l) return; 
			switch(l.type){
				case PickerLatch.TYPE_ACL:
				case PickerLatch.TYPE_BARCODE:
				case PickerLatch.TYPE_REGISTER:
					pause('Таймаут ожидания.');
					break;
				case PickerLatch.TYPE_LAYER:
					if(layerLatch.step==0){
						//layer not in
						//close current
						waiteTraySwitch=true;
						aclLatch.setOn();
						controller.close(currentTray);
						currentTray=-1;
					}else{
						//layer not out
						pause('Застрял слой '+currentLayer.name);
					}
					break;
			}
		}
		
		private function onLatchRelease(event:Event):void{
			if(!isRunning || isPaused) return;
			var l:PickerLatch=event.target as PickerLatch;
			if(l && l.type==PickerLatch.TYPE_ACL && waiteTraySwitch){
				//try next tray
				waiteTraySwitch=false;
				var ct:int=currentLayer.nextTray()-1;
				if(layerLatch.startingTray==ct){
					pause('Заполните лотки для слоя '+currentLayer.name);
					return;
				}
				currentTray=ct;
				layerLatch.setOn();
				aclLatch.setOn();
				controller.open(currentTray);
				return;
			}
			checkLatches();
		}

		private function resetLatches():void{
			var l:PickerLatch;
			for each(l in latches){
				l.reset();
			}
		}

		private function checkLatches():void{
			var complite:Boolean=true;
			var l:PickerLatch;
			for each(l in latches){
				if(l.isOn){
					complite=false;
					break;
				}
			}
			if(complite){
				currentGroupStep++;
				nextStep();
			}
		}
		
		private function onControllerErr(event:ErrorEvent):void{
			pause('Ошибка контролера: '+event.text);
		}
		private function onControllerCommandComplite(event:Event):void{
			aclLatch.forward();
		}
		private function onControllerMsg(event:ControllerMesageEvent):void{
			if(event.chanel==0){
				if(!layerLatch.isOn){
					pause('Не ожидаемое срабатывание датчика бумаги');
					return;
				}
				if(event.state==1){
					//layer in
					if(layerLatch.step==0){
						layerLatch.forward('Ожидание выхода листа');
						aclLatch.setOn();
						controller.close(currentTray);
						currentTray=-1;
					}
				}else if(layerLatch.step==1){
					//layer out
					if(currentGroup!=COMMAND_GROUP_BOOK_SHEET) currBarcode=null; //barcode covered vs some layer
					layerLatch.forward();
				}
			}
		}

		private function onBarCode(event:BarCodeEvent):void{
			var barcode:String=event.barcode;
			log('barcod: '+barcode);
			if(!isRunning || isPaused) return;
			if(!barLatch.isOn && barcode!=currBarcode){
				//currBarcode=barcode;
				pause('Не ожидаемое срабатывание сканера ШК, код:' +barcode);
				return;
			}
			currBarcode=barcode;
			//parce barcode
			var pgId:String;
			if(barcode.length>10) pgId=barcode.substr(10);
			if(!pgId){
				pause('Не верный штрих код: '+barcode);
				return;
			}
			var bookNum:int=int(barcode.substr(0,3));
			var pageNum:int=int(barcode.substr(6,2));
			if(currSheetIdx==-1){
				//new register
				//TODO add template check
				currPgId=pgId;
				currBookTot=int(barcode.substr(3,3));
				currSheetTot=int(barcode.substr(8,2));
				register= new TechRegisterPicker(pgId,currBookTot,currSheetTot);
				register.techPoint=techPoint;
				register.revers=reversOrder;
			}else{
				if(pgId!=currPgId){
					pause('Не верный заказ разворота, текущий: '+currPgId+', заказ разворота'+pgId);
					return;

				}
			}
			//check sequence
			registerLatch.setOn();
			register.register(bookNum,pageNum);
			barLatch.forward();
		}
		private function onBarError(event:BarCodeEvent):void{
			pause('Ошибка сканера ШК: '+event.error);
		}

		private function onRegisterErr(event:ErrorEvent):void{
			pause(event.text);
		}
		private function onRegisterComplite(event:Event):void{
			currBookIdx=register.currentBook;
			currSheetIdx=register.currentSheet;
			registerLatch.forward();
		}
		private function log(msg:String):void{
			if(logger) logger.log(msg);
		}

	}
}