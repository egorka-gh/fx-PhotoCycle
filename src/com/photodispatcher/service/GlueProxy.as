package com.photodispatcher.service{
	
	import com.photodispatcher.model.mysql.AsyncLatch;
	
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;
	import flash.net.Socket;
	
	[Event(name="connect", type="flash.events.Event")]
	[Event(name="close", type="flash.events.Event")]
	[Event(name="error", type="flash.events.ErrorEvent")]
	[Event(name="complete", type="flash.events.Event")]
	public class GlueProxy extends EventDispatcher{
		
		public static const ERR_CONNECT:int=1;
		public static const ERR_SEND:int=2;
		public static const ERR_CMD:int=3;

		public static const MSG_ACL:String='OK';
		public static const MSG_ERROR:String='ERROR';
		
		public function GlueProxy(){
			super(null);
		}
		
		protected var proxy_port:int;
		protected var hostIP:String;
		private var socket:Socket;

		private var _isStarted:Boolean;
		public function get isStarted():Boolean{
			return _isStarted;
		}

		
		public function start(hostIP:String,proxy_port:int):void{
			_isStarted=true;
			connect(hostIP,proxy_port);
		}

		public function stop():void{
			_isStarted=false;
			closeConnection();
		}

		protected function closeConnection():void{
			if(socket){
				socket.removeEventListener(Event.CLOSE, onSocket );
				socket.removeEventListener(Event.CONNECT, onSocket );
				socket.removeEventListener(IOErrorEvent.IO_ERROR, onIOErrorEvent );
				socket.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityError );
				socket.removeEventListener(ProgressEvent.SOCKET_DATA, onSocketData );
				if(socket.connected) socket.close();
			}
			socket=null;
		}
		

		protected function connect(hostIP:String,proxy_port:int){
			this.proxy_port=proxy_port;
			this.hostIP=hostIP;
			if(!proxy_port || !hostIP){
				riseErr(ERR_CONNECT,'Не настроены параметры подключения');
				return;
			}
			
			closeConnection();
			
			socket = new Socket();
			socket.addEventListener( Event.CLOSE, onSocket );
			socket.addEventListener( Event.CONNECT, onSocket );
			socket.addEventListener( IOErrorEvent.IO_ERROR, onIOErrorEvent );
			socket.addEventListener( SecurityErrorEvent.SECURITY_ERROR, onSecurityError );
			socket.addEventListener( ProgressEvent.SOCKET_DATA, onSocketData );
			try{
				socket.connect(hostIP,proxy_port);
			}catch(err:Error){
				riseErr(ERR_CONNECT,'Ошибка подключения: '+err.message);
			}
		}

		private function onSocket(event:Event):void{
			if(isStarted && event.type==Event.CLOSE){
				stop();
				riseErr(ERR_CONNECT,'Подключение закрыто');
			}else{
				dispatchEvent(event.clone());
			}
		}
		private function onIOErrorEvent( event:IOErrorEvent ):void{
			riseErr(ERR_CONNECT,'Ошибка ввода/вывода: '+event.text);
		}
		private function onSecurityError( event:SecurityErrorEvent ):void{
			riseErr(ERR_CONNECT,'Ошибка подключения: '+event.text);
		}

		
		private var aclLatch:AsyncLatch;
		private var currCommand:String;
		
		private function startAclLatch():void{
			if(!isStarted) return;
			
			if(!aclLatch){
				aclLatch=new AsyncLatch(true);
				aclLatch.addEventListener(Event.COMPLETE, onAcl);
			}
			aclLatch.reset();
			aclLatch.start();
		}
		private function onAcl(evt:Event):void{
			dispatchEvent(new Event(Event.COMPLETE));
		}
		
		private function onSocketData( event:ProgressEvent ):void{
			var res:String=socket.readUTFBytes(socket.bytesAvailable);
			if(aclLatch && aclLatch.isStarted){
				if(res==MSG_ACL){
					aclLatch.release();
				}else{
					aclLatch.reset();
					riseErr(ERR_CMD,'Ошибка выполнения команды: "'+currCommand+'"; отклик:'+res);
				}
			}
		}

		private function send( value:String ):void{
			if(!isStarted) return;
			//TODO time out ????
			if(!socket || !socket.connected){
				riseErr(ERR_SEND,'Нет подключения');
				return;
			}
			try{
				startAclLatch();
				socket.writeUTFBytes(value);
				socket.flush();
			}catch(err:Error){
				aclLatch.reset();
				riseErr(ERR_SEND,'Ошибка отправки: '+err.message);
			}
		}
		
		protected function riseErr(errCode:int,msg:String):void{
			dispatchEvent( new ErrorEvent(ErrorEvent.ERROR,false,false,msg,errCode));
		}

	}
}