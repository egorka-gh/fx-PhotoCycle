package com.photodispatcher.service.barcode{
	import com.photodispatcher.event.SerialProxyEvent;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;
	import flash.net.Socket;
	import flash.utils.ByteArray;
	
	[Event(name="serialProxyData", type="com.photodispatcher.event.SerialProxyEvent")]
	[Event(name="serialProxyError", type="com.photodispatcher.event.SerialProxyEvent")]
	[Event(name="connect", type="flash.events.Event")]
	[Event(name="close", type="flash.events.Event")]
	public class Socket2Com extends EventDispatcher{
		private var comInfo:ComInfo;
		private var socket:Socket;

		public function Socket2Com(comInfo:ComInfo){
			super(null);
			this.comInfo=comInfo;
		}

		public function get comCaption():String{
			return (comInfo?comInfo.label:'COM?');
		}

		public function get sufix():uint{
			if(!comInfo || !comInfo.suffix) return 0;
			return uint(comInfo.suffix);
		}

		public function get tray():int{
			if(!comInfo) return 0;
			return comInfo.tray;
		}

		public function get doubleScanGap():int{
			if(!comInfo || comInfo.type!=ComInfo.COM_TYPE_BARREADER || comInfo.doubleScanGap<=0) return 0;
			return comInfo.doubleScanGap;
		}
		
		public function connect():void{
			if(!comInfo || comInfo.type==ComInfo.COM_TYPE_NONE && !comInfo.num){
				dispatchEvent( new SerialProxyEvent(SerialProxyEvent.SERIAL_PROXY_ERROR,'' ,'Connect error: Порт не настроен'));
				return;
			}
			if(comInfo.isEthernet && !comInfo.remoteIP){
				dispatchEvent( new SerialProxyEvent(SerialProxyEvent.SERIAL_PROXY_ERROR,'' ,'Connect error: IP не настроен'));
				return;
			}
			
			//connect to proxy
			var proxy_port:int=SerialProxy.PROXY_PORT_BASE+int(comInfo.num);
			socket = new Socket();
			socket.addEventListener( Event.CLOSE, onSocket );
			socket.addEventListener( Event.CONNECT, onSocket );
			socket.addEventListener( IOErrorEvent.IO_ERROR, onIOErrorEvent );
			socket.addEventListener( SecurityErrorEvent.SECURITY_ERROR, onSecurityError );
			socket.addEventListener( ProgressEvent.SOCKET_DATA, onSocketData );
			try{
				if(comInfo.isEthernet){
					//remote mode
					socket.connect(comInfo.remoteIP,proxy_port);
				}else{
					socket.connect('127.0.0.1',proxy_port);
				}
			}catch(err:Error){
				dispatchEvent( new SerialProxyEvent(SerialProxyEvent.SERIAL_PROXY_ERROR,'','Connect error: '+err.message));
			}
		}
		
		public function close():void{
			if(socket){
				if(socket.connected) socket.close();
				socket.removeEventListener(Event.CLOSE, onSocket );
				socket.removeEventListener(Event.CONNECT, onSocket );
				socket.removeEventListener(IOErrorEvent.IO_ERROR, onIOErrorEvent );
				socket.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityError );
				socket.removeEventListener(ProgressEvent.SOCKET_DATA, onSocketData );
				
			}
			socket=null;
		}
		
		private function onSocket(event:Event):void{
			dispatchEvent(event.clone());
		}
		
		private function onIOErrorEvent( event:IOErrorEvent ):void{
			dispatchEvent( new SerialProxyEvent(SerialProxyEvent.SERIAL_PROXY_ERROR,'','Socket error: '+event.text));
		}
		
		private function onSecurityError( event:SecurityErrorEvent ):void{
			dispatchEvent( new SerialProxyEvent(SerialProxyEvent.SERIAL_PROXY_ERROR,'','Socket error: '+event.text));
		}
		
		private function onSocketData( event:ProgressEvent ):void{
			var res:String=socket.readUTFBytes(socket.bytesAvailable);
			dispatchEvent( new SerialProxyEvent(SerialProxyEvent.SERIAL_PROXY_DATA,res));
		}
		
		public function get connected():Boolean{
			return socket &&  socket.connected;
		}
		
		public function send( value:String ):void{
			if(!socket || !socket.connected){
				dispatchEvent( new SerialProxyEvent(SerialProxyEvent.SERIAL_PROXY_ERROR,'','Send error: Not connected'));
				return;
			}
			try{
				socket.writeUTFBytes(value);
				socket.flush();
			}catch(err:Error){
				dispatchEvent( new SerialProxyEvent(SerialProxyEvent.SERIAL_PROXY_ERROR,'','Send error: '+err.message));
			}
		}

		public function sendBytes(buffer:ByteArray):void{
			if(!socket || !socket.connected){
				dispatchEvent( new SerialProxyEvent(SerialProxyEvent.SERIAL_PROXY_ERROR,'','Send error: Not connected'));
				return;
			}
			try{
				socket.writeBytes(buffer);
				socket.flush();
			}catch(err:Error){
				dispatchEvent( new SerialProxyEvent(SerialProxyEvent.SERIAL_PROXY_ERROR,'','Send error: '+err.message));
			}
		}

		public function clean():void{
			if(socket && socket.connected && socket.bytesAvailable){
				socket.readUTFBytes(socket.bytesAvailable);
			}
		}
		
		override public function toString():String{
			return 'Socket2Com: '+comCaption;
		}
		
		
	}
}