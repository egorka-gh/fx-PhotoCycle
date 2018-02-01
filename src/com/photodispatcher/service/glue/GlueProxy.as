package com.photodispatcher.service.glue{
	
	import com.photodispatcher.event.GlueMessageEvent;
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
	[Event(name="gluemessage", type="com.photodispatcher.event.GlueMessageEvent")]
	
	public class GlueProxy extends EventDispatcher{
		/*
		команды считывания статусов
		инфа в сообщении идет блоками
		блок описывает одну сущность типа конкретная кнопель на экране -  имя кнопки, подпись, цвет, состояние   
		общий формат ответа
		
		~~блок1~~блок2~~блок3...~~блокN@@
		@@		 конец сообщения
		~~ 		разделитель блоков
		
		в блоке идут параметры, парами  имя=значение типа Text=Books: 40727
		формат блока
		||parametr1=value1||parametr2=value2...||parametrN=valueN||
		|| 		разделитель параметров
		
		конкретно по каждой команде:
		
		GetStatus
		пример ответа:
		~~||Text=Books: 40727||~~||Text=Books/Day: 5||~~||Text=Page: 0"||~~||Text=Last Book: 20 Pages||~~||Text=Pages per Book: 20||~~||Text=||@@
		(тут поясню, я из гуи получаю просто 6 строк, думаю нет смысла  мне их парсить, это немного геморно в четвертом там число в середине строки сидит, если 
		хочешь могу их поименовать, но пока что реализовано так)
		
		GetProduct
		~~||Name=Product||Text=No product loaded||~~||Name=GLM||Text=Halt||~~||Name=GBT||Text==Halt||@@
		
		GetMessage
		~~||Text=30.01 бла бла бла....||ColText=#FFAA11||ColBack=#BBCCDD||~~||Text=30.02 бла бла бла....||ColText=#FFAA11||ColBack=#BBCCDD||@@
		
		GetButtons
		~~||Name=button1||Text=Start||ColBack=#80FF80||Enabled=True||~~||Name=button4||Text=Quit||ColBack=#FFFF80||Enabled=False||@@
		(максимум 24 кнопки)
		
		
		команды
		
		Start
		Stop
		Quit 				- закрыть программу
		Stop after Job 		- не используется, поидее остановка после сборки книги
		Sheets per Book,N  	- установить кол листов в книге (N - число листов)
		Select Product,NAME - установить имя продукта (NAME - имя продукта)
		Еject Book
		
		в ответ на вышерепечисленные команды прилетает OK
		для следующих прилетает ответ в форамте как описано выше
		
		GetStatus
		GetProduct
		GetMessage
		GetButtons

		*/
		
		public static const RESPONCE_TIMEOUT:int=5000;
		
		public static const ERR_CONNECT:int=1;
		public static const ERR_SEND:int=2;
		public static const ERR_CMD:int=3;

		public static const MSG_ACL:String='OK';
		public static const MSG_ERROR:String='ERROR';

		//buttons
		public static const CMD_DISCONNECT:String='Disconnect';
		public static const CMD_START:String='Start';
		public static const CMD_STOP:String='Stop';
		public static const CMD_QUIT:String='Quit'; //quits the glue station (programm)
		public static const CMD_EJECT_BOOK:String='Еject Book';
		
		//comands
		public static const CMD_STOP_AFTER_JOB:String='Stop after Job'; //???
		public static const CMD_SET_SHEETS:String='Sheets per Book,';
		public static const CMD_SET_PRODUCT:String='Select Product,';
		
		public static const CMD_GET_STATUS:String='GetStatus';
		public static const CMD_GET_PRODUCT:String='GetProduct';
		public static const CMD_GET_MESSAGE:String='GetMessage';
		public static const CMD_GET_BUTTONS:String='GetButtons';
		

		public function GlueProxy(){
			super(null);
		}
		
		//device vars
		[Bindable]
		public var devProduct:String='-';
		[Bindable]
		public var devGLM:String='-';
		[Bindable]
		public var devGBT:String='-';
		[Bindable]
		public var devBookPages:String='-';
		
		
		
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
			cmd_stack.push(new GlueCmd(CMD_START));
			run_next();
		}

		public function run_Stop():void{
			cmd_stack=[];
			cmd_stack.push(new GlueCmd(CMD_STOP));
			run_next();
		}
		
		public function run_SetSheets(sheets:int):void{
			if(sheets<=0){
				riseErr(ERR_SEND,'Не верное количество разворотов: '+sheets.toString());
				return;
			}
			cmd_stack.push(new GlueCmd(CMD_SET_SHEETS+sheets.toString()));
			run_next();
		}

		public function run_SetProduct(product:String):void{
			if(!product){
				riseErr(ERR_SEND,'Пустое название продукта');
				return;
			}
			cmd_stack.push(new GlueCmd(CMD_SET_PRODUCT+product));
			run_next();
		}

		public function run_GetProduct(createLatch:Boolean=false):AsyncLatch{
			devProduct='?';
			devGBT=='?';
			devGLM=='?';
			var latch:AsyncLatch;
			if(createLatch) latch=new AsyncLatch(true);
			cmd_stack.push(new GlueCmd(CMD_GET_PRODUCT,true,latch));
			run_next();
			return latch;
		}
		
		public function run_GetStatus(createLatch:Boolean=false):AsyncLatch{
			devBookPages='?';
			var latch:AsyncLatch;
			if(createLatch) latch=new AsyncLatch(true);
			cmd_stack.push(new GlueCmd(CMD_GET_STATUS,true,latch));
			run_next();
			return latch;
		}
		
		protected function run_next():void{
			if(aclLatch && aclLatch.isStarted) return;
			if(!isStarted) return;

			currCommand=null;

			if(!cmd_stack || cmd_stack.length==0){
				dispatchEvent(new Event(Event.COMPLETE));
				return;
			}

			if(!socket || !socket.connected){
				riseErr(ERR_SEND,'Нет подключения');
				return;
			}
			var cmd:GlueCmd=cmd_stack.shift() as GlueCmd;
			if(!cmd){
				run_next();
				return;
			}
			currCommand=cmd;
			msgBuffer='';
			try{
				startAclLatch();
				socket.writeUTFBytes(currCommand.command);
				socket.flush();
				log('Отправлено: '+currCommand.command);
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
		private var currCommand:GlueCmd;
		
		private function startAclLatch():void{
			if(!isStarted) return;
			
			if(!aclLatch){
				aclLatch=new AsyncLatch(true);
				aclLatch.timeout=RESPONCE_TIMEOUT;
				aclLatch.addEventListener(Event.COMPLETE, onAcl);
			}
			aclLatch.reset();
			if(currCommand && currCommand.latch){
				currCommand.latch.join(aclLatch);
				currCommand.latch.start();
				currCommand.latch.release();
			}
			aclLatch.start();
		}
		private function onAcl(evt:Event):void{
			if(aclLatch.hasError){
				aclLatch.stop();
				riseErr(ERR_CMD,'Ошибка выполнения команды: "'+currCommand.command+'"; отклик: '+aclLatch.error);
				aclLatch.reset();
				currCommand=null;
			}
			run_next();
		}
		
		private var msgBuffer:String;
		
		private function onSocketData( event:ProgressEvent ):void{
			if(!currCommand){
				log('onSocketData no currCommand');
				return;
			}
			if(!aclLatch || !aclLatch.isStarted){
				log('onSocketData aclLatch not started');
				return;
			}

			var res:String=socket.readUTFBytes(socket.bytesAvailable);
			res=res.replace('\n','');
			log('currCommand cmd:'+currCommand.command+'; hasResponce:'+currCommand.hasResponce+'; responce:'+res);
			if(!currCommand.hasResponce){
				//waite simple acl
				if(res==MSG_ACL){
					aclLatch.release();
				}else{
					aclLatch.stop();
					riseErr(ERR_CMD,'Ошибка выполнения команды: "'+currCommand.command+'"; отклик:'+res);
					aclLatch.reset();
				}
			}else{
				//waite message
				msgBuffer+=res;
				if(msgBuffer.substr(-2)== GlueMessage.MSG_CCH_END){
					//complited
					checkMessage(GlueMessage.parse(msgBuffer,currCommand));
					aclLatch.release();
				}
			}
		}
		
		protected function checkMessage(message:GlueMessage):void{
			if(!message || !message.command) return;
			switch(message.command){
				case GlueProxy.CMD_GET_PRODUCT:
					devProduct=message.getBlockItemValue(GlueMessage.BLOCK_KEY_PRODUCT, GlueMessage.ITEM_KEY_TEXT);
					devGBT=message.getBlockItemValue(GlueMessage.BLOCK_KEY_GBT, GlueMessage.ITEM_KEY_TEXT);
					devGLM=message.getBlockItemValue(GlueMessage.BLOCK_KEY_GLM, GlueMessage.ITEM_KEY_TEXT);
					break;
				case GlueProxy.CMD_GET_STATUS:
					devBookPages=message.getBlockItemValue(GlueMessage.BLOCK_KEY_PAGESBOOK, GlueMessage.ITEM_KEY_TEXT);
					break;
				default:
					break;
			}	
			dispatchEvent(new GlueMessageEvent(message));
		}

		protected function log(msg:String):void{
			if(loger) loger.log(msg);
		}

		protected function riseErr(errCode:int,msg:String):void{
			dispatchEvent( new ErrorEvent(ErrorEvent.ERROR,false,false,msg,errCode));
		}

	}
}