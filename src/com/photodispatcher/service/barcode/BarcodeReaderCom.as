package com.photodispatcher.service.barcode{
	import com.photodispatcher.event.BarCodeEvent;
	import com.photodispatcher.event.SerialProxyEvent;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.TimerEvent;
	import flash.utils.Timer;
	
	[Event(name="barcodeReaded", type="com.photodispatcher.event.BarCodeEvent")]
	[Event(name="barcodeError", type="com.photodispatcher.event.BarCodeEvent")]
	public class BarcodeReaderCom extends EventDispatcher{
		public static const TIMEUOT:int=500;

		//private static const STATE_WAIT:int=0;
		//private static const STATE_CAPTURE:int=1;

		[Bindable]
		public var isStarted:Boolean=false;
		public var prefix:uint=0; //unused
		public var sufix:uint=13; //LF default

		//private var barcode:String='';
		private var buffer:String='';
		//private var state:int=STATE_WAIT;
		private var timer:Timer;

		private var com_port:int;
		private var com_baud:int;
		//private var proxy_port:int;
		private var comPort:SerialProxy;

		public function BarcodeReaderCom(){
			super(null);
		}

		public function get connected():Boolean{
			return comPort &&  comPort.connected;
		}

		public function start(com_port:int=1, com_baud:int=2400):void{
			this.com_port=com_port;
			this.com_baud=com_baud;
			comPort= new SerialProxy();
			comPort.addEventListener(Event.CLOSE, onComClose);
			comPort.addEventListener(Event.CONNECT, onComConnect);
			comPort.addEventListener(SerialProxyEvent.SERIAL_PROXY_ERROR, onComErr);
			comPort.addEventListener(SerialProxyEvent.SERIAL_PROXY_DATA, onComData);
			isStarted=true;
			//barcode='';
			buffer='';
			//state=STATE_WAIT;
			comPort.start(com_port,com_baud);
		}
		
		public function stop():void{
			stopTimer();
			timer=null;
			destroyCom();
			isStarted=false;
		}
		
		private function onComConnect(event:Event):void{
			comPort.clean();
		}

		private function onComClose(event:Event):void{
			//???	
		}

		private function onComErr(event:SerialProxyEvent):void{
			destroyCom();
			dispatchEvent(new BarCodeEvent(BarCodeEvent.BARCODE_ERR, buffer, event.error));
			isStarted=false;
		}

		private function destroyCom():void{
			if(comPort){
				comPort.removeEventListener(Event.CLOSE, onComClose);
				comPort.removeEventListener(Event.CONNECT, onComConnect);
				comPort.removeEventListener(SerialProxyEvent.SERIAL_PROXY_ERROR, onComErr);
				comPort.removeEventListener(SerialProxyEvent.SERIAL_PROXY_DATA, onComData);
				comPort.stop();
				comPort=null;
			}
		}

		private function onComData(event:SerialProxyEvent):void{
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
					//clean
					barcode = barcode.replace(String.fromCharCode(13),'');
					barcode = barcode.replace(String.fromCharCode(10),'');
					barcode = barcode.replace(String.fromCharCode(02),'');
					buffer=buffer.substr(idx+1);
					dispatchEvent(new BarCodeEvent(BarCodeEvent.BARCODE_READED,barcode));
				}
			} while(idx>-1);
			if(buffer==null) buffer='';
			if(buffer) startTimer();
		}

		private function startTimer():void{
			if(!timer){
				timer=new Timer(TIMEUOT,1);
				timer.addEventListener(TimerEvent.TIMER, onTimer);
			}else{
				timer.reset();
			}
			timer.start();
		}
		private function stopTimer():void{
			if(timer) timer.reset();
		}
		
		private function onTimer(event:TimerEvent):void{
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