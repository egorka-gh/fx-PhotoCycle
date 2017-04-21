package com.photodispatcher.tech{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.event.BarCodeEvent;
	import com.photodispatcher.event.SerialProxyEvent;
	import com.photodispatcher.interfaces.ISimpleLogger;
	import com.photodispatcher.model.mysql.DbLatch;
	import com.photodispatcher.model.mysql.entities.FieldValue;
	import com.photodispatcher.model.mysql.entities.PrintGroup;
	import com.photodispatcher.model.mysql.entities.TechPoint;
	import com.photodispatcher.model.mysql.services.OrderService;
	import com.photodispatcher.service.barcode.ComInfo;
	import com.photodispatcher.service.barcode.ComReader;
	import com.photodispatcher.service.barcode.SerialProxy;
	import com.photodispatcher.service.barcode.Socket2Com;
	import com.photodispatcher.tech.plain_register.TechRegisterPicker;
	import com.photodispatcher.util.ArrayUtil;
	
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	
	import mx.collections.ArrayCollection;
	import mx.controls.Alert;
	
	import org.granite.tide.Tide;

	[Event(name="error", type="flash.events.ErrorEvent")]
	public class GlueStreamed extends EventDispatcher{
		
		public function GlueStreamed(){
			super(null);
			feedDelay=100;
		}

		public var glueType:int;
		
		[Bindable]
		public var prepared:Boolean;
		
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
		
		public var engineOnStartOn:Boolean=false;
		public var vacuumOnStartOn:Boolean=false;
		public var engineOnErrOff:Boolean=false;
		public var vacuumOnErrOff:Boolean=false;
		
		public var stopOnComplite:Boolean=false;
		public var pauseOnComplite:Boolean=false;
		
		public var pushDelay:int=200;
		
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
			//checkPrepared();
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
			}
			_glueHandler = value;
			if(_glueHandler){
				_glueHandler.logger=logger;
				_glueHandler.addEventListener(ErrorEvent.ERROR,onGlueHandlerErr);
			}
		}
		protected function onGlueHandlerErr(event:ErrorEvent):void{
			if(!isRunning ){
				log('Cклейка: '+event.text);
				return;
			}
			if(glueHandler.isRunning && glueHandler.hasPauseRequest){
				logErr('Cклейка: '+event.text);
			}else{
				log('Cклейка: '+event.text);
				stop();
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
				
				gh.init(null);
				glueHandler=gh;
				
			}
		}
		
		protected function startDevices():void{
			//start glueHandler
			createGlueHandler();
			glueHandler.nonStopMode=true;
			glueHandler.start();
			
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
			
			if(!dataBaseOff){
				//cycle barcode
				if(barcode.length>10) pgId=PrintGroup.idFromDigitId(barcode.substr(10));
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
			
			glueHandler.await(pgId,bookNum,pageNum,pageTotal);
			currBookIdx=bookNum;
			currSheetIdx=pageNum;

			if(register && !checkPrintgroup(pgId)){
				register.finalise();
				if(register.inexactBookSequence){
					//defect complited
					inexactBookSequence=false;
					log('Сборка брака завершена: "'+currPgId);
				}
				/*
				else{
					logErr('Не верный заказ разворота, текущий: '+currPgId+', заказ разворота'+pgId);
					return;
				}
				*/
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
				register= new TechRegisterPicker(pgId,currBookTot,currSheetTot);
				register.techPoint=techPoint;
				register.revers=reversOrder;
				register.inexactBookSequence=inexactBookSequence;
				register.detectFirstBook=detectFirstBook;
				register.noDataBase=dataBaseOff;
				//reset detectFirstBook
				if(detectFirstBook) detectFirstBook=false;
			}
			//check sequence
			register.register(bookNum,pageNum);
			if (register.isComplete){
				register.flushData();
				log('Заказ "'+register.printGroupId+'" завершен');
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
			}else{
				log(event.text);
			}
		}
		
		protected function onRegisterComplite(event:Event):void{
		}

		protected function log(msg:String):void{
			if(logger) logger.log(msg);
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
	}
}