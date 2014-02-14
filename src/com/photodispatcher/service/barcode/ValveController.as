package com.photodispatcher.service.barcode{
	import com.photodispatcher.event.BarCodeEvent;
	import com.photodispatcher.event.ControllerMesageEvent;
	import com.photodispatcher.interfaces.ISimpleLogger;
	
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.TimerEvent;
	import flash.utils.ByteArray;
	import flash.utils.Timer;

	[Event(name="barcodeReaded", type="com.photodispatcher.event.BarCodeEvent")]
	[Event(name="barcodeError", type="com.photodispatcher.event.BarCodeEvent")]
	[Event(name="error", type="flash.events.ErrorEvent")]
	[Event(name="complete", type="flash.events.Event")]
	[Event(name="controllerMesage", type="com.photodispatcher.event.ControllerMesageEvent")]
	public class ValveController extends ComDevice{
		/*
		[13:52:12] Anton: вроде окончательно:
		//err0 - ошибка 6го байта посылки, не равен 0x0d
		//err1 - тайм-аут, т.е. долго нет ожидаемого байта 
		//err2 - при установке клапано нет знака равно
		//err3 - неизвестный номер кнопки/клапана(т.е. второй символ команды) или нет знака равно 
		//err4 - неизвестная команда(т.е.первый символ команды)
		//err5 - некорректное значение установки 
		//err6 - неверное время дребезга(более 99мс)
		[13:55:03] Anton: *b0=[0-1][0x0D]
		*b[1-2]=[1][0x0D]
		*v[0-7]=[0-1][0x0D]
		сообщения от меня:
		*s0=0[0x0D]
		*s0=1[0x0D]
		дребезг трогать не будем, команда есть, но я там уже установил нормальное время
		[13:57:15] Igor Zadenov: погоди у нас сколько кнопок 3?
		[13:57:24] Anton: да
		[13:58:44] Anton: 0ая это н адвигатель, она работает - пока нажата - работает, поэтому когда устанавливаешь 1 - работает, 0 - стоп
		компрессора пуск/стоп это 1 и 2, туда ты просто отсылаешь 1 и я выдерживаю 500мс , эмулирую нажатие кнопки
		*/
		public static const ERROR_CONTROLLER_ERROR:int=1;
		
		public static const ERROR_ACKNOWLEDGE_TIMEOUT:int	=100;
		public static const ERROR_REINIT:int				=101;
		public static const ERROR_WRONG_MESAGE:int			=102;
		public static const ERROR_WRONG_RLC:int				=103;
		public static const ERROR_BUSY:int					=104;
		public static const ERROR_COM:int					=105;
		
		
		public static const COMMAND_STATE_SEPARATOR:String='=';
		public static const COMMAND_VALVE_PREFIX:String='*v'; //*v0=1 + LRC + 0x0d
		public static const COMMAND_VALVE_ALL:String='*v@'; //*v@=0 + LRC + 0x0d
		public static const COMMAND_BUTTON_PREFIX:String='*b'; //*b0=1 + LRC + 0x0d // 1-push, 0-release (release - only 4 engine(*b0))
		public static const COMMAND_SET_FLUCTUATION:String='*dbc'; //*dbcX + LRC + 0x0d, X= 0-200 unsigned cha
		
		public static const MSG_SUFIX:int=0x0D;
		public static const MSG_CONTROLLER_INIT:String='start'; //'start+0x0d
		public static const MSG_CONTROLLER_INIT2:String='*BOOT'; //'*BOOT0x0d
		public static const MSG_CONTROLLER_ACKNOWLEDGE:String='ok'; //'ok+0x0d
		public static const MSG_CONTROLLER_ACKNOWLEDGE2:String='*okey'; //'*okey0x0d
		public static const MSG_CONTROLLER_SENSOR_PREFIXF:String='s'; //'*s';//*s0=1 + LRC + 0x0d

		public static const MSG_CONTROLLER_ERROR_PREFIX:String='err';//err1+0x0d
		/*
		public static const MSG_CONTROLLER_ERROR_WRONG_COMMAND:String='err1';//err1+0x0d
		public static const MSG_CONTROLLER_ERROR_READ_TIMEOUT:String='err2';
		public static const MSG_CONTROLLER_ERROR_WRONG_LRC:String='err3';
		*/
		public static const MAX_RESEND:int=1;
		public static const ACKNOWLEDGE_TIMEOUT:int	=100;
		

		public var logger:ISimpleLogger;
		
		private var _isBusy:Boolean;
		public function get isBusy():Boolean{
			return _isBusy;
		}
		
		private var lastCommand:String;
		private var resendCount:int=0;
		
		public function ValveController(){
			super();
			sufix=MSG_SUFIX;
			cleanMsg=false;
			doubleScanGap=0;
			addEventListener(BarCodeEvent.BARCODE_READED,onMessage,false,int.MAX_VALUE);
			addEventListener(BarCodeEvent.BARCODE_ERR,onComError,false,int.MAX_VALUE);
		}

		//valves control
		//revers notation: command On - mean - power On - valve Off 

		public function closeAll():void{
			if(!isStarted) return;
			sendCmd(COMMAND_VALVE_ALL+COMMAND_STATE_SEPARATOR+'1');
		}

		public function close(valve:int):void{
			if(!isStarted) return;
			if(valve<0 || valve>7) return;
			sendCmd(COMMAND_VALVE_PREFIX+valve.toString(10)+COMMAND_STATE_SEPARATOR+'1');
		}

		public function open(valve:int):void{
			if(!isStarted) return;
			if(valve<0 || valve>7) return;
			sendCmd(COMMAND_VALVE_PREFIX+valve.toString(10)+COMMAND_STATE_SEPARATOR+'0');
		}
		
		private function onComError(event:BarCodeEvent):void{
			log('! COM error: '+event.error+' ('+event.barcode+')');
			dispatchEvent(new ErrorEvent(ErrorEvent.ERROR,false,false,event.error,ERROR_COM));
		}
		
		private function onMessage(event:BarCodeEvent):void{
			var msg:String=event.barcode;
			if(!msg) return;
			log('< '+msg);
			//check fo error
			if(msg.substr(0,3)==MSG_CONTROLLER_ERROR_PREFIX){
				if(resendCount>=MAX_RESEND) {
					log('! Controller error ('+event.barcode+')');
					_isBusy=false;
					dispatchEvent(new ErrorEvent(ErrorEvent.ERROR,false,false,'Ошибка контролера ('+event.barcode+')',ERROR_CONTROLLER_ERROR));
				}else{
					resendCount++;
					log('> '+lastCommand+' (resend)');
					send(lastCommand);
				}
				return;
			}
			if(msg==MSG_CONTROLLER_INIT || msg==MSG_CONTROLLER_INIT2){
				log('! Controller Init');
				dispatchEvent(new ErrorEvent(ErrorEvent.ERROR,false,false,'Реинициализация контролера',ERROR_REINIT));
				return;
			}
			if(msg==MSG_CONTROLLER_ACKNOWLEDGE || msg==MSG_CONTROLLER_ACKNOWLEDGE2){
				if(aclTimer) aclTimer.reset();
				_isBusy=false;
				dispatchEvent(new Event(Event.COMPLETE));
				return;
			}
			/*
			//read vs LRC
			if(msg.length<3){
				log('! Wrong message error: '+msg);
				dispatchEvent(new ErrorEvent(ErrorEvent.ERROR,false,false,'Не верное сообщение: '+msg,ERROR_WRONG_MESAGE));
				return;
			}
			var lrc:int=parseInt(msg.substr(-2),16);
			if(!checkLRC(msg.substr(0,msg.length-2),lrc)){
				log('! LRC error: '+msg);
				dispatchEvent(new ErrorEvent(ErrorEvent.ERROR,false,false,'Ошибка контрольной суммы: '+msg,ERROR_WRONG_RLC));
				return;
			}
			msg=msg.substr(0,msg.length-2);
			*/
			//parse
			if(msg.substr(0,MSG_CONTROLLER_SENSOR_PREFIXF.length)!=MSG_CONTROLLER_SENSOR_PREFIXF){
				log('! Wrong message error: '+msg);
				dispatchEvent(new ErrorEvent(ErrorEvent.ERROR,false,false,'Не верное сообщение: '+msg,ERROR_WRONG_MESAGE));
				return;
			}
			msg=msg.substr(MSG_CONTROLLER_SENSOR_PREFIXF.length-1);
			//TODO parse?
			//var arr:Array=msg.split(COMMAND_STATE_SEPARATOR);
			dispatchEvent(new ControllerMesageEvent(int(msg.charAt(0)),int(msg.charAt(msg.length-1))));
		}

		protected function checkLRC(data:String,lrc:int):Boolean{
			return calcLRC(data)==lrc;
		}
		
		public function calcLRC(data:String):int{
			var checksum:int = 0;
			var i:int;

			if(data){
				var ba:ByteArray= new ByteArray();
				ba.writeUTFBytes(data);
				ba.position=0;
				while (ba.position<ba.length){
					checksum = (checksum + ba.readUnsignedByte()) & 0xFF;
				}
			}
			checksum = ((checksum ^ 0xFF) + 1) & 0xFF;
			return checksum;
		}
		
		private var aclTimer:Timer;
		
		protected function sendCmd(cmd:String):void{
			if(!cmd) return;
			if(_isBusy){
				log('! Busy error');
				dispatchEvent(new ErrorEvent(ErrorEvent.ERROR,false,false,'Нет потверждения предидущей команды ('+lastCommand+'/'+cmd+')',ERROR_BUSY));
				return;
			}
			/* vs LRC
			var msg:String=cmd+calcLRC(cmd).toString(16)+String.fromCharCode(sufix);
			*/
			var msg:String=cmd+String.fromCharCode(sufix);
			_isBusy=true;
			resendCount=0;
			log('> '+msg);
			lastCommand=msg;
			if(!aclTimer){
				aclTimer= new Timer(ACKNOWLEDGE_TIMEOUT,1);
				aclTimer.addEventListener(TimerEvent.TIMER, onAclTimer);
			}
			aclTimer.start();
			send(msg);
		}
		
		private function onAclTimer(evt:TimerEvent):void{
			aclTimer.reset();
			if(resendCount>=MAX_RESEND) {
				log('! ACL timeout error');
				_isBusy=false;
				//dispatchEvent(new ErrorEvent(ErrorEvent.ERROR,false,false,'Таймаут подтверждения команды от контролера',ERROR_ACKNOWLEDGE_TIMEOUT));
			}else{
				resendCount++;
				aclTimer.start();
				log('> '+lastCommand+' (resend)');
				send(lastCommand);
			}
		}

		public function engineOn():void{
			if(!isStarted) return;
			sendCmd(buttonCmd(0,1));
		}
		public function engineOff():void{
			if(!isStarted) return;
			sendCmd(buttonCmd(0,0));
		}

		public function vacuumOn():void{
			if(!isStarted) return;
			sendCmd(buttonCmd(1,1));
		}
		public function vacuumOff():void{
			if(!isStarted) return;
			sendCmd(buttonCmd(2,1));
		}

		private function buttonCmd(butt:int, state:int):String{
			var result:String=COMMAND_BUTTON_PREFIX+butt.toString()+COMMAND_STATE_SEPARATOR+state.toString();
			return result;
		}
		
		protected function log(msg:String):void{
			if(logger) logger.log(msg.replace(String.fromCharCode(sufix), "'hex:"+sufix.toString(16)+"'"));
		}
	}
}
