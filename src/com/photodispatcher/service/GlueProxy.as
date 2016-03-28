package com.photodispatcher.service{
	
	import com.photodispatcher.interfaces.ISimpleLogger;
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

		public static const CMD_DISCONNECT:String='Disconnect';
		public static const CMD_START:String='Start';
		public static const CMD_STOP:String='Stop';
		public static const CMD_QUIT:String='Quit'; //quits the glue station (programm)
		public static const CMD_STOP_AFTER_JOB:String='Stop after Job'; //???
		public static const CMD_SET_SHEETS:String='Sheets per Book,';
		public static const CMD_SET_PRODUCT:String='Select Product,';

		public function GlueProxy(){
			super(null);
		}
		
		public var loger:ISimpleLogger;
		
		protected var proxy_port:int;
		protected var hostIP:String;
		private var socket:Socket;

		private var cmd_stack:Array=[];

		[Bindable]
		public var isStarted:Boolean;
		
		public function start(hostIP:String,proxy_port:int):void{
			isStarted=false;
			cmd_stack=[];
			connect(hostIP,proxy_port);
		}

		public function stop():void{
			isStarted=false;
			cmd_stack=[];
			closeConnection();
		}
		
		public function run_Start():void{
			cmd_stack.push(CMD_START);
			run_next();
		}

		public function run_Stop():void{
			cmd_stack=[];
			cmd_stack.push(CMD_STOP);
			run_next();
		}
		
		public function run_SetSheets(sheets:int):void{
			if(sheets<=0){
				riseErr(ERR_SEND,'Не верное количество разворотов: '+sheets.toString());
				return;
			}
			cmd_stack.push(CMD_SET_SHEETS+sheets.toString());
			run_next();
		}

		public function run_SetProduct(product:String):void{
			if(!product){
				riseErr(ERR_SEND,'Пустое название продукта');
				return;
			}
			cmd_stack.push(CMD_SET_PRODUCT+product);
			run_next();
		}

		protected function run_next():void{
			if(aclLatch && aclLatch.isStarted) return;
			if(!isStarted) return;

			if(!cmd_stack || cmd_stack.length==0){
				dispatchEvent(new Event(Event.COMPLETE));
				return;
			}

			if(!socket || !socket.connected){
				riseErr(ERR_SEND,'Нет подключения');
				return;
			}
			currCommand=cmd_stack.shift();
			//TODO time out ????
			try{
				startAclLatch();
				socket.writeUTFBytes(currCommand);
				socket.flush();
				log('Отправлено: '+currCommand);
			}catch(err:Error){
				aclLatch.reset();
				riseErr(ERR_SEND,'Ошибка отправки: '+err.message);
			}

		}

		protected function closeConnection():void{
			//trace('close soket');
			if(socket){
				if(socket.connected){
					try{
						socket.writeUTFBytes(CMD_DISCONNECT);
						socket.flush();
						log('Закрытие соедиения..');
					}catch(err:Error){
					}
					socket.close();
				}
				socket.removeEventListener(Event.CLOSE, onSocketClose );
				socket.removeEventListener(Event.CONNECT, onSocketConnect );
				socket.removeEventListener(IOErrorEvent.IO_ERROR, onIOErrorEvent );
				socket.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityError );
				socket.removeEventListener(ProgressEvent.SOCKET_DATA, onSocketData );
			}
			socket=null;
		}
		

		protected function connect(hostIP:String,proxy_port:int):void{
			this.proxy_port=proxy_port;
			this.hostIP=hostIP;
			if(!proxy_port || !hostIP){
				riseErr(ERR_CONNECT,'Не настроены параметры подключения');
				return;
			}
			
			closeConnection();
			
			log('Подключение к '+hostIP+':'+proxy_port.toString());
			socket = new Socket();
			socket.addEventListener( Event.CLOSE, onSocketClose );
			socket.addEventListener( Event.CONNECT, onSocketConnect );
			socket.addEventListener( IOErrorEvent.IO_ERROR, onIOErrorEvent );
			socket.addEventListener( SecurityErrorEvent.SECURITY_ERROR, onSecurityError );
			socket.addEventListener( ProgressEvent.SOCKET_DATA, onSocketData );
			try{
				socket.connect(hostIP,proxy_port);
			}catch(err:Error){
				riseErr(ERR_CONNECT,'Ошибка подключения: '+err.message);
			}
		}

		private function onSocketClose(event:Event):void{
			if(isStarted){
				stop();
				riseErr(ERR_CONNECT,'Подключение закрыто');
			}else{
				dispatchEvent(event.clone());
			}
		}
		private function onSocketConnect(event:Event):void{
			isStarted=true;
			log('Подключено к '+hostIP+':'+proxy_port.toString());
			dispatchEvent(event.clone());
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
			run_next();
		}
		
		private function onSocketData( event:ProgressEvent ):void{
			var res:String=socket.readUTFBytes(socket.bytesAvailable);
			res=res.replace('\n','');
			if(aclLatch && aclLatch.isStarted){
				if(res==MSG_ACL){
					aclLatch.release();
				}else{
					aclLatch.reset();
					riseErr(ERR_CMD,'Ошибка выполнения команды: "'+currCommand+'"; отклик:'+res);
				}
			}
		}

		protected function log(msg:String):void{
			if(loger) loger.log(msg);
		}

		protected function riseErr(errCode:int,msg:String):void{
			dispatchEvent( new ErrorEvent(ErrorEvent.ERROR,false,false,msg,errCode));
		}

	}
}