package com.photodispatcher.service.barcode{
	import com.photodispatcher.event.BarCodeEvent;
	import com.photodispatcher.event.SerialProxyEvent;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.TimerEvent;
	import flash.utils.Timer;
	import flash.utils.getTimer;
	
	[Event(name="barcodeReaded", type="com.photodispatcher.event.BarCodeEvent")]
	[Event(name="barcodeError", type="com.photodispatcher.event.BarCodeEvent")]
	public class ComReader extends EventDispatcher{
		public static const TIMEUOT:int=500;
		public static const DOUBLE_SCAN_GAP:int=200;

		[Bindable]
		public var isStarted:Boolean=false;
		public var prefix:uint=0; //unused
		public var sufix:uint=13; //LF default

		protected var buffer:String='';
		protected var timer:Timer;
		
		protected var doubleScanGap:int;
		protected var lastBarcode:String;
		protected var lastBarcodeTime:int=getTimer();
		protected var cleanMsg:Boolean=true;

		//private var comPort:SerialProxy;
		protected var _comPort:Socket2Com;
		public function set comPort(value:Socket2Com):void{
			if(_comPort){
				_comPort.removeEventListener(Event.CLOSE, onComClose);
				_comPort.removeEventListener(Event.CONNECT, onComConnect);
				_comPort.removeEventListener(SerialProxyEvent.SERIAL_PROXY_ERROR, onComErr);
				_comPort.removeEventListener(SerialProxyEvent.SERIAL_PROXY_DATA, onComData);
				_comPort.close();
			}
			_comPort = value;
			if(_comPort){
				sufix=_comPort.sufix;
				doubleScanGap=_comPort.doubleScanGap;
				_comPort.addEventListener(Event.CLOSE, onComClose);
				_comPort.addEventListener(Event.CONNECT, onComConnect);
				_comPort.addEventListener(SerialProxyEvent.SERIAL_PROXY_ERROR, onComErr);
				_comPort.addEventListener(SerialProxyEvent.SERIAL_PROXY_DATA, onComData);
			}
		}

		public function ComReader(doubleScanGap:int=DOUBLE_SCAN_GAP){
			super(null);
			this.doubleScanGap=doubleScanGap;
		}

		public function get connected():Boolean{
			return _comPort &&  _comPort.connected;
		}

		public function start(comPort:Socket2Com=null):void{
			isStarted=false;
			buffer='';
			if(comPort){
				this.comPort=comPort;
			}
			if(!_comPort) return;
			if(!_comPort.connected){
				_comPort.connect();
			}else{
				isStarted=true;
			}
		}
		
		public function stop():void{
			stopTimer();
			timer=null;
			destroyCom();
			isStarted=false;
		}
		
		protected function onComConnect(event:Event):void{
			isStarted=true;
			_comPort.clean();
		}

		protected function onComClose(event:Event):void{
			stopTimer();
			destroyCom();
		}

		protected function onComErr(event:SerialProxyEvent):void{
			stopTimer();
			destroyCom();
			dispatchEvent(new BarCodeEvent(BarCodeEvent.BARCODE_ERR, buffer, event.error));
		}

		protected function destroyCom():void{
			if(_comPort){
				_comPort.removeEventListener(Event.CLOSE, onComClose);
				_comPort.removeEventListener(Event.CONNECT, onComConnect);
				_comPort.removeEventListener(SerialProxyEvent.SERIAL_PROXY_ERROR, onComErr);
				_comPort.removeEventListener(SerialProxyEvent.SERIAL_PROXY_DATA, onComData);
				_comPort.close();
				_comPort=null;
			}
			isStarted=false;
		}

		protected function onComData(event:SerialProxyEvent):void{
			//TODO implement prefix
			var barcode:String;
			stopTimer();
			buffer+=event.data;
			var idx:int;
			do{
				//look for sufix
				idx=buffer.indexOf(String.fromCharCode(sufix));
				if(idx>-1){
					barcode=buffer.substring(0,idx);
					if(cleanMsg){
						//clean
						barcode = barcode.replace(String.fromCharCode(13),'');
						barcode = barcode.replace(String.fromCharCode(10),'');
						barcode = barcode.replace(String.fromCharCode(02),'');
					}
					buffer=buffer.substr(idx+1);
					var skip:Boolean=false;
					if(doubleScanGap>0){
						var now:int=getTimer();
						skip=lastBarcode && now-lastBarcodeTime<doubleScanGap && lastBarcode==barcode;
						lastBarcode=barcode;
						lastBarcodeTime=now;	
						//if (skip) return;
					}
					if (!skip)dispatchEvent(new BarCodeEvent(BarCodeEvent.BARCODE_READED,barcode));
				}
			} while(idx>-1);
			if(buffer==null) buffer='';
			if(buffer) startTimer();
		}

		protected function startTimer():void{
			if(!timer){
				timer=new Timer(TIMEUOT,1);
				timer.addEventListener(TimerEvent.TIMER, onTimer);
			}else{
				timer.reset();
			}
			timer.start();
		}
		protected function stopTimer():void{
			if(timer) timer.reset();
		}
		
		protected function onTimer(event:TimerEvent):void{
			if (buffer){
				var e:BarCodeEvent=new BarCodeEvent(BarCodeEvent.BARCODE_ERR, buffer, 'Timeout error');
				//state=STATE_WAIT;
				//barcode='';
				buffer='';
				dispatchEvent(e);
			}
		}

	}
}