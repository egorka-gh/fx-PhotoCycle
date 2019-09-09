package com.photodispatcher.tech{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.event.BarCodeEvent;
	import com.photodispatcher.event.ControllerMesageEvent;
	import com.photodispatcher.event.SerialProxyEvent;
	import com.photodispatcher.event.WebEvent;
	import com.photodispatcher.interfaces.ISimpleLogger;
	import com.photodispatcher.model.mysql.DbLatch;
	import com.photodispatcher.model.mysql.entities.FieldValue;
	import com.photodispatcher.model.mysql.entities.PrintGroup;
	import com.photodispatcher.model.mysql.entities.TechPoint;
	import com.photodispatcher.model.mysql.services.OrderService;
	import com.photodispatcher.service.barcode.ComInfo;
	import com.photodispatcher.service.barcode.ComReader;
	import com.photodispatcher.service.barcode.ComReaderEmulator;
	import com.photodispatcher.service.barcode.FeederController;
	import com.photodispatcher.service.barcode.SerialProxy;
	import com.photodispatcher.service.barcode.Socket2Com;
	import com.photodispatcher.service.modbus.controller.GlueMBController;
	import com.photodispatcher.service.web.LocalWeb;
	import com.photodispatcher.service.web.LocalWebAction;
	import com.photodispatcher.service.web.Responses;
	import com.photodispatcher.tech.plain_register.TechRegisterPicker;
	import com.photodispatcher.util.ArrayUtil;
	
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.net.SharedObject;
	
	import mx.collections.ArrayCollection;
	import mx.controls.Alert;
	
	import org.granite.tide.Tide;
	
	import spark.formatters.DateTimeFormatter;

	[Event(name="error", type="flash.events.ErrorEvent")]
	public class GlueStreamed extends EventDispatcher{
		
		public function GlueStreamed(){
			super(null);
			feedDelay=100;
		}

		public var glueType:int;
		public var hasFeeder:Boolean=false;

		[Bindable]
		public var prepared:Boolean;

		private var _feederReamState:int=FeederController.REAM_STATE_UNKNOWN;
		[Bindable]
		public function get feederReamState():int{
			return _feederReamState;
		}
		public function set feederReamState(value:int):void{
			_feederReamState=value;
		}
		
		public function get feederEmpty():Boolean{
			return false;
		}

		
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
		
		[Bindable]
		public var currBookTypeName:String=''; 
		
		public var dataBaseOff:Boolean;
		public var altBarcode:Boolean;
		
		public var engineOnStartOn:Boolean=false;
		public var vacuumOnStartOn:Boolean=false;
		public var engineOnErrOff:Boolean=false;
		public var vacuumOnErrOff:Boolean=false;
		
		public var stopOnComplite:Boolean=false;
		public var pauseOnComplite:Boolean=false;
		
		public var pushDelay:int=200;
		
		protected var useServer:Boolean=false;
		protected var serverUrl:String;

		
		private var _serialProxy:SerialProxy;
		public function get serialProxy():SerialProxy{
			return _serialProxy;
		}
		public function set serialProxy(value:SerialProxy):void{
			if(_serialProxy){
				//_serialProxy.removeEventListener(SerialProxyEvent.SERIAL_PROXY_START,onSerialProxyStart);
				_serialProxy.removeEventListener(SerialProxyEvent.SERIAL_PROXY_ERROR, onProxyErr);
				//_serialProxy.removeEventListener(SerialProxyEvent.SERIAL_PROXY_CONNECTED, onProxyConnect0);
			}
			_serialProxy = value;
			if(_serialProxy){
				//_serialProxy.addEventListener(SerialProxyEvent.SERIAL_PROXY_START,onSerialProxyStart);
				_serialProxy.addEventListener(SerialProxyEvent.SERIAL_PROXY_ERROR, onProxyErr);
				//_serialProxy.addEventListener(SerialProxyEvent.SERIAL_PROXY_CONNECTED, onProxyConnect0,false,10);
				//if(_serialProxy.isStarted) _serialProxy.connectAll();
			}
		}
		/*
		protected function onSerialProxyStart(evt:SerialProxyEvent):void{
			log('SerialProxy: started, connect to com proxies...');
			serialProxy.connectAll();
		}
		
		protected function onProxyConnect0(evt:SerialProxyEvent):void{
			log('SerialProxy: connected, start devices');
			startDevices();
		}
		*/
		
		protected function onProxyErr(evt:SerialProxyEvent):void{
			isRunning=false;
			logErr('SerialProxy error: '+evt.error);
		}
		
		public var techPoint:TechPoint;
		public var reversOrder:Boolean;
		public  var doubleSheetOff:Boolean=false;
		
		[Bindable]
		public var isRunning:Boolean;
		[Bindable]
		public var isPaused:Boolean;
		
		//Latches
		[Bindable]
		public var latches:Array;
		
		[Bindable]
		public var statString:String='';
		[Bindable]
		public var statStringD:String='';

		//print group params
		[Bindable]
		public var currPgId:String='';
		protected var currBarcode:String;
		protected var currReprints:Array;

		[Bindable]
		public var currBookTot:int;
		[Bindable]
		public var currBookIdx:int;
		[Bindable]
		public var currSheetTot:int;
		[Bindable]
		public var currSheetIdx:int;
		
		
		protected var _logger:ISimpleLogger;
		public function get logger():ISimpleLogger{
			return _logger;
		}
		public function set logger(value:ISimpleLogger):void{
			_logger = value;
		}
		
		private var _feedDelay:int;
		public function get feedDelay():int{
			return _feedDelay;
		}
		
		public function set feedDelay(value:int):void{
			if(value<100) value=100;
			_feedDelay = value;
		}
		
		public function init():void{
			useServer = Context.getAttribute("useServer");
			serverUrl = Context.getAttribute("serverUrl");
			useServer = useServer && serverUrl;
			if(lServer) lServer.removeEventListener(WebEvent.RESPONSE, onlServerResp);
			if (useServer){
				lServer = new LocalWeb(serverUrl);
				lServer.addEventListener(WebEvent.RESPONSE, onlServerResp);
			}

			if(!glueHandler && glueType!=0) createGlueHandler();
			//checkPrepared();
		}
		
		protected var lServer:LocalWeb;
		protected function serverOrderComplite(pgId:String):void{
			if (!useServer || !lServer) return;
			log('Send OrderComplite '+pgId, 101);
			lServer.sendOrderComplite(pgId);
		}
		
		protected function onlServerResp(event:WebEvent):void{
			var action:LocalWebAction = event.data as LocalWebAction;
			var str:String='';
			if (action){
				str = 'HttpStatus: ' + action.httpStatus+'; ';
				str = str +'data:'+action.data+'; ';  
			}
			if(event.response==Responses.SERVICE_ERROR){
				str = str +'error:'+event.error;
			}else{
				//Responses.COMPLETE
				if (action){
					str = str +'response: '+action.responce;
				}else{
					str = str +'OK';
				}
			}
			log('Response: '+str, 101);
		}
		
		protected function checkPrepared(showAlert:Boolean=false):Boolean{
			prepared=barcodeReaders && barcodeReaders.length>0 && 
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
			if(!prepared && showAlert){
				var msg:String='';
				if(!barcodeReaders || barcodeReaders.length==0) msg='Не инициализированы сканеры ШК';
				if(!barsConnected) msg= (msg?'\n':'')+'Не подключены сканеры ШК';
				if(!glueHandler || !glueHandler.isPrepared) msg=(msg?'\n':'')+'Не инициализирована склейка';
				log(msg);
				Alert.show(msg);
			}
			return 	prepared;
		}
		
		public function destroy():void{
			logger=null;
			var barReader:ComReader;
			if (barcodeReaders){
				for each(barReader in barcodeReaders) barReader.stop();
			}
			barcodeReaders=null;
			register=null;
			if(glueHandler) glueHandler.destroy();
			glueHandler=null;

		}
		
		protected var _barcodeReaders:Array;
		protected function get barcodeReaders():Array{
			return _barcodeReaders;
		}
		protected function set barcodeReaders(value:Array):void{
			//log('Set barcode readers');
			var barReader:ComReader;
			if(_barcodeReaders){
				for each(barReader in _barcodeReaders){
					barReader.removeEventListener(BarCodeEvent.BARCODE_READED,onBarCode);
					barReader.removeEventListener(BarCodeEvent.BARCODE_ERR, onBarError);
					barReader.removeEventListener(BarCodeEvent.BARCODE_DISCONNECTED, onBarDisconnect);
					barReader.removeEventListener(BarCodeEvent.BARCODE_DEBUG, onBarDebug);
					//barReader.stop();
				}
			}
			var deb:Boolean=Context.getAttribute('debugBarReders');
			_barcodeReaders = value;
			if(_barcodeReaders){
				for each(barReader in _barcodeReaders){
					barReader.addEventListener(BarCodeEvent.BARCODE_READED,onBarCode);
					barReader.addEventListener(BarCodeEvent.BARCODE_ERR, onBarError);
					barReader.addEventListener(BarCodeEvent.BARCODE_DISCONNECTED, onBarDisconnect);
					if(deb){
						barReader.debugMode=true;
						barReader.addEventListener(BarCodeEvent.BARCODE_DEBUG, onBarDebug);
					}
				}
			}
			/*
			//checkPrepared();
			var msg:String;
			if(!_barcodeReaders || _barcodeReaders.length==0){
				msg='has no barcode readers';
			}else{
				msg='has '+_barcodeReaders.length.toString()+' barcode readers';
			}
			log(msg);
			*/
		}
		
		
		private var _glueHandler:GlueHandler;
		[Bindable]
		public function get glueHandler():GlueHandler{
			return _glueHandler;
		}
		public function set glueHandler(value:GlueHandler):void{
			if(_glueHandler){
				_glueHandler.removeEventListener(ErrorEvent.ERROR,onGlueHandlerErr);
				_glueHandler.removeEventListener(ControllerMesageEvent.CONTROLLER_MESAGE_EVENT,onControllerMsg);
			}
			_glueHandler = value;
			if(_glueHandler){
				_glueHandler.logger=logger;
				_glueHandler.addEventListener(ErrorEvent.ERROR,onGlueHandlerErr);
				_glueHandler.addEventListener(ControllerMesageEvent.CONTROLLER_MESAGE_EVENT,onControllerMsg);
			}
		}
		protected function onGlueHandlerErr(event:ErrorEvent):void{
			if(!isRunning ){
				log('Cклейка: '+event.text);
				return;
			}
			if(glueHandler.isRunning){
				logErr('Cклейка: '+event.text);
				//??
				if(!glueHandler.errorMode){
					stop();
				}
			}else{
				//hz
				log('Cклейка: '+event.text);
			}
		}
		
		protected function onControllerMsg(event:ControllerMesageEvent):void{
			//posible bug - GlueMBController && FeederController chanel_state colision
			//now no problem -> GlueMBController.GLUE_LEVEL_ALARM > FeederController.CHANEL_STATE_REAM_FILLED
			if(event.state==GlueMBController.GLUE_LEVEL_ALARM){
				//show alert
				log('Низкий уровень клея');
				if(Context.getAttribute("glueAlarm")){
					dispatchEvent(new ErrorEvent(ErrorEvent.ERROR,false,false,"Закончился клей",10));
					/*
					if(Context.getAttribute("glueShowAlarm") && !Context.getAttribute("showAlarm")){
						(glueHandler as GlueHandlerMB).controller.setAlarmOn();
					}
					*/
				}
				return;
			}
		}
		
		
		protected var _register:TechRegisterPicker;
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
		
		public function setEngineOn():void{
		}
		public function setEngineOff():void{
		}
		public function setVacuumOn():void{
		}
		public function setVacuumOff():void{
		}
		
		public function start():void{
			isRunning=false;
			if(logger) logger.clear();
			if(!serialProxy) return;
			log('Старт');
			if(!serialProxy.isStarted){
				logErr('SerialProxy not started...');
				return;
			}
			isRunning=true;
			
			if(!serialProxy.connected){
				//connect
				log('Ожидание подключения COM портов');
				serialProxy.addEventListener(SerialProxyEvent.SERIAL_PROXY_CONNECTED, onProxyConnect);
				serialProxy.connectAll();
				return;
			}
			
			onProxyConnect(null);
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
		}
		protected function onProxyConnect(evt:SerialProxyEvent):void{
			serialProxy.removeEventListener(SerialProxyEvent.SERIAL_PROXY_CONNECTED, onProxyConnect);
			log('SerialProxy: connect complite');
			if(!serialProxy.connected){
				log('Часть COM портов не подключено');
				log('SerialProxy:' +serialProxy.traceDisconnected());
			}
			
			//startDevices()
			startInternal();
		}

		protected function createGlueHandler():void{
			if(glueType==0){
				glueHandler=new GlueHandler();
				glueHandler.init(serialProxy);
				glueHandler.pushDelay=pushDelay;
			}else{
				var gh:GlueHandlerMB=new GlueHandlerMB();
				if(Context.getAttribute('glueServerIP')) gh.serverIP=Context.getAttribute('glueServerIP');
				if(Context.getAttribute('glueServerPort')) gh.serverPort=Context.getAttribute('glueServerPort');
				if(Context.getAttribute('glueClientIP')) gh.clientIP=Context.getAttribute('glueClientIP');
				if(Context.getAttribute('glueClientPort')) gh.clientPort=Context.getAttribute('glueClientPort');
				if(Context.getAttribute('glueSideStopOffDelay')) gh.glueSideStopOffDelay=Context.getAttribute('glueSideStopOffDelay');
				if(Context.getAttribute('glueSideStopOnDelay')) gh.glueSideStopOnDelay=Context.getAttribute('glueSideStopOnDelay');
				if(Context.getAttribute('pumpEnable')) gh.pumpEnable=Context.getAttribute('pumpEnable');
				if(Context.getAttribute('pumpSensFilterTime')) gh.pumpSensFilterTime=Context.getAttribute('pumpSensFilterTime');
				if(Context.getAttribute('pumpWorkTime')) gh.pumpWorkTime=Context.getAttribute('pumpWorkTime');
				if(Context.getAttribute('glueHasFeeder')) gh.hasFeeder=Context.getAttribute('glueHasFeeder');
				
				if(Context.getAttribute('whitePaperDelay')) gh.whitePaperDelay=Context.getAttribute('whitePaperDelay');
				if(Context.getAttribute('bookEjectionDelay')) gh.bookEjectionDelay=Context.getAttribute('bookEjectionDelay');
				if(Context.getAttribute('finalSqueezingTime')) gh.finalSqueezingTime=Context.getAttribute('finalSqueezingTime');

				if(Context.getAttribute('glueUnloadOffDelay')) gh.glueUnloadOffDelay=Context.getAttribute('glueUnloadOffDelay');
				if(Context.getAttribute('glueUnloadOnDelay')) gh.glueUnloadOnDelay=Context.getAttribute('glueUnloadOnDelay');
				if(Context.getAttribute('gluePlateReturnDelay')) gh.gluePlateReturnDelay=Context.getAttribute('gluePlateReturnDelay');
				if(Context.getAttribute('glueScraperDelay')) gh.glueScraperDelay=Context.getAttribute('glueScraperDelay');
				if(Context.getAttribute('glueScraperRun')) gh.glueScraperRun=Context.getAttribute('glueScraperRun');
				if(Context.getAttribute('glueFirstSheetDelay')) gh.glueFirstSheetDelay=Context.getAttribute('glueFirstSheetDelay');
				
				gh.allowSkipMode=Context.getAttribute('allowSkipMode');
				if(Context.getAttribute('glueSkipSheetDelay')) gh.glueFirstSheetDelay=Context.getAttribute('glueSkipSheetDelay');

				
				gh.allowErrorMode = Context.getAttribute('glueAllowErrorMode');

				gh.init(null);
				glueHandler=gh;
			}
		}
		
		public var barcodeEmulator:ComReaderEmulator;
		protected function startDevices():void{
			//start glueHandler
			//createGlueHandler();
			if(!glueHandler || (glueType==0 && !isPaused)) createGlueHandler();
			glueHandler.nonStopMode=true;
			//glueHandler.start();
			
			/*
			//emulate barreader
			barcodeEmulator= new ComReaderEmulator();
			barcodeEmulator.books=5;
			barcodeEmulator.sheets=7;
			barcodeEmulator.pgId='99999';
			barcodeEmulator.start();
			barcodeReaders=[barcodeEmulator];
			return;
			*/
			
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

		protected function startInternal():void{
			startDevices();
			if(!checkPrepared(true)){
				isRunning=false;
				log('Ошибка запуска');
				return;
			}
			
			if(!glueHandler || !glueHandler.start()){
				log('startInternal: glueHandler init error');
				return;
			}
			if(!glueHandler.isConnected){
				log('startInternal: Не подключен контролер склейки');
				return;
			}
			
			log('SerialProxy:' +serialProxy.traceDisconnected());
			log('start internal complete');
			currBarcode=null;
			currPgId='';
			currBookTot=-1;
			currBookIdx=-1;
			currSheetTot=-1;
			currSheetIdx=-1;
			isRunning=true;
		}
		
		public function stop():void{
			if(!isRunning) return;
			register=null;
			inexactBookSequence=false;
			detectFirstBook=false;
			isRunning=false;
			if(glueHandler){
				glueHandler.stop();
				glueHandler.isRunning=false;
			}
			//glueHandler??
		}
		
		public function pauseRequest(msg:String=''):void{
			
		}
		
		protected function onBarDebug(event:BarCodeEvent):void{
			
		}
		
		protected function onBarCode(event:BarCodeEvent):void{
			var barcode:String=event.barcode;
			log('barcod: '+barcode);
			if(!isRunning) return;
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
					logErr('Не верный штрих код: '+barcode);
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
			
			currBookIdx=bookNum;
			currSheetIdx=pageNum;

			if(register && !checkPrintgroup(pgId)){
				/*
				register.finalise();
				if(register.inexactBookSequence){
					//defect complited
					inexactBookSequence=false;
					log('Сборка брака завершена: "'+currPgId);
				}
				*/
				
				if(register.finalise()){
					log('Заказ '+currPgId+' завершен.');
					serverOrderComplite(currPgId);
				}
				register=null;
			}
			
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
				register= new TechRegisterPicker(pgId,currBookTot,currSheetTot, dataBaseOff);
				register.techPoint=techPoint;
				register.revers=reversOrder;
				register.inexactBookSequence=inexactBookSequence;
				register.detectFirstBook=detectFirstBook;
				//register.noDataBase=dataBaseOff;
				//reset detectFirstBook
				//if(detectFirstBook) detectFirstBook=false;
			}
			
			statCountSheet();
			//check sequence
			register.register(bookNum,pageNum);
			/*
			//4 fast glue in error mode
			if (register.isNextEndSheet){
				glueHandler.penultSheet =true;
			}
			*/
			if (register.currentBookComplited){
				statCountBook();
				glueHandler.awaitLast(pgId,bookNum,pageNum,pageTotal);
			}else{
				glueHandler.await(pgId,bookNum,pageNum,pageTotal);				
			}

			if (register.isComplete){
				register.flushData();
				log('Заказ "'+register.printGroupId+'" завершен (register)');
				serverOrderComplite(register.printGroupId);
				register=null;
			}
		}
		protected function onBarError(event:BarCodeEvent):void{
			log('Ошибка сканера ШК: '+event.error);
		}
		protected function onBarDisconnect(event:BarCodeEvent):void{
			log('Отключен сканер ШК '+event.barcode);
			//pause('Отключен сканер ШК '+event.barcode); busy bug
		}
		
		protected function checkPrintgroup(pgId:String):Boolean{
			var res:Boolean=pgId==currPgId;
			if(!res && currReprints){
				res=currReprints.indexOf(pgId)!=-1;
			}
			return res;
		}
		
		protected function onRegisterErr(event:ErrorEvent):void{
			if(event.errorID>0){
				logErr(event.text);
				if(glueHandler) glueHandler.errorMode = true;
			}else{
				log(event.text);
			}
		}
		
		protected function onRegisterComplite(event:Event):void{
		}

		protected function log(msg:String, level:int=0):void{
			if(logger) logger.log(msg, level);
		}
		protected function logErr(msg:String):void{
			dispatchEvent(new ErrorEvent(ErrorEvent.ERROR,false,false,msg));
		}
		
		protected function checkOrderParams():void{
			if(!currPgId) return;
			if(dataBaseOff) return;
			var svc:OrderService=Tide.getInstance().getContext().byType(OrderService,true) as OrderService;
			var latch:DbLatch= new DbLatch();
			//load reprints
			latch.addEventListener(Event.COMPLETE,onReprintsLoad);
			latch.addLatch(svc.loadReprintsByPG(currPgId));
			latch.start();
		}
		protected function onReprintsLoad(e:Event):void{
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
		}
		
		protected function getBookTypeName(bookType:int):String{
			var result:String;
			if(!bookType) return '';
			var ac:ArrayCollection=Context.getAttribute('book_typeList') as ArrayCollection;
			if(ac){
				var fv:FieldValue=ArrayUtil.searchItem('value',bookType,ac.source) as FieldValue;
				if(fv) result=fv.label;
			}
			if(!result) result='id:'+bookType;
			return result;
		}
		
		protected var statDate:Date;
		protected var statBooks:int=0;
		protected var statSheets:int=0;
		
		protected var statDateD:Date;
		protected var statBooksD:int=0;
		protected var statSheetsD:int=0;
		
		protected var statSheetCounter:int=0;
		
		public function showStat():void{
			var dt:Date= Context.getAttribute('statDate');
			var bk:int= Context.getAttribute('statBooks');
			var sht:int= Context.getAttribute('statSheets');

			//curr date
			var dtd:Date= Context.getAttribute('statDateD');
			var bkd:int= Context.getAttribute('statBooksD');
			var shtd:int= Context.getAttribute('statSheetsD');
			//check curr date
			var now:Date =  new Date();
			statDateD = new Date(now.fullYear, now.month, now.date);
			if(!dtd || dtd.time != statDateD.time){
				Context.setAttribute("statDateD", statDateD);
				statBooksD=0;
				statSheetsD=0;
			}

			var str:String=' Произведено';
			var fmt:DateTimeFormatter= new DateTimeFormatter();
			fmt.dateTimePattern='dd.MM.yy HH:mm';
			if(dt){
				str=str +' c ' +fmt.format(dt);
			}
			str=str+' Книг:'+bk.toString()+' листов:'+(sht+statSheetCounter).toString();
			statString=str;

			statStringD='Произведено '+fmt.format(statDateD)+' Книг:'+bkd.toString()+' листов:'+(shtd+statSheetCounter).toString();
		}
		
		protected function statCountBook():void{
			var so:SharedObject = SharedObject.getLocal('appProps','/');
			statDate=so.data.statDate;
			statBooks=so.data.statBooks;
			statSheets=so.data.statSheets;
			if(statBooks<=0) statBooks=0;
			if(statSheets<=0) statSheets=0;
			
			if(statSheets>= (int.MAX_VALUE-statSheetCounter)){
				statSheets=0;
				statBooks=0;
			}
			if(statBooks==int.MAX_VALUE) statBooks=0;
			
			statDateD=so.data.statDateD;
			statBooksD=so.data.statBooksD;
			statSheetsD=so.data.statSheetsD;
			//check curr date
			var now:Date =  new Date();
			now = new Date(now.fullYear, now.month, now.date);
			if(!statDateD || statDateD.time != now.time){
				statBooksD=0;
				statSheetsD=0;
				statDateD= now;
			}
			
			statBooks++;
			statSheets=statSheets+statSheetCounter;
			statBooksD++;
			statSheetsD=statSheetsD+statSheetCounter;
			statSheetCounter=0;
			
			//save
			so.data.statBooks=statBooks;
			so.data.statSheets=statSheets;
			so.data.statBooksD=statBooksD;
			so.data.statSheetsD=statSheetsD;
			so.data.statDateD=statDateD;
			
			so.flush();
			
			Context.setAttribute("statBooks", statBooks);
			Context.setAttribute("statSheets", statSheets);

			Context.setAttribute("statBooksD", statBooksD);
			Context.setAttribute("statSheetsD", statSheetsD);
			Context.setAttribute("statDateD", statDateD);

			showStat();
		}
		
		protected function statCountSheet():void{
			statSheetCounter++;
			showStat();
		}

	}
}