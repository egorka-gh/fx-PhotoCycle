package com.photodispatcher.service.modbus{
	import com.photodispatcher.service.modbus.data.ModbusADU;
	import com.photodispatcher.service.modbus.data.ModbusBytes;
	import com.photodispatcher.service.modbus.data.ModbusPDU;
	
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.TimerEvent;
	import flash.net.Socket;
	import flash.utils.ByteArray;
	import flash.utils.Timer;
	
	[Event(name="connectChange", type="flash.events.Event")]
	[Event(name="error", type="flash.events.ErrorEvent")]
	[Event(name="responseEvent", type="com.photodispatcher.service.modbus.ModbusResponseEvent")]
	public class ModbusClient extends EventDispatcher{

		public static const MODBUS_TIMEOUT:int=1000;
		public static const RECCONECT_INTERVAL:int=10000;

		public function ModbusClient(){
			super(null);
			timeoutTimer= new Timer(MODBUS_TIMEOUT,1);
			timeoutTimer.addEventListener(TimerEvent.TIMER_COMPLETE,onTimeoutTimer);
			reconnectTimer= new Timer(RECCONECT_INTERVAL,1);
			reconnectTimer.addEventListener(TimerEvent.TIMER_COMPLETE,onReconnectTimer);
		}
		

		public var serverIP:String='192.168.250.1';
		public var serverPort:int=502;
		
		private var _deviceId:int=0xFF;
		public function get deviceId():int{
			return _deviceId;
		}
		public function set deviceId(value:int):void{
			if(value < 0 || value > 0xFF) value=0xFF;
			_deviceId = value;
		}


		private var socket:Socket;
		
		public function start():void{
			sendQueue=[];
			if(!serverIP || !serverPort){
				logErr('TCP IP:Port не настроены');
				return;
			}
			if(socket){
				socket.removeEventListener(Event.CLOSE, onSocketClose );
				socket.removeEventListener(Event.CONNECT, onSocketConnect );
				socket.removeEventListener(IOErrorEvent.IO_ERROR, onIOErrorEvent );
				socket.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityError );
				socket.removeEventListener(ProgressEvent.SOCKET_DATA, onSocketData );
				if(socket.connected) socket.close();
			}

			socket = new Socket();
			socket.addEventListener( Event.CLOSE, onSocketClose );
			socket.addEventListener( Event.CONNECT, onSocketConnect );
			socket.addEventListener( IOErrorEvent.IO_ERROR, onIOErrorEvent );
			socket.addEventListener( SecurityErrorEvent.SECURITY_ERROR, onSecurityError );
			socket.addEventListener( ProgressEvent.SOCKET_DATA, onSocketData );
			try{
				socket.connect(serverIP,serverPort);
			}catch(err:Error){
				logErr('Connect error: '+err.message);
				if(reconnectTimer){
					reconnectTimer.reset();
					reconnectTimer.start();
				}
			}
		}
		
		public function stop():void{
			sendQueue=[];
			popTransaction();
			if(reconnectTimer) reconnectTimer.reset();
			if(socket){
				socket.removeEventListener(Event.CLOSE, onSocketClose );
				socket.removeEventListener(Event.CONNECT, onSocketConnect );
				socket.removeEventListener(IOErrorEvent.IO_ERROR, onIOErrorEvent );
				socket.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityError );
				socket.removeEventListener(ProgressEvent.SOCKET_DATA, onSocketData );
				if(socket.connected) socket.close();
			}
			socket=null;
			dispatchEvent(new Event('connectChange'));
		}
		
		[Bindable('connectChange')]
		public function set connected(val:Boolean):void{dispatchEvent(new Event('connectChange'));}
		public function get connected():Boolean{
			return socket &&  socket.connected;
		}

		public function writeRegister(address:int, value:int):void{
			logMsg('Запись в регистр '+address.toString(16)+' значения 0x'+value.toString(16));
			if(!connected){
				logErr('Не подключен');
				return;
			}
			/*
			if(hasTransaction){
				logErr('Не завершена предидущая операция');
				return;
			}
			*/
			var adu:ModbusADU=new ModbusADU();
			adu.transactionId=nextTransaction;
			var pdu:ModbusPDU= new ModbusPDU(ModbusPDU.FUNC_WRITE_REGISTER);
			pdu.address=address;
			pdu.value=value;
			adu.pdu=pdu;
			sendAdu(adu);
			/*
			var ba:ByteArray=adu.createRequest();
			if(ba && ba.length>0) sendBytes(ba);
			*/
		}

		public function readHoldingRegisters(startingAddress:int, quantity:int):void{
			logMsg('Чтение '+quantity.toString()+' регистров, адрес 0x'+startingAddress.toString(16));
			if(!connected){
				logErr('Не подключен');
				return;
			}
			/*
			if(hasTransaction){
				logErr('Не завершена предидущая операция');
				return;
			}
			*/
			var adu:ModbusADU=new ModbusADU();
			adu.transactionId=nextTransaction;
			var pdu:ModbusPDU= new ModbusPDU(ModbusPDU.FUNC_READ_HOLDING_REGISTERS);
			pdu.address=startingAddress;
			pdu.value=quantity;
			adu.pdu=pdu;
			sendAdu(adu);
			/*
			var ba:ByteArray=adu.createRequest();
			if(ba && ba.length>0) sendBytes(ba);
			*/
		}

		
		
		private var _transactionId:int=0;
		public function get currentTransaction():int{
			return _transactionId;
		}
		private function get nextTransaction():int{
			_transactionId=(_transactionId+1) & 0xFFFF;
			return _transactionId;
		}
		
		private var hasTransaction:Boolean;
		private function pushTransaction():void{
			/*TODO implement
				 add currentTransaction to poll
				implement transaction depth check
			*/
			//serial implementation
			//dummy flip
			hasTransaction=true;
			if(timeoutTimer){
				timeoutTimer.reset();
				timeoutTimer.start();
			}
		}
		private function popTransaction(transactionId:int=0):Boolean{
			//TODO implement 
			//dummy flop
			var res:Boolean=hasTransaction;
			hasTransaction=false;
			sendNextAdu();
			return res;
		}

		private var timeoutTimer:Timer; 
		private function onTimeoutTimer(e:TimerEvent):void{
			if(hasTransaction){
				logErr('Таймут ожидания отклика контролера');
				popTransaction();
			}
		}
		private var reconnectTimer:Timer; 
		private function onReconnectTimer(e:TimerEvent):void{
			if(!connected){
				logMsg('Переподключение к контролеру');
				start();
			}
		}

		private function onSocketConnect(event:Event):void{
			if(reconnectTimer) reconnectTimer.reset();
			logMsg('Подключен');
			dispatchEvent(new Event('connectChange'));
		}
		private function onSocketClose(event:Event):void{
			logErr('Соединение разорвано');
			if(reconnectTimer){
				reconnectTimer.reset();
				reconnectTimer.start();
			}
			dispatchEvent(new Event('connectChange'));
		}
		
		private function onIOErrorEvent( event:IOErrorEvent ):void{
			logErr('Socket error: '+event.text);
			if(socket.connected) socket.close();
			if(reconnectTimer){
				reconnectTimer.reset();
				reconnectTimer.start();
			}
			dispatchEvent(new Event('connectChange'));
		}
		
		private function onSecurityError( event:SecurityErrorEvent ):void{
			logErr('Socket error: '+event.text);
			if(socket.connected) socket.close();
			if(reconnectTimer){
				reconnectTimer.reset();
				reconnectTimer.start();
			}
			dispatchEvent(new Event('connectChange'));
		}

		
		private function onSocketData( event:ProgressEvent ):void{
			var bytes:ByteArray = new ByteArray();
			event.target.readBytes(bytes, 0, event.target.bytesAvailable);
			logMsg('◄ '+ModbusBytes.byteArrayToStr(bytes));
			if(!hasTransaction) return;
			var adu:ModbusADU=ModbusADU.readResponse(bytes);
			if(adu){
				dispatchEvent( new ModbusResponseEvent(adu));
				popTransaction();
			}else{
				logMsg('ADU not parsed');
			}
			/*
			if(adu){
				if(popTransaction(adu.transactionId)) dispatchEvent( new ModbusResponseEvent(adu));
			}
			*/
		}
		
		private var sendQueue:Array;
		private function sendAdu(adu:ModbusADU):void{
			if(!adu) return;
			if(!sendQueue) sendQueue=[];
			sendQueue.push(adu);
			sendNextAdu();
		}
		private function sendNextAdu():void{
			if(hasTransaction) return;
			if(!sendQueue || sendQueue.length==0) return;
			if(!connected){
				sendQueue=[];
				logErr('Не подключен');
				return;
			}

			var adu:ModbusADU;
			while(!adu && sendQueue.length>0){
				adu=sendQueue.shift() as ModbusADU;
			}
			if(!adu) return;
			var ba:ByteArray=adu.createRequest();
			if(ba && ba.length>0){
				sendBytes(ba);
			}else{
				sendNextAdu();
			}
		}
		
		private function sendBytes(buffer:ByteArray):void{
			if(!connected){
				logErr('Не подключен');
				return;
			}
			logMsg('► '+ModbusBytes.byteArrayToStr(buffer));
			try{
				pushTransaction();
				socket.writeBytes(buffer);
				socket.flush();
			}catch(err:Error){
				logErr('Ошибка отправки: '+err.message);
				popTransaction();
			}
		}

		protected function logErr(msg:String):void{
			dispatchEvent( new ErrorEvent(ErrorEvent.ERROR,false,false,msg,1));
		}
		protected function logMsg(msg:String):void{
			dispatchEvent( new ErrorEvent(ErrorEvent.ERROR,false,false,msg,0));
		}

	}
}