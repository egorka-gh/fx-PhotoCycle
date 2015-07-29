package com.photodispatcher.tech.picker{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.event.BarCodeEvent;
	import com.photodispatcher.event.ControllerMesageEvent;
	import com.photodispatcher.event.SerialProxyEvent;
	import com.photodispatcher.interfaces.ISimpleLogger;
	import com.photodispatcher.model.mysql.DbLatch;
	import com.photodispatcher.model.mysql.entities.FieldValue;
	import com.photodispatcher.model.mysql.entities.Layer;
	import com.photodispatcher.model.mysql.entities.LayerSequence;
	import com.photodispatcher.model.mysql.entities.Layerset;
	import com.photodispatcher.model.mysql.entities.OrderExtraInfo;
	import com.photodispatcher.model.mysql.entities.PrintGroup;
	import com.photodispatcher.model.mysql.entities.TechPoint;
	import com.photodispatcher.model.mysql.services.OrderService;
	import com.photodispatcher.service.barcode.ComInfo;
	import com.photodispatcher.service.barcode.ComReader;
	import com.photodispatcher.service.barcode.ComReaderEmulator;
	import com.photodispatcher.service.barcode.SerialProxy;
	import com.photodispatcher.service.barcode.Socket2Com;
	import com.photodispatcher.service.barcode.ValveController;
	import com.photodispatcher.tech.TechRegisterPicker;
	import com.photodispatcher.util.ArrayUtil;
	
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.TimerEvent;
	import flash.net.SharedObject;
	import flash.text.ReturnKeyLabel;
	import flash.utils.Timer;
	import flash.utils.setInterval;
	
	import mx.collections.ArrayCollection;
	import mx.controls.Alert;
	
	import org.granite.tide.Tide;
	
	[Event(name="error", type="flash.events.ErrorEvent")]
	public class TechPicker extends EventDispatcher{
		public static const START_DELAY:int	=2000;

		public static const COMMAND_GROUP_BOOK_START:int	=0;
		public static const COMMAND_GROUP_BOOK_SHEET:int	=1;
		public static const COMMAND_GROUP_BOOK_BETWEEN_SHEET:int	=2;
		public static const COMMAND_GROUP_BOOK_END:int		=3;
		public static const COMMAND_GROUP_ORDER_END:int		=4;
		public static const COMMAND_GROUP_START:int			=5;
		public static const COMMAND_GROUP_PAUSE:int			=6;
		public static const COMMAND_GROUP_RESUME:int		=7;
		public static const COMMAND_GROUP_STOP:int			=8;
		
		private static const BD_TIMEOUT_MIN:int=300;
		private static const BD_TIMEOUT_MAX:int=1000;
		private static const BD_MAX_WAITE:int=10000;

 
		[Bindable]
		public var prepared:Boolean; 
		[Bindable]
		public var traySet:TraySet;
		[Bindable]
		public var interlayerSet:InterlayerSet; 
		[Bindable]
		public var endpaperSet:EndpaperSet;//:EndpaperSetKill; 
		[Bindable]
		public var currInerlayer:Layerset;
		
		private var _inexactBookSequence:Boolean=false;
		[Bindable]
		public function get inexactBookSequence():Boolean{
			return _inexactBookSequence;
		}
		public function set inexactBookSequence(value:Boolean):void{
			_inexactBookSequence = value;
			if(_inexactBookSequence) detectFirstBook=false;
		}

		private var _detectFirstBook:Boolean=false;
		[Bindable]
		public function get detectFirstBook():Boolean{
			return _detectFirstBook;
		}
		public function set detectFirstBook(value:Boolean):void{
			_detectFirstBook = value;
			if(_detectFirstBook) inexactBookSequence=false;
		}

		
		private var techGroup:int;

		[Bindable]
		public var currEndpaper:Layerset;
		
		[Bindable]
		public var currBookTypeName:String=''; 
		
		public var engineOnStartOn:Boolean=false;
		public var vacuumOnStartOn:Boolean=false;
		public var engineOnErrOff:Boolean=false;
		public var vacuumOnErrOff:Boolean=false;
		
		public var stopOnComplite:Boolean=false;
		public var pauseOnComplite:Boolean=false;
		public var layerOnComplite:int=0;
		
		private var _serialProxy:SerialProxy;
		public function get serialProxy():SerialProxy{
			return _serialProxy;
		}
		public function set serialProxy(value:SerialProxy):void{
			if(_serialProxy){
				_serialProxy.removeEventListener(SerialProxyEvent.SERIAL_PROXY_START,onSerialProxyStart);
				_serialProxy.removeEventListener(SerialProxyEvent.SERIAL_PROXY_ERROR, onProxyErr);
				_serialProxy.removeEventListener(SerialProxyEvent.SERIAL_PROXY_CONNECTED, onProxyConnect0);
			}
			_serialProxy = value;
			if(_serialProxy){
				_serialProxy.addEventListener(SerialProxyEvent.SERIAL_PROXY_START,onSerialProxyStart);
				_serialProxy.addEventListener(SerialProxyEvent.SERIAL_PROXY_ERROR, onProxyErr);
				_serialProxy.addEventListener(SerialProxyEvent.SERIAL_PROXY_CONNECTED, onProxyConnect0,false,10);
				if(_serialProxy.isStarted) _serialProxy.connectAll();
			}
		}
		private function onSerialProxyStart(evt:SerialProxyEvent):void{
			log('SerialProxy: started, connect to com proxies...');
			serialProxy.connectAll();
		}

		private function onProxyConnect0(evt:SerialProxyEvent):void{
			log('SerialProxy: connected, start devices');
			startDevices();
		}
		private function onProxyErr(evt:SerialProxyEvent):void{
			log('SerialProxy error: '+evt.error);
			dispatchEvent(new ErrorEvent(ErrorEvent.ERROR,false,false,evt.error));
		}

		
		/*
		public var engineOnCompliteOff:Boolean=false;
		public var vacuumOnCompliteOff:Boolean=false;
		public var askOnComplite:Boolean=false;
		public var layerOnComplite:Boolean=false;
		public var layerOnCompliteTray:int=1;
		*/

		public var techPoint:TechPoint;
		public var reversOrder:Boolean;
		
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
		private var layerInLatch:PickerLatch;
		private var layerOutLatch:PickerLatch;
		private var barLatch:PickerLatch;
		private var registerLatch:PickerLatch;
		private var bdLatch:PickerLatch;
		
		//print group params
		[Bindable]
		public var currExtraInfo:OrderExtraInfo
		[Bindable]
		public var currPgId:String='';
		private var currBarcode:String;
		private var currReprints:Array;
		[Bindable]
		public var currBookTot:int;
		[Bindable]
		public var currBookIdx:int;
		[Bindable]
		public var currSheetTot:int;
		[Bindable]
		public var currSheetIdx:int;
		
		private var currentLayer:int;
		[Bindable]
		public  var currentTray:int=-1;
		private var waiteTraySwitch:Boolean;

		private var _logger:ISimpleLogger;
		public function get logger():ISimpleLogger{
			return _logger;
		}
		public function set logger(value:ISimpleLogger):void{
			_logger = value;
			//if(controller) controller.logger=value;
		}

		
		private var _turnInterval:int=1000; //1sec
		public function get turnInterval():int{
			return _turnInterval;
		}

		public function set turnInterval(value:int):void{
			_turnInterval = value;
			if(layerInLatch) layerInLatch.setTimeout(_turnInterval);
			if(barLatch) barLatch.setTimeout(_turnInterval);
		}
 
		public function TechPicker(techGroup:int){
			super(null);
			this.techGroup=techGroup;
			/*
			//create & fill trays
			traySet= new TraySet();
			if (!traySet.prepared) return;
			
			interlayerSet= new InterlayerSet();
			interlayerSet.init(techGroup);
			if (!interlayerSet.prepared) return;
			
			endpaperSet= new EndpaperSet();
			endpaperSet.init(techGroup);
			if (!endpaperSet.prepared) return;
			
			currEndpaper=endpaperSet.emptyEndpaper;

			aclLatch = new PickerLatch(PickerLatch.TYPE_ACL, 1,'Контроллер','Ожидание подтверждения команды', ValveController.ACKNOWLEDGE_TIMEOUT*3);
			//layerInLatch= new PickerLatch(PickerLatch.TYPE_LAYER, 2,'Фотодатчик','Ожидание листа',turnInterval)
			layerInLatch= new PickerLatch(PickerLatch.TYPE_LAYER_IN, 1,'Фотодатчик Вход','Ожидание листа',turnInterval);
			layerOutLatch= new PickerLatch(PickerLatch.TYPE_LAYER_OUT, 1,'Фотодатчик Выход','Ожидание выхода листа',1000); //1сек
			barLatch = new PickerLatch(PickerLatch.TYPE_BARCODE, 1,'Сканер','Ожидание штрихкода',turnInterval);
			registerLatch = new PickerLatch(PickerLatch.TYPE_REGISTER, 1,'Книга','Контроль очередности',ValveController.ACKNOWLEDGE_TIMEOUT*2);
			bdLatch= new PickerLatch(PickerLatch.TYPE_BD, 2,'База данных','Получение параметров заказа',2*BD_MAX_WAITE); //callDbLate wl pause after BD_MAX_WAITE
			
			latches=[aclLatch,layerInLatch,layerOutLatch,barLatch,registerLatch,bdLatch];
			var l:PickerLatch;
			for each(l in latches){
				l.addEventListener(ErrorEvent.ERROR, onLatchTimeout);
				l.addEventListener(Event.COMPLETE, onLatchRelease);
			}
			checkPrepared();
			*/
		}
		
		public function init():DbLatch{
			interlayerSet= new InterlayerSet();
			endpaperSet= new EndpaperSet();
			var initLatch:DbLatch= new DbLatch();
			initLatch.addEventListener(Event.COMPLETE, onInitLatch);
			initLatch.join(interlayerSet.init(techGroup));
			initLatch.join(endpaperSet.init(techGroup));
			initLatch.start();
			return initLatch;
		}
		protected function onInitLatch(evt:Event):void{
			var latch:DbLatch= evt.target as DbLatch;
			if(!latch) return;
			latch.removeEventListener(Event.COMPLETE,onInitLatch);
			if(!latch.complite) return;
		
			//create & fill trays
			traySet= new TraySet();
			if (!traySet.prepared) return;
			
			currEndpaper=endpaperSet.emptyEndpaper;
			
			aclLatch = new PickerLatch(PickerLatch.TYPE_ACL, 1,'Контроллер','Ожидание подтверждения команды', ValveController.ACKNOWLEDGE_TIMEOUT*3);
			//layerInLatch= new PickerLatch(PickerLatch.TYPE_LAYER, 2,'Фотодатчик','Ожидание листа',turnInterval)
			layerInLatch= new PickerLatch(PickerLatch.TYPE_LAYER_IN, 1,'Фотодатчик Вход','Ожидание листа',turnInterval);
			layerOutLatch= new PickerLatch(PickerLatch.TYPE_LAYER_OUT, 1,'Фотодатчик Выход','Ожидание выхода листа',1000); //1сек
			barLatch = new PickerLatch(PickerLatch.TYPE_BARCODE, 1,'Сканер','Ожидание штрихкода',turnInterval);
			registerLatch = new PickerLatch(PickerLatch.TYPE_REGISTER, 1,'Книга','Контроль очередности',ValveController.ACKNOWLEDGE_TIMEOUT*2);
			bdLatch= new PickerLatch(PickerLatch.TYPE_BD, 2,'База данных','Получение параметров заказа',2*BD_MAX_WAITE); //callDbLate wl pause after BD_MAX_WAITE
			
			latches=[aclLatch,layerInLatch,layerOutLatch,barLatch,registerLatch,bdLatch];
			var l:PickerLatch;
			for each(l in latches){
				l.addEventListener(ErrorEvent.ERROR, onLatchTimeout);
				l.addEventListener(Event.COMPLETE, onLatchRelease);
			}
			checkPrepared();
		}

		private function checkPrepared(alert:Boolean=false):Boolean{
			prepared=barcodeReaders && barcodeReaders.length>0 && 
				controller && controller.connected && 
				traySet && traySet.prepared && 
				interlayerSet && interlayerSet.prepared && 
				endpaperSet && endpaperSet.prepared && 
				_layerset && _layerset.prepared;
			//check barreaders
			var barsConnected:Boolean=false;
			var barReader:ComReader;
			if (barcodeReaders && barcodeReaders.length>0){
				barsConnected=true;
				for each(barReader in barcodeReaders){
					if(!barReader.connected){
						prepared=false;
						barsConnected=false;
						break;
					}
				}
			}
			if(!prepared && alert){
				var msg:String='';
				if(!barcodeReaders || barcodeReaders.length==0) msg='Не инициализированы сканеры ШК';
				if(!barsConnected) msg='\n Не подключены сканеры ШК';
				if(!controller) msg+='\n Не инициализирован контролер';
				if(controller && !controller.connected) msg+='\n Не подключен контролер';
				if(!traySet || !traySet.prepared) msg+='\n Не инициализирован набор лотков';
				if(!interlayerSet ||!interlayerSet.prepared) msg+='\n Не инициализирован набор прослоек';
				if(!endpaperSet || !endpaperSet.prepared) msg+='\n Не инициализирован набор форзацев';
				if(!_layerset || !_layerset.prepared) msg+='\n Не инициализирован текущий шаблон';
				Alert.show(msg);
			}
			return 	prepared;
		}
		
		public function destroy():void{
			var l:PickerLatch;
			for each(l in latches){
				l.removeEventListener(ErrorEvent.ERROR, onLatchTimeout);
				l.removeEventListener(Event.COMPLETE, onLatchRelease);
			}
			latches=null;
			logger=null;
			if(controller) controller.stop();
			var barReader:ComReader;
			if (barcodeReaders){
				for each(barReader in barcodeReaders) barReader.stop();
			}
			barcodeReaders=null;
			controller=null;
			register=null;
			/*
			if(bdTimer){
				bdTimer.reset();
				bdTimer.removeEventListener(TimerEvent.TIMER,onBdTimer);
				bdTimer=null;
			}
			*/
		}
		
		private var _layerset:Layerset;
		[Bindable]
		public function get layerset():Layerset{
			return _layerset;
		}
		public function set layerset(value:Layerset):void{
			if(value.layerset_group!=techGroup){
				_layerset =null;
			}else{
				_layerset = value;
			}
			if(_layerset) prepareTemplate();
		}
		
		
		private var pausedGroup:int=-1;
		private var pausedGroupStep:int=-1;

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
				if(!isServiceGroup(value)) currentTray=-1;
				var ls:LayerSequence;
				switch(value){
					/*
					case COMMAND_GROUP_START:
						break;
					*/
					case COMMAND_GROUP_BOOK_START:
						if(!currEndpaper || currEndpaper.is_passover){
							currentSequence=layerset.sequenceStart.toArray();
						}else{
							currentSequence=currEndpaper.sequenceStart.toArray();
						}
						break;
					case COMMAND_GROUP_BOOK_SHEET:
						ls= new LayerSequence();
						ls.layer_group=COMMAND_GROUP_BOOK_SHEET;
						ls.seqlayer=Layer.LAYER_SHEET;
						ls.seqlayer_name='Разворот';
						ls.seqorder=1;
						currentSequence=[ls];
						break;
					case COMMAND_GROUP_BOOK_BETWEEN_SHEET:
						if(currInerlayer){
							currentSequence=currInerlayer.sequenceMiddle.toArray();
						}else{
							currentSequence=[];
						}
						break;
					case COMMAND_GROUP_BOOK_END:
						if(!currEndpaper || currEndpaper.is_passover){
							currentSequence=layerset.sequenceEnd.toArray();
						}else{
							currentSequence=currEndpaper.sequenceEnd.toArray();
						}
						break;
					case COMMAND_GROUP_ORDER_END:
						ls= new LayerSequence();
						ls.layer_group=COMMAND_GROUP_ORDER_END;
						ls.seqlayer=layerOnComplite;
						ls.seqlayer_name=traySet.getLayerName(layerOnComplite);
						ls.seqorder=1;
						currentSequence=[ls];
						break;
					default:
						currentSequence=[];
						break;
				}

				log('group: '+value.toString());
			}
			_currentGroup = value;
		}

		private var _barcodeReaders:Array;
		protected function get barcodeReaders():Array{
			return _barcodeReaders;
		}
		protected function set barcodeReaders(value:Array):void{
			var barReader:ComReader;
			if(_barcodeReaders){
				for each(barReader in _barcodeReaders){
					barReader.removeEventListener(BarCodeEvent.BARCODE_READED,onBarCode);
					barReader.removeEventListener(BarCodeEvent.BARCODE_ERR, onBarError);
					barReader.removeEventListener(BarCodeEvent.BARCODE_DISCONNECTED, onBarDisconnect);
					//barReader.stop();
				}
			}
			_barcodeReaders = value;
			if(_barcodeReaders){
				for each(barReader in _barcodeReaders){
					barReader.addEventListener(BarCodeEvent.BARCODE_READED,onBarCode);
					barReader.addEventListener(BarCodeEvent.BARCODE_ERR, onBarError);
					barReader.addEventListener(BarCodeEvent.BARCODE_DISCONNECTED, onBarDisconnect);
				}
			}
			//checkPrepared();
		}

		private var _controller:ValveController;
		[Bindable]
		public function get controller():ValveController{
			return _controller;
		}
		public function set controller(value:ValveController):void{
			if(_controller){
				_controller.removeEventListener(ErrorEvent.ERROR, onControllerErr);
				_controller.removeEventListener(BarCodeEvent.BARCODE_DISCONNECTED, onControllerDisconnect);
				_controller.removeEventListener(Event.COMPLETE, onControllerCommandComplite);
				_controller.removeEventListener(ControllerMesageEvent.CONTROLLER_MESAGE_EVENT,onControllerMsg);
			}
			_controller = value;
			if(_controller){
				_controller.logger=logger;
				_controller.addEventListener(ErrorEvent.ERROR, onControllerErr);
				_controller.addEventListener(BarCodeEvent.BARCODE_DISCONNECTED, onControllerDisconnect);
				_controller.addEventListener(Event.COMPLETE, onControllerCommandComplite);
				_controller.addEventListener(ControllerMesageEvent.CONTROLLER_MESAGE_EVENT,onControllerMsg);
			}
			//checkPrepared();
		}
		
		private function onControllerDisconnect(event:BarCodeEvent):void{
			log('Отключен контролер '+event.barcode);
			//pause('Отключен контролер '+event.barcode); busy bug
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

		private function prepare():Boolean{
			return false;
		}

		private function prepareTemplate():void{
			if(!_layerset){
				prepared=false;
				return;
			}
			checkPrepared();
		}

		public function start():void{
			if(!serialProxy) return;
			log('Start');
			if(!serialProxy.isStarted){
				log('SerialProxy not started...');
				return;
			}
			//connect
			serialProxy.addEventListener(SerialProxyEvent.SERIAL_PROXY_CONNECTED, onProxyConnect);
			serialProxy.connectAll();
		}
		
		private function onProxyConnect(evt:SerialProxyEvent):void{
			log('SerialProxy: connected to com proxies (start)');
			serialProxy.removeEventListener(SerialProxyEvent.SERIAL_PROXY_CONNECTED, onProxyConnect);
			//startDevices()
			startInternal();
		}
		private function startDevices():void{
			//create devs
			var proxy:Socket2Com=serialProxy.getProxy(ComInfo.COM_TYPE_CONTROLLER);
			if(!controller) controller= new ValveController();
			controller.start(proxy);

			//var barReader:ComReader;
			var readers:Array= serialProxy.getProxiesByType(ComInfo.COM_TYPE_BARREADER);
			if(!readers || readers.length==0) return;
			var i:int;
			if(!barcodeReaders){
				//init bar readers
				var newBarcodeReaders:Array=[];
				for (i=0; i<readers.length; i++) newBarcodeReaders.push(new ComReader(500));
				barcodeReaders=newBarcodeReaders;
			}
			if(readers.length!=barcodeReaders.length){
				barcodeReaders=null;
				return;
			}
			//start readers
			for (i=0; i<readers.length; i++) (barcodeReaders[i] as ComReader).start(readers[i]);
		}

		protected function startInternal():void{
			hasPauseRequest=false;
			if(!checkPrepared(true)) return;
			if(isRunning){
				resume();
				return;
			}
			if(!barcodeReaders || barcodeReaders.length==0 || ! controller){
				//TODO err?
				return;
			}
			if(logger) logger.clear();
			log('start');
			currBarcode=null;
			currPgId='';
			currExtraInfo=null;
			currBookTot=-1;
			currBookIdx=-1;
			currSheetTot=-1;
			currSheetIdx=-1;
			pausedGroup=-1;
			pausedGroupStep=-1;
			
			currentGroup= COMMAND_GROUP_START;
			isRunning=true;
			isPaused=false;
			nextStep();
		}

		private function resume():void{
			if(!isRunning || !isPaused) return;
			if(pausedGroup==-1 || pausedGroupStep==-1) return;
			log('start resume');
			resetLatches();
			isPaused=false;
			currentGroup= COMMAND_GROUP_RESUME;
			nextStep();
		}

		private var hasPauseRequest:Boolean=false;
		public function pauseRequest():void{
			if(hasPauseRequest) return;
			if(isServiceGroup(currentGroup)) return;
			log('pause request');
			hasPauseRequest=true;
		}

		private function pause(alert:String, isError:Boolean=true):void{
			if(!isRunning) return;
			if(isPaused) return;
			if(currentGroup==COMMAND_GROUP_STOP || currentGroup==COMMAND_GROUP_PAUSE){
				log('service sequence: '+alert);
				return;
			}
			hasPauseRequest=false;
			log('pause sequence: '+alert);
			if(!isServiceGroup(currentGroup)){
				pausedGroup=currentGroup;
				pausedGroupStep=currentGroupStep;
			}
			resetLatches();
			currentGroup= COMMAND_GROUP_PAUSE;
			nextStep();
			if(isError) dispatchEvent(new ErrorEvent(ErrorEvent.ERROR,false,false,alert));
		}
		private function pauseComplete():void{
			hasPauseRequest=false;
			isPaused=true;
			currentTray=-1;
			log('paused');
			currentGroup=pausedGroup;
			currentGroupStep=pausedGroupStep;
			log('restarting SerialProxy...');
			serialProxy.restart();
		}
		
		private function isServiceGroup(group:int):Boolean{
			return (group==COMMAND_GROUP_START || group==COMMAND_GROUP_STOP || group==COMMAND_GROUP_PAUSE || group==COMMAND_GROUP_RESUME);
		}

		public function stop():void{
			if(!isRunning) return;
			if(isPaused) isPaused=false;
			log('stop sequence');
			resetLatches();
			currentGroup= COMMAND_GROUP_STOP;
			nextStep();
		}
		private function stopComplite():void{
			log('stoped');
			currentTray=-1;
			pausedGroup=-1;
			pausedGroupStep=-1;
			register=null;
			inexactBookSequence=false;
			detectFirstBook=false;
			isRunning=false;
			isPaused=false;
			resetLatches();
			/*
			controller.stop();
			var barReader:ComReader;
			if (barcodeReaders){
				for each(barReader in barcodeReaders) barReader.stop();
			}
			*/
		}
		
		private var delayTimer:Timer;
		
		private function runDelayTimer():void{
			log('Задержка старта (2сек)');
			if(!delayTimer){
				delayTimer=new Timer(START_DELAY,1);
				delayTimer.addEventListener(TimerEvent.TIMER,onDelayTimer); 
			}
			delayTimer.reset();
			delayTimer.start();
		}
		
		private function onDelayTimer(evt:TimerEvent):void{
			nextStep();
		}
		
		private function nextStep():void{
			if(!isRunning || isPaused) return;
			if(hasPauseRequest){
				hasPauseRequest=false;
				pause('Пауза по запросу пользователя',false);
				return;
			}
			var steps:int=0;
			switch(currentGroup){
				case COMMAND_GROUP_START:
					if (vacuumOnStartOn) steps++;
					if (engineOnStartOn) steps++;
					if(currentGroupStep>=steps){
						//complite
						currentGroup= COMMAND_GROUP_BOOK_START;
						//nextStep();
						runDelayTimer();
						return;
					}
					if(currentGroupStep==0 && vacuumOnStartOn){
						//log('vacuumOn');
						aclLatch.setOn();
						controller.vacuumOn();
						return;
					}
					//log('engineOn');
					aclLatch.setOn();
					controller.engineOn();
					break;
				case COMMAND_GROUP_PAUSE:
					steps=3;
					if(currentGroupStep>=steps){
						//complite
						pauseComplete();
						return;
					}
					switch(currentGroupStep){
						case 0:
							if(currentTray!=-1){
								aclLatch.setOn();
								controller.close(currentTray);
							}else{
								currentGroupStep++;
								nextStep();
							}
							break;
						case 1:
							if (vacuumOnErrOff){
								aclLatch.setOn();
								controller.vacuumOff();
							}else{
								currentGroupStep++;
								nextStep();
							}
							break;
						case 2:
							if (engineOnErrOff){
								aclLatch.setOn();
								controller.engineOff();
							}else{
								currentGroupStep++;
								nextStep();
							}
							break;
					}
					break;
				case COMMAND_GROUP_RESUME:
					steps=2;
					if(currentGroupStep>=steps){
						//complite 
						//restore paused step
						if(pausedGroup!=-1 && pausedGroupStep!=-1){
							log('Resume complited');
							currentGroup=pausedGroup;
							currentGroupStep=pausedGroupStep;
							pausedGroup=-1;
							pausedGroupStep=-1;
							//nextStep();
							runDelayTimer();
						}
						return;
					}
					switch(currentGroupStep){
						case 0:
							if (vacuumOnErrOff){
								aclLatch.setOn();
								controller.vacuumOn();
							}else{
								currentGroupStep++;
								nextStep();
							}
							break;
						case 1:
							if (engineOnErrOff){
								aclLatch.setOn();
								controller.engineOn();
							}else{
								currentGroupStep++;
								nextStep();
							}
							break;
					}
					break;
				case COMMAND_GROUP_STOP:
					steps=3;
					if(currentGroupStep>=steps){
						//complite
						stopComplite();
						return;
					}
					switch(currentGroupStep){
						case 0:
							if(currentTray!=-1){
								aclLatch.setOn();
								controller.close(currentTray);
							}else{
								currentGroupStep++;
								nextStep();
							}
							break;
						case 1:
							aclLatch.setOn();
							controller.vacuumOff();
							break;
						case 2:
							aclLatch.setOn();
							controller.engineOff();
							break;
					}
					break;
				case COMMAND_GROUP_BOOK_START:
					//check completed
					if(currentGroupStep>=currentSequence.length){
						//complited
						currentGroup= COMMAND_GROUP_BOOK_SHEET;
						nextStep();
						return;
					}
					feedLayer(currentSequence[currentGroupStep] as LayerSequence);
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
					/*
					if(!currInerlayer){
						pause('Не определена прослойка.');
						return;
					}
					*/
					//check completed
					if(!currInerlayer || currentGroupStep>=currInerlayer.sequenceMiddle.length){
						//complited
						currentGroup= COMMAND_GROUP_BOOK_SHEET;
						nextStep();
						return;
					}
					feedLayer(currInerlayer.sequenceMiddle[currentGroupStep] as LayerSequence);
					break;
				case COMMAND_GROUP_BOOK_END:
					//check completed
					if(currentGroupStep>=currentSequence.length){
						if(logger) logger.clear();
						//if (currBookIdx>=currBookTot){ 
						if (register.isComplete){
							//order complited
							detectFirstBook=false;
							register.finalise();
							register=null;
							currBookTot=-1;
							currBookIdx=-1;
							currSheetTot=-1;
							currSheetIdx=-1;
							log('Заказ '+currPgId+' завершен.');
							currPgId='';
							currExtraInfo=null;
							currentGroup= COMMAND_GROUP_ORDER_END;
							nextStep();
						}else{
							//current book complited
							currentGroup= COMMAND_GROUP_BOOK_START;
							nextStep();
						}
						return;
					}
					feedLayer(currentSequence[currentGroupStep] as LayerSequence);
					break;
				case COMMAND_GROUP_ORDER_END:
					if(currentGroupStep>=1){
						//complite
						if(stopOnComplite){
							stop();
							return;
						}
						currentGroup= COMMAND_GROUP_BOOK_START;
						if(pauseOnComplite){
							pause('Пауза между заказами',false);
							return;
						}
						nextStep();
						return;
					}
					feedLayer(currentSequence[0] as LayerSequence);
					break;
				default:
					log('Не определена последовательность');
					break;
			}
		}

		private function feedLayer(ls:LayerSequence):void{
			if(!ls) return;
			waiteTraySwitch=false;
			if(ls.seqlayer==Layer.LAYER_EMPTY){
				//skip 
				currentGroupStep++;
				nextStep();
				return;
			}
			currentLayer=ls.seqlayer;
			if(!currentLayer){
				pause('Ошибка выполнения. Слой не определен.');
				return;
			}
			var ct:int=traySet.getCurrentTray(currentLayer);
			if(ct<0){
				pause('Не назначен лоток для слоя '+traySet.getLayerName(currentLayer));
				return;
			}
			currentTray=ct;//-1;
			//set latches
			layerInLatch.layer=currentLayer;
			layerInLatch.startingTray=currentTray;
			layerInLatch.setOn();
			aclLatch.setOn();
			controller.open(currentTray);
		}

		private function feedSheet():void{
			waiteTraySwitch=false;
			currentLayer=Layer.LAYER_SHEET;
			var ct:int=traySet.getCurrentTray(currentLayer);
			if(ct<0){
				pause('Не назначен лоток для слоя '+traySet.getLayerName(currentLayer));
				return;
			}
			currentTray=ct;
			//set latches
			layerInLatch.layer=currentLayer;
			layerInLatch.startingTray=currentTray;
			layerInLatch.setOn();
			if(barcodeReaders && barcodeReaders.length>0 && barcodeReaders[0] is ComReaderEmulator) (barcodeReaders[0] as ComReaderEmulator).emulateNext(); 
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
					if(isServiceGroup(currentGroup)){
						//skip
						//log('ACL Timeout - skipped (service group)');
						l.reset();
						checkLatches();
						break;
					}
				case PickerLatch.TYPE_REGISTER:
					pause('Таймаут ожидания. '+l.label+':'+l.caption);
					break;
				case PickerLatch.TYPE_BARCODE:
					if(layerInLatch.isOn || layerOutLatch.isOn || waiteTraySwitch){
						//sheet is not in or not out; restart
						//also restart barLatch on waiteTraySwitch complite
						barLatch.setOn();
					}else{
						//TODO neve run?
						if(register && register.inexactBookSequence && register.currentBookComplited){
							register.finalise();
							register=null;
							inexactBookSequence=false;
							log('Сборка брака завершена: заказ "'+currPgId+'"');
							stop();
							return;
						}
						pause('Таймаут ожидания. '+l.label+':'+l.caption);
					}
					break;
				case PickerLatch.TYPE_LAYER_IN:
					//layer not in
					//close current
					waiteTraySwitch=true;
					aclLatch.setOn();
					controller.close(currentTray);
					currentTray=-1;
					break;
				case PickerLatch.TYPE_LAYER_OUT:
					//layer not out
					pause('Застрял слой '+traySet.getLayerName(currentLayer));// currentLayer.name);
					break;
			}
		}
		
		private function onLatchRelease(event:Event):void{
			if(!isRunning || isPaused) return;
			var l:PickerLatch=event.target as PickerLatch;
			if(!l) return; 
			switch(l.type){
				case PickerLatch.TYPE_ACL:
					if(waiteTraySwitch){
						//try next tray
						waiteTraySwitch=false;
						var ct:int=traySet.getNextTray(currentLayer); 
						if(ct<0 || layerInLatch.startingTray==ct){
							//check if defect complited
							if(currentGroup==COMMAND_GROUP_BOOK_SHEET){
								if(register && register.inexactBookSequence && register.currentBookComplited){
									register.finalise();
									register=null;
									inexactBookSequence=false;
									log('Сборка брака завершена: заказ "'+currPgId+'"');
									stop();
									return;
								}
							}
							pause('Заполните лотки для слоя '+traySet.getLayerName(currentLayer));
							return;
						}
						currentTray=ct;
						layerInLatch.setOn();
						if(currentGroup==COMMAND_GROUP_BOOK_SHEET) barLatch.setOn(); //restart bar latch
						aclLatch.setOn();
						controller.open(currentTray);
						return;
						break;
					}
					/*
				case PickerLatch.TYPE_LAYER_IN:
					layerOutLatch.setOn();
					return;
					break;
					*/
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
				//log('checkLatches complite');
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
			if(!isRunning || isPaused) return;
			if(event.chanel==0){
				if(event.state==1){
					//layer in
					if(layerInLatch.isOn){
						aclLatch.setOn();
						controller.close(currentTray);
						currentTray=-1;
						layerOutLatch.setOn();
						layerInLatch.forward();
					}else{
						pause('Не ожидаемое срабатывание '+layerInLatch.label);
						return;
					}
				}else{
					if(layerOutLatch.isOn){
						//layer out
						if(currentGroup!=COMMAND_GROUP_BOOK_SHEET) currBarcode=null; //barcode covered vs some layer
						layerOutLatch.forward();
					}else{
						pause('Не ожидаемое срабатывание '+layerOutLatch.label);
						return;
					}
				}
			}
		}

		private function onBarCode(event:BarCodeEvent):void{
			var barcode:String=event.barcode;
			log('barcod: '+barcode);
			if(!isRunning || isPaused) return;
			if(!barLatch.isOn){
				//chek doublescan while barcode not covered vs next layer
				if(barcode!=currBarcode) pause('Не ожидаемое срабатывание сканера ШК, код:' +barcode);
				return;
			}
			if(barcode==currBarcode) return; //doublescan or more then 1 barreader
			currBarcode=barcode;
			//parce barcode
			var pgId:String;
			if(barcode.length>10) pgId=PrintGroup.idFromDigitId(barcode.substr(10));
			if(!pgId){
				pause('Не верный штрих код: '+barcode);
				return;
			}
			var bookNum:int=int(barcode.substr(0,3));
			var pageNum:int=int(barcode.substr(6,2));
			//if(currSheetIdx==-1){
			if(!register){
				//new order
				currPgId=pgId;
				currReprints=[];
				currBookTot=int(barcode.substr(3,3));
				currSheetTot=int(barcode.substr(8,2));
				/*
				//template check
				bdWait=0;
				bdAttempt=0;
				*/
				bdLatch.setOn();
				checkOrderParams();
				//new register
				register= new TechRegisterPicker(pgId,currBookTot,currSheetTot);
				register.techPoint=techPoint;
				register.revers=reversOrder;
				register.inexactBookSequence=inexactBookSequence;
				register.detectFirstBook=detectFirstBook;
				//reset detectFirstBook
				if(detectFirstBook) detectFirstBook=false;
			}else{
				if(!checkPrintgroup(pgId)){
					if(register.inexactBookSequence){
						//defect complited
						register.finalise();
						register=null;
						inexactBookSequence=false;
						pause('Сборка брака завершена: "'+currPgId+'", отделите заказ "'+currPgId+'" и начало новой книги "'+pgId+'"');
					}else{
						pause('Не верный заказ разворота, текущий: '+currPgId+', заказ разворота'+pgId);
					}
					return;
				}
			}
			//check sequence
			registerLatch.setOn();
			register.register(bookNum,pageNum);
			//barLatch.forward();
		}
		private function onBarError(event:BarCodeEvent):void{
			pause('Ошибка сканера ШК: '+event.error);
		}
		private function onBarDisconnect(event:BarCodeEvent):void{
			log('Отключен сканер ШК '+event.barcode);
			//pause('Отключен сканер ШК '+event.barcode); busy bug
		}

		private function checkPrintgroup(pgId:String):Boolean{
			var res:Boolean=pgId==currPgId;
			if(!res && currReprints){
				res=currReprints.indexOf(pgId)!=-1;
			}
			return res;
		}
		
		private function onRegisterErr(event:ErrorEvent):void{
			pause(event.text);
		}
		private function onRegisterComplite(event:Event):void{
			currBookIdx=register.currentBook;
			currSheetIdx=register.currentSheet;
			registerLatch.forward();
			barLatch.forward();
		}
		private function log(msg:String):void{
			if(logger) logger.log(msg);
		}
		
		private function checkOrderParams():void{
			if(!currPgId) return;
			var svc:OrderService=Tide.getInstance().getContext().byType(OrderService,true) as OrderService;
			var latch:DbLatch= new DbLatch();
			latch.addLatch(svc.loadExtraIfoByPG(currPgId));
			latch.addEventListener(Event.COMPLETE,onOrderFinde);
			//load reprints
			var latchR:DbLatch= new DbLatch();
			latchR.addEventListener(Event.COMPLETE,onReprintsLoad);
			latchR.addLatch(svc.loadReprintsByPG(currPgId));
			latchR.start();
			latch.join(latchR);
			latch.start();
		}
		private function onReprintsLoad(e:Event):void{
			currReprints=[];
			var latch:DbLatch=e.target as DbLatch;
			if(latch){
				latch.removeEventListener(Event.COMPLETE,onReprintsLoad);
				if(latch.complite){
					var list:Array=latch.lastDataArr;
					if(list){
						for each (var pg:PrintGroup in list){
							if(pg){
								currReprints.push(pg.id);
							}
						}
					}
				}
			}
		}
		private function onOrderFinde(e:Event):void{
			var latch:DbLatch=e.target as DbLatch;
			var ei:OrderExtraInfo;
			if(latch){
				latch.removeEventListener(Event.COMPLETE,onOrderFinde);
				ei=latch.lastDataItem as OrderExtraInfo;
			}
			if(!ei){
				//read error or not exists
				pause('Нет доп информации по заказу');
				log('! ExtraInfo not found');
				return;
			}
			currExtraInfo=ei;
			bdLatch.forward('Проверка заказа');
			
			currBookTypeName=getBookTypeName(currExtraInfo.book_type)
			//check book type
			if(!layerset.is_book_check_off && layerset.book_type!=currExtraInfo.book_type){
				pause('Тип книги "'+currBookTypeName+'" заказа не соответствует шаблону.');
				log('! wrong book_type');
				return;
			}
			//check interlayer
			currInerlayer=interlayerSet.getBySynonym(currExtraInfo.interlayer);
			if(currExtraInfo.interlayer && !currInerlayer){
				pause('Неизвестный тип прослойки "'+currExtraInfo.interlayer+'"');
				log('! unknown interlayer');
				return;
			}

			if(!layerset.is_epaper_check_off){
				//check endpaper
				var newEp:Layerset;
				if(currExtraInfo.endpaper){
					newEp=endpaperSet.getBySynonym(currExtraInfo.endpaper);
				}else{
					newEp=endpaperSet.emptyEndpaper;
				}
				if(!newEp){
					pause('Не известный форзац "'+currExtraInfo.endpaper+'"');
					log('! unknown endpaper');
					return;
				}
				if(newEp.id!=currEndpaper.id){
					pause('Форзац заказа "'+newEp.name+'" не соответствует текущему шаблону "'+currEndpaper.name+'"');
					log('! wrong endpaper');
					return;
				}
				currEndpaper=newEp;
			}
			
			bdLatch.forward();
			//TODO implement check format
		}

		private function getBookTypeName(bookType:int):String{
			var result:String;
			var ac:ArrayCollection=Context.getAttribute('book_typeList') as ArrayCollection;
			if(ac){
				var fv:FieldValue=ArrayUtil.searchItem('value',bookType,ac.source) as FieldValue;
				if(fv) result=fv.label;
			}
			if(!result) result='id:'+bookType;
			return result;
		}
	}
}