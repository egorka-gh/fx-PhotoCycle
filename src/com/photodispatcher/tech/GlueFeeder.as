package com.photodispatcher.tech{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.event.BarCodeEvent;
	import com.photodispatcher.event.ControllerMesageEvent;
	import com.photodispatcher.event.SerialProxyEvent;
	import com.photodispatcher.interfaces.ISimpleLogger;
	import com.photodispatcher.model.mysql.DbLatch;
	import com.photodispatcher.model.mysql.entities.FieldValue;
	import com.photodispatcher.model.mysql.entities.Layer;
	import com.photodispatcher.model.mysql.entities.LayerSequence;
	import com.photodispatcher.model.mysql.entities.PrintGroup;
	import com.photodispatcher.model.mysql.entities.TechPoint;
	import com.photodispatcher.model.mysql.services.OrderService;
	import com.photodispatcher.service.barcode.ComInfo;
	import com.photodispatcher.service.barcode.ComReader;
	import com.photodispatcher.service.barcode.ComReaderEmulator;
	import com.photodispatcher.service.barcode.FeederController;
	import com.photodispatcher.service.barcode.GlueController;
	import com.photodispatcher.service.barcode.SerialProxy;
	import com.photodispatcher.service.barcode.Socket2Com;
	import com.photodispatcher.tech.picker.PickerLatch;
	import com.photodispatcher.tech.plain_register.TechRegisterPicker;
	import com.photodispatcher.util.ArrayUtil;
	
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.TimerEvent;
	import flash.utils.Timer;
	
	import mx.collections.ArrayCollection;
	import mx.controls.Alert;
	
	import org.granite.tide.Tide;
	
	[Event(name="error", type="flash.events.ErrorEvent")]
	public class GlueFeeder extends GlueStreamed{
		public static const START_DELAY:int	=2000;

		//public static const COMMAND_GROUP_BOOK_START:int	=0;
		public static const COMMAND_GROUP_BOOK_SHEET:int	=1;
		//public static const COMMAND_GROUP_BOOK_BETWEEN_SHEET:int	=2;
		//public static const COMMAND_GROUP_BOOK_END:int		=3;
		//public static const COMMAND_GROUP_ORDER_END:int		=4;
		public static const COMMAND_GROUP_START:int			=5;
		public static const COMMAND_GROUP_PAUSE:int			=6;
		public static const COMMAND_GROUP_RESUME:int		=7;
		public static const COMMAND_GROUP_STOP:int			=8;
		
		protected static const BD_TIMEOUT_MIN:int=300;
		protected static const BD_TIMEOUT_MAX:int=1000;
		protected static const BD_MAX_WAITE:int=3000;

		//Latches
		protected var aclLatch:PickerLatch;
		protected var layerInLatch:PickerLatch;
		protected var layerOutLatch:PickerLatch;
		protected var barLatch:PickerLatch;
		protected var registerLatch:PickerLatch;
		protected var bdLatch:PickerLatch;
		
		protected var currentLayer:int;
		
		public function GlueFeeder(){
			super();
		}
		
		override public function init():void{
			
			aclLatch = new PickerLatch(PickerLatch.TYPE_ACL, 1,'Контроллер','Ожидание подтверждения команды', 200*3);
			//layerInLatch= new PickerLatch(PickerLatch.TYPE_LAYER, 2,'Фотодатчик','Ожидание листа',turnInterval)
			layerInLatch= new PickerLatch(PickerLatch.TYPE_LAYER_IN, 1,'Фотодатчик Вход','Ожидание листа',2000);
			barLatch = new PickerLatch(PickerLatch.TYPE_BARCODE, 1,'Сканер','Ожидание штрихкода',layerInLatch.getTimeout()+1000);
			layerOutLatch= new PickerLatch(PickerLatch.TYPE_LAYER_OUT, 1,'Фотодатчик Выход','Ожидание выхода листа',1000); //1сек
			registerLatch = new PickerLatch(PickerLatch.TYPE_REGISTER, 1,'Книга','Контроль очередности',200*2);
			bdLatch= new PickerLatch(PickerLatch.TYPE_BD, 1,'База данных','Получение параметров заказа',2*BD_MAX_WAITE); //callDbLate wl pause after BD_MAX_WAITE
			
			latches=[aclLatch,layerInLatch,layerOutLatch,barLatch,registerLatch,bdLatch];
			var l:PickerLatch;
			for each(l in latches){
				l.addEventListener(ErrorEvent.ERROR, onLatchTimeout);
				l.addEventListener(Event.COMPLETE, onLatchRelease);
			}
			checkPrepared();
		}

		override protected function checkPrepared(alert:Boolean=false):Boolean{
			prepared=barcodeReaders && barcodeReaders.length>0 && 
				controller && controller.connected &&
				glueHandler && glueHandler.isPrepared;
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
				if(!controller) msg+='\n Не инициализирован контролер подачи';
				if(controller && !controller.connected) msg+='\n Не подключен контролер подачи';
				if(!glueHandler || !glueHandler.isPrepared) msg+='\n Не инициализирована склейка';
				Alert.show(msg);
			}
			return 	prepared;
		}
		
		override public function destroy():void{
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
		}
		
		protected var pausedGroup:int=-1;
		protected var pausedGroupStep:int=-1;

		[Bindable]
		public var currentGroupStep:int;

		protected var _currentGroup:int;
		[Bindable]
		public function get currentGroup():int{
			return _currentGroup;
		}
		public function set currentGroup(value:int):void{
			if(_currentGroup != value){
				currentGroupStep=0;
			}
			_currentGroup = value;
		}

		protected var _controller:FeederController;
		
		public function get controller():FeederController{
			return _controller;
		}
		public function set controller(value:FeederController):void{
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
		
		override protected function onGlueHandlerErr(event:ErrorEvent):void{
			if(!isRunning || isPaused){
				log('Cклейка: '+event.text);
				return;
			}
			if(glueHandler.isRunning && glueHandler.hasPauseRequest){
				pauseRequest('Cклейка: '+event.text);
			}else{
				log('Cклейка: '+event.text);
				stop();
			}
		}
		
		protected function onControllerDisconnect(event:BarCodeEvent):void{
			log('Отключен контролер '+event.barcode);
			//pause('Отключен контролер '+event.barcode); busy bug
		}

		override public function start():void{
			if(!serialProxy) return;
			if(logger) logger.clear();

			log('Старт');
			if(!serialProxy.isStarted){
				log('SerialProxy not started...');
				return;
			}
			
			/*
			if(!isRunning){
				//connect
				serialProxy.addEventListener(SerialProxyEvent.SERIAL_PROXY_CONNECTED, onProxyConnect);
				serialProxy.connectAll();
			}else{
				if(!serialProxy.connected){
					log('SerialProxy часть COM портов не подключено');
					log('SerialProxy:' +serialProxy.traceDisconnected());
					return;
				}
				startInternal();	
			}
			*/
			if(!serialProxy.connected){
				//connect
				log('Ожидание подключения COM портов');
				serialProxy.addEventListener(SerialProxyEvent.SERIAL_PROXY_CONNECTED, onProxyConnect);
				serialProxy.connectAll();
				return;
			}
			startInternal();
		}

		override public function setEngineOn():void{
			if(controller) controller.engineOn(); 
		}
		override public function setEngineOff():void{
			if(controller) controller.engineOff(); 
		}
		override public function setVacuumOn():void{
			if(controller) controller.vacuumOn(); 
		}
		override public function setVacuumOff():void{
			if(controller) controller.vacuumOff(); 
		}

		override protected function onProxyConnect(evt:SerialProxyEvent):void{
			
			serialProxy.removeEventListener(SerialProxyEvent.SERIAL_PROXY_CONNECTED, onProxyConnect);
			log('SerialProxy: connect complite');
			if(!serialProxy.connected){
				log('Часть COM портов не подключено');
				log('SerialProxy:' +serialProxy.traceDisconnected());
			}

			//startDevices()
			startInternal();
		}
		override protected function startDevices():void{
			//create devs
			var proxy:Socket2Com=serialProxy.getProxy(ComInfo.COM_TYPE_CONTROLLER);
			if(!controller) controller= new FeederController();
			controller.start(proxy);

			/*
			if(!glueHandler) glueHandler=new GlueHandler();
			glueHandler.init(serialProxy);
			glueHandler.pushDelay=pushDelay;
			*/
			createGlueHandler();
			
			//var barReader:ComReader;
			var readers:Array= serialProxy.getProxiesByType(ComInfo.COM_TYPE_BARREADER);
			if(!readers || readers.length==0) return;
			var i:int;
			if(!barcodeReaders){
				//init bar readers
				var newBarcodeReaders:Array=[];
				for (i=0; i<readers.length; i++) newBarcodeReaders.push(new ComReader());
				barcodeReaders=newBarcodeReaders;
			}
			if(readers.length!=barcodeReaders.length){
				barcodeReaders=null;
				return;
			}
			//start readers
			for (i=0; i<readers.length; i++) (barcodeReaders[i] as ComReader).start(readers[i]);
		}

		override protected function startInternal():void{
			hasPauseRequest=false;
			startDevices();
			if(!checkPrepared(true)) return;
			if(!glueHandler || !glueHandler.start()){
				log('startInternal: glueHandler init error');
				return;
			}
			log('SerialProxy:' +serialProxy.traceDisconnected());
			if(!barcodeReaders || barcodeReaders.length==0 || ! controller){
				log('startInternal: barcodeReaders or controller init error');
				return;
			}
			log('SerialProxy:' +serialProxy.traceDisconnected());
			if(isRunning){
				resume();
				return;
			}
			log('start');
			currBarcode=null;
			currPgId='';
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

		protected function resume():void{
			if(!isRunning || !isPaused) return;
			if(pausedGroup==-1 || pausedGroupStep==-1) return;
			currBarcode=null;
			log('start resume');
			resetLatches();
			isPaused=false;
			currentGroup= COMMAND_GROUP_RESUME;
			nextStep();
		}

		protected var hasPauseRequest:Boolean=false;
		override public function pauseRequest(msg:String=''):void{
			if(hasPauseRequest) return;
			if(isServiceGroup(currentGroup)) return;
			log('Запрос паузы. '+msg);
			hasPauseRequest=true;
		}

		protected function pause(alert:String, isError:Boolean=true):void{
			log(alert);
			if(!isRunning) return;
			if(isPaused) return;
			if(currentGroup==COMMAND_GROUP_STOP || currentGroup==COMMAND_GROUP_PAUSE){
				log('service sequence');
				return;
			}
			hasPauseRequest=false;
			log('pause sequence');
			if(!isServiceGroup(currentGroup)){
				pausedGroup=currentGroup;
				pausedGroupStep=currentGroupStep;
			}
			resetLatches();
			currentGroup= COMMAND_GROUP_PAUSE;
			nextStep();
			if(isError) dispatchEvent(new ErrorEvent(ErrorEvent.ERROR,false,false,alert));
		}
		protected function pauseComplete():void{
			hasPauseRequest=false;
			isPaused=true;
			log('paused');
			currentGroup=pausedGroup;
			currentGroupStep=pausedGroupStep;
			/*
			log('restarting SerialProxy...');
			serialProxy.restart();
			*/
		}
		
		protected function isServiceGroup(group:int):Boolean{
			return (group==COMMAND_GROUP_START || group==COMMAND_GROUP_STOP || group==COMMAND_GROUP_PAUSE || group==COMMAND_GROUP_RESUME);
		}

		override public function stop():void{
			if(!isRunning) return;
			if(isPaused) isPaused=false;
			//if(glueHandler && glueHandler.isRunning) glueHandler.stop();
			log('stop sequence');
			resetLatches();
			currentGroup= COMMAND_GROUP_STOP;
			nextStep();
		}
		protected function stopComplite():void{
			log('stoped');
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
		
		protected var delayTimer:Timer;
		
		protected function runDelayTimer():void{
			log('Задержка старта (2сек)');
			if(!delayTimer){
				delayTimer=new Timer(START_DELAY,1);
				delayTimer.addEventListener(TimerEvent.TIMER,onDelayTimer); 
			}
			delayTimer.reset();
			delayTimer.start();
		}
		
		protected function onDelayTimer(evt:TimerEvent):void{
			nextStep();
		}
		
		protected function nextStep():void{
			//controller.close(currentTray);
			//reset refeed
			refeed=false;
			
			if(!isRunning || isPaused) return;
			if(hasPauseRequest){
				hasPauseRequest=false;
				pause('Пауза',false);
				return;
			}
			var steps:int=0;
			switch(currentGroup){
				case COMMAND_GROUP_START:
					if (vacuumOnStartOn) steps++;
					if (engineOnStartOn) steps++;
					if(currentGroupStep>=steps){
						//complite
						currentGroup= COMMAND_GROUP_BOOK_SHEET;
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
							currentGroupStep++;
							nextStep();
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
							runDelayTimer();
							if(glueHandler) glueHandler.resume();
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
							currentGroupStep++;
							nextStep();
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
				case COMMAND_GROUP_BOOK_SHEET:
					//check completed
					if(currentGroupStep>=1){
						if (register && register.isComplete){
							//order complited
							if(logger) logger.clear();
							detectFirstBook=false;
							register.finalise();
							register=null;
							currBookTot=-1;
							currBookIdx=-1;
							currSheetTot=-1;
							currSheetIdx=-1;
							log('Заказ '+currPgId+' завершен.');
							currPgId='';
							if(stopOnComplite){
								stop();
								return;
							}
							if(pauseOnComplite){
								currentGroupStep=0;
								pause('Пауза между заказами',false);
								return;
							}
						}
						
						//cycle feeding
						currentGroupStep=0;
						//nextStep();
						startFeedDelay();
						return;
					}
					feedSheet();
					break;
				default:
					log('Не определена последовательность');
					break;
			}
		}

		protected var refeed:Boolean=false;
		protected function feedSheet():void{
			refeed=true;
			currentLayer=Layer.LAYER_SHEET;
			//set latches
			layerInLatch.layer=currentLayer;
			layerInLatch.setOn();
			//if(barcodeReaders && barcodeReaders.length>0 && barcodeReaders[0] is ComReaderEmulator) (barcodeReaders[0] as ComReaderEmulator).emulateNext(); 
			barLatch.setOn();
			aclLatch.setOn();
			log('Старт подачи листа')
			controller.feed();
		}

		protected function onLatchTimeout(event:ErrorEvent):void{
			if(!isRunning || isPaused) return;
			var l:PickerLatch=event.target as PickerLatch;
			if(!l) return; 
			switch(l.type){
				case PickerLatch.TYPE_ACL:
					refeed=false;
					if(isServiceGroup(currentGroup)){
						//skip
						//log('ACL Timeout - skipped (service group)');
						l.reset();
						checkLatches();
						break;
					}
					//no break to call pause
				case PickerLatch.TYPE_BD:
				case PickerLatch.TYPE_REGISTER:
					pause('Таймаут ожидания. '+l.label+':'+l.caption);
					break;
				case PickerLatch.TYPE_BARCODE:
					if(layerInLatch.isOn){
						//sheet is not in, can be refeed, reset
						//will never run if timeout > then layerInLatch timeout
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
					//try refeed
					if(refeed){
						log('Повторная подача листа.');
						refeed=false;
						layerInLatch.setOn(); //restart in latch
						if(currentGroup==COMMAND_GROUP_BOOK_SHEET && barLatch.isOn) barLatch.setOn(); //reset bar latch
						aclLatch.setOn();
						controller.feed();
						return;
					}
					//empty tay or some else 
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
					pause('Заполните лотк подачи');
					return;
					break;
				case PickerLatch.TYPE_LAYER_OUT:
					//layer not out
					pause('Застрял лист');
					break;
			}
		}
		
		protected function onLatchRelease(event:Event):void{
			if(!isRunning || isPaused) return;
			checkLatches();
		}

		protected function resetLatches():void{
			var l:PickerLatch;
			for each(l in latches){
				l.reset();
			}
		}

		protected function checkLatches():void{
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
		
		protected function onControllerErr(event:ErrorEvent):void{
			pause('Ошибка контролера: '+event.text);
		}
		protected function onControllerCommandComplite(event:Event):void{
			aclLatch.forward();
		}
		protected function onControllerMsg(event:ControllerMesageEvent):void{
			if(!isRunning || isPaused) return;
			if(event.state==FeederController.CHANEL_STATE_FEEDER_EMPTY){
				var msg:String='Лоток подачи: '+FeederController.chanelStateName(FeederController.CHANEL_STATE_FEEDER_EMPTY);
				log(msg);
				/*
				var ap:AlertrPopup= new AlertrPopup();
				ap.show(msg,3,16);
				*/
				return;
			}
			//reset refeed
			refeed=false;
			if(layerInLatch.isOn && (event.state==FeederController.CHANEL_STATE_SINGLE_SHEET || event.state==FeederController.CHANEL_STATE_DOUBLE_SHEET)){
				//layerIn msg					
				var waiteState:int=FeederController.CHANEL_STATE_SINGLE_SHEET;
				//var wrongState:int=FeederController.CHANEL_STATE_DOUBLE_SHEET;
				if(currentLayer==Layer.LAYER_SHEET){
					waiteState=FeederController.CHANEL_STATE_DOUBLE_SHEET;
					//wrongState=FeederController.CHANEL_STATE_SINGLE_SHEET;
				}
				
				if((event.state==waiteState) || (doubleSheetOff && currentLayer==Layer.LAYER_SHEET && event.state==FeederController.CHANEL_STATE_SINGLE_SHEET)){
					//start OutLatch
					layerOutLatch.setOn();
					//layer in
					//currentTray=-1;
					layerInLatch.forward();
				}else{ //if(event.state==wrongState){
					//wrong state
					pause('Лоток подачи: '+FeederController.chanelStateName(event.state));
				}
			}else if(layerOutLatch.isOn && event.state==FeederController.CHANEL_STATE_SHEET_PASS){
				//sheet out
				currBarcode=null;//close if added scaner over conveyer
				layerOutLatch.forward();
				//if(currentGroup!=COMMAND_GROUP_BOOK_SHEET) currBarcode=null; //barcode covered vs some layer
				/*
				if(feedDelay<100){
					layerOutLatch.forward();
				}else{
					startFeedDelay();
				}
				*/
			}else{
				//unexpected msg
				pause('Лоток подачи. Не ожидаемое срабатывание: '+FeederController.chanelStateName(event.state));
			}
		}
		
		private var feedTimer:Timer;
		
		protected function startFeedDelay():void{
			if(feedDelay<100){
				//layerOutLatch.forward();
				nextStep();
				return;
			}
			
			if(!feedTimer){
				feedTimer= new Timer(feedDelay,1);
				feedTimer.addEventListener(TimerEvent.TIMER, onFeedDelayTimer);
			}
			feedTimer.start();
			log('Задержка подачи листа');
		}
		private function onFeedDelayTimer(evt:TimerEvent):void{
			//layerOutLatch.forward();
			nextStep();
		}

		override protected function onBarCode(event:BarCodeEvent):void{
			var barcode:String=event.barcode;
			log('barcod: '+barcode);
			if(!isRunning || isPaused) return;
			if(!barLatch.isOn){
				//chek doublescan while barcode not covered vs next layer
				if(barcode!=currBarcode) pause('Не ожидаемое срабатывание сканера ШК, код:' +barcode);
				return;
			}
			barLatch.forward();
			if(barcode==currBarcode) return; //doublescan or more then 1 barreader
			currBarcode=barcode;
			//parce barcode
			var pgId:String;
			var bookNum:int;
			var bookTotal:int;
			var pageNum:int;
			var pageTotal:int;
			
			if(!altBarcode){
				//cycle barcode
				//if(barcode.length>10) pgId=PrintGroup.idFromDigitId(barcode.substr(10));
				if(PrintGroup.isTechBarcode(barcode)) pgId=PrintGroup.idFromDigitId(barcode.substr(10));
				if(!pgId){
					pause('Не верный штрих код: '+barcode);
					return;
				}
				bookNum=int(barcode.substr(0,3));
				bookTotal=int(barcode.substr(3,3))
				pageNum=int(barcode.substr(6,2));
				pageTotal=int(barcode.substr(8,2));
			}else{
				//external barcode
				//1 book always
				/*format [xxxxxx][nnn][ttt] 
					nnn - 3digit current sheet
					ttt - 3digit total sheets
					xxxxxx - some digits vs order id 
				*/
				bookTotal=1;
				bookNum=1;
				pageTotal=int(barcode.substr(barcode.length-3,3));
				pageNum=int(barcode.substr(barcode.length-6,3));
				pgId=barcode.substr(0,barcode.length-6);
			}
			
			glueHandler.await(pgId,bookNum,pageNum,pageTotal);
			//if(currSheetIdx==-1){
			if(!register){
				//new order
				currPgId=pgId;
				currReprints=[];
				currBookTot=bookTotal;
				currSheetTot=pageTotal;
				/*
				//template check
				bdWait=0;
				bdAttempt=0;
				*/
				checkOrderParams();
				//new register
				register= new TechRegisterPicker(pgId,currBookTot,currSheetTot);
				register.techPoint=techPoint;
				register.revers=reversOrder;
				register.inexactBookSequence=inexactBookSequence;
				register.detectFirstBook=detectFirstBook;
				register.noDataBase=dataBaseOff;
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
						glueHandler.pauseOnBook(pgId,bookNum);
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

		override protected function onRegisterErr(event:ErrorEvent):void{
			if(event.errorID>0){
				if(glueHandler) glueHandler.pauseOnBook();
				pause(event.text);
			}else{
				log(event.text);
			}
		}
		override protected function onRegisterComplite(event:Event):void{
			currBookIdx=register.currentBook;
			currSheetIdx=register.currentSheet;
			registerLatch.forward();
		}
		
		override protected function checkOrderParams():void{
			if(!currPgId) return;
			if(dataBaseOff) return;
			bdLatch.setOn();
			var svc:OrderService=Tide.getInstance().getContext().byType(OrderService,true) as OrderService;
			var latch:DbLatch= new DbLatch();
			//load reprints
			latch.addEventListener(Event.COMPLETE,onReprintsLoad);
			latch.addLatch(svc.loadReprintsByPG(currPgId));
			latch.start();
		}
		override protected function onReprintsLoad(e:Event):void{
			currReprints=[];
			var bookType:int
			var latch:DbLatch=e.target as DbLatch;
			if(latch){
				latch.removeEventListener(Event.COMPLETE,onReprintsLoad);
				if(latch.complite){
					var list:Array=latch.lastDataArr;
					if(list){
						for each (var pg:PrintGroup in list){
							if(pg){
								currReprints.push(pg.id);
								bookType=pg.book_type;
							}
						}
					}
				}
			}
			currBookTypeName=getBookTypeName(bookType);
			bdLatch.forward();
		}

	}
}