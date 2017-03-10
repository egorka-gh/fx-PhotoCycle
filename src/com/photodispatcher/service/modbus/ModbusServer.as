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
	import flash.events.ServerSocketConnectEvent;
	import flash.events.TimerEvent;
	import flash.net.ServerSocket;
	import flash.net.Socket;
	import flash.utils.ByteArray;
	import flash.utils.Timer;
	
	[Event(name="connectChange", type="flash.events.Event")]
	[Event(name="error", type="flash.events.ErrorEvent")]
	[Event(name="requestEvent", type="com.photodispatcher.service.modbus.ModbusRequestEvent")]
	public class ModbusServer extends EventDispatcher{

		public function ModbusServer(){
			super(null);
		}

		public var serverIP:String='192.168.250.2';
		public var serverPort:int=503;
		
		private var _deviceId:int=0xFF;
		public function get deviceId():int{
			return _deviceId;
		}
		public function set deviceId(value:int):void{
			if(value < 0 || value > 0xFF) value=0xFF;
			_deviceId = value;
		}
		
		
		private var serverSocket:ServerSocket;
		private var clientSocket:Socket;
		
		public function start():void{
			if(!serverIP || !serverPort){
				logErr('TCP IP:Port не настроены');
				return;
			}
			
			if(serverSocket){
				serverSocket.removeEventListener(ServerSocketConnectEvent.CONNECT,onClientSocketConnect);
				serverSocket.removeEventListener(Event.CLOSE, onserverSocketClose);
				if(serverSocket.bound) serverSocket.close(); 
			}
			serverSocket = new ServerSocket();
			serverSocket.addEventListener(ServerSocketConnectEvent.CONNECT,onClientSocketConnect);
			serverSocket.addEventListener(Event.CLOSE, onserverSocketClose);
			
			try{
				serverSocket.bind(serverPort, serverIP);
				serverSocket.listen();
				logMsg('Ожидаю подключение контролера');
			}catch(err:Error){
				logErr('Connect error: '+err.message);
			}
			dispatchEvent(new Event('connectChange'));
		}
		
		public function stop():void{
			if(clientSocket){
				clientSocket.removeEventListener(Event.CLOSE, onSocketClose );
				clientSocket.removeEventListener(IOErrorEvent.IO_ERROR, onIOErrorEvent );
				clientSocket.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityError );
				clientSocket.removeEventListener(ProgressEvent.SOCKET_DATA, onSocketData );
				if(clientSocket.connected) clientSocket.close();
			}
			clientSocket=null;

			if(serverSocket){
				serverSocket.removeEventListener(ServerSocketConnectEvent.CONNECT,onClientSocketConnect);
				serverSocket.removeEventListener(Event.CLOSE, onserverSocketClose);
				if(serverSocket.bound) serverSocket.close(); 
			}
			serverSocket=null;
			dispatchEvent(new Event('connectChange'));
		}
		
		[Bindable('connectChange')]
		public function set connected(val:Boolean):void{dispatchEvent(new Event('connectChange'));}
		public function get connected():Boolean{
			return serverSocket &&  serverSocket.listening;
		}

		[Bindable('connectChange')]
		public function set cilentConnected(val:Boolean):void{dispatchEvent(new Event('connectChange'));}
		public function get cilentConnected():Boolean{
			return clientSocket &&  clientSocket.connected;
		}

		private function onSocketData( event:ProgressEvent ):void{
			var bytes:ByteArray = new ByteArray();
			event.target.readBytes(bytes, 0, event.target.bytesAvailable);
			if(ignoreMessage){
				cleanController();
				return;
			}
			logMsg('< '+ModbusBytes.byteArrayToStr(bytes));
			var adu:ModbusADU=ModbusADU.readResponse(bytes);
			var needResponse:Boolean=true;
			if(adu){
				if(adu.pdu){
					//autoresponse
					if(adu.pdu.functionCode==ModbusPDU.FUNC_WRITE_REGISTER){
						sendBytes(bytes);
						needResponse=false;
					}
				}
				dispatchEvent(new ModbusRequestEvent(adu,needResponse));
			}else{
				logMsg('ADU not parsed');
			}
		}
		
		
		private function sendBytes(buffer:ByteArray):void{
			if(!cilentConnected){
				logErr('Контроллер не подключен');
				return;
			}
			logMsg('> '+ModbusBytes.byteArrayToStr(buffer));
			try{
				clientSocket.writeBytes(buffer);
				clientSocket.flush();
			}catch(err:Error){
				logErr('Ошибка отправки: '+err.message);
			}
		}
		
		private function onClientSocketConnect(event:ServerSocketConnectEvent ):void{
			if(clientSocket){
				clientSocket.removeEventListener(Event.CLOSE, onSocketClose );
				clientSocket.removeEventListener(IOErrorEvent.IO_ERROR, onIOErrorEvent );
				clientSocket.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityError );
				clientSocket.removeEventListener(ProgressEvent.SOCKET_DATA, onSocketData );
				if(clientSocket.connected) clientSocket.close();
			}
			cleanController();
			clientSocket = event.socket;
			clientSocket.addEventListener(Event.CLOSE, onSocketClose );
			clientSocket.addEventListener(IOErrorEvent.IO_ERROR, onIOErrorEvent );
			clientSocket.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityError );
			clientSocket.addEventListener(ProgressEvent.SOCKET_DATA, onSocketData );
			logMsg("Подключен контролер " + clientSocket.remoteAddress + ":" + clientSocket.remotePort );
			dispatchEvent(new Event('connectChange'));
			
		}
		
		private var cleanTimer:Timer;
		private var ignoreMessage:Boolean;
		private function cleanController():void{
			ignoreMessage=true;
			if(!cleanTimer){
				cleanTimer= new Timer(1000,1);
				cleanTimer.addEventListener(TimerEvent.TIMER_COMPLETE,oncleanTimer);
			}
			cleanTimer.reset();
			cleanTimer.start();
		}
		private function oncleanTimer(evt:TimerEvent):void{
			ignoreMessage=false;
			logMsg('message buffer clean complete');
		}

		private function onserverSocketClose(event:Event):void{
			logErr('Server disconnected');
			if(clientSocket){
				clientSocket.removeEventListener(Event.CLOSE, onSocketClose );
				clientSocket.removeEventListener(IOErrorEvent.IO_ERROR, onIOErrorEvent );
				clientSocket.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityError );
				clientSocket.removeEventListener(ProgressEvent.SOCKET_DATA, onSocketData );
				if(clientSocket.connected) clientSocket.close();
			}
			clientSocket=null;
			serverSocket.removeEventListener(ServerSocketConnectEvent.CONNECT,onClientSocketConnect);
			serverSocket.removeEventListener(Event.CLOSE, onserverSocketClose);
			serverSocket=null;
			dispatchEvent(new Event('connectChange'));
		}
		
		private function onSocketClose(event:Event):void{
			logErr('Соединение с контролером разорвано');
			clientSocket.removeEventListener(Event.CLOSE, onSocketClose );
			clientSocket.removeEventListener(IOErrorEvent.IO_ERROR, onIOErrorEvent );
			clientSocket.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityError );
			clientSocket.removeEventListener(ProgressEvent.SOCKET_DATA, onSocketData );
			if(clientSocket.connected) clientSocket.close();
			clientSocket=null;
			dispatchEvent(new Event('connectChange'));
		}
		
		private function onIOErrorEvent( event:IOErrorEvent ):void{
			logErr('Ошибка соединения с контролером: '+event.text);
			clientSocket.removeEventListener(Event.CLOSE, onSocketClose );
			clientSocket.removeEventListener(IOErrorEvent.IO_ERROR, onIOErrorEvent );
			clientSocket.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityError );
			clientSocket.removeEventListener(ProgressEvent.SOCKET_DATA, onSocketData );
			if(clientSocket.connected) clientSocket.close();
			clientSocket=null;
			dispatchEvent(new Event('connectChange'));
		}
		
		private function onSecurityError( event:SecurityErrorEvent ):void{
			logErr('Ошибка соединения с контролером: '+event.text);
			clientSocket.removeEventListener(Event.CLOSE, onSocketClose );
			clientSocket.removeEventListener(IOErrorEvent.IO_ERROR, onIOErrorEvent );
			clientSocket.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityError );
			clientSocket.removeEventListener(ProgressEvent.SOCKET_DATA, onSocketData );
			if(clientSocket.connected) clientSocket.close();
			clientSocket=null;
			dispatchEvent(new Event('connectChange'));
		}
		
		
		protected function logErr(msg:String):void{
			dispatchEvent( new ErrorEvent(ErrorEvent.ERROR,false,false,msg,1));
		}
		protected function logMsg(msg:String):void{
			dispatchEvent( new ErrorEvent(ErrorEvent.ERROR,false,false,msg,0));
		}

		
	}
}
