package com.photodispatcher.service.barcode{
	import com.photodispatcher.event.BarCodeEvent;
	import com.photodispatcher.event.ControllerMesageEvent;
	import com.photodispatcher.interfaces.ISimpleLogger;
	
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.TimerEvent;
	import flash.utils.Timer;
	
	[Event(name="barcodeReaded", type="com.photodispatcher.event.BarCodeEvent")]
	[Event(name="barcodeError", type="com.photodispatcher.event.BarCodeEvent")]
	[Event(name="error", type="flash.events.ErrorEvent")]
	[Event(name="complete", type="flash.events.Event")]
	[Event(name="controllerMesage", type="com.photodispatcher.event.ControllerMesageEvent")]
	public class GlueController extends ComDevice{
		
		public static const ERROR_CONTROLLER_ERROR:int=-1;
		
		public static const ERROR_ACKNOWLEDGE_TIMEOUT:int	=-100;
		public static const ERROR_REINIT:int				=-101;
		public static const ERROR_WRONG_MESAGE:int			=-102;
		public static const ERROR_BUSY:int					=-104;
		public static const ERROR_COM:int					=-105;
		
		/*
		*o0=2#013 - стоп
		*o1=2#013 - кнопка выброса книги
		*i0=1#013  - 1ый датчик вкл
		*i0=0#013  - 1ый датчик выкл
		*i1=1#013  - 2ой датчик вкл
		*i1=0#013  - 2ой датчик выкл		
		*/

		public static const MSG_SUFIX:int=0x0D;

		//public static const COMMAND_BUTTON_PREFIX:String='*b'; 
		public static const COMMAND_STOP:String='*o0=2'; 
		public static const COMMAND_PUSH_BOOK:String='*o1=2'; 
		
		public static const MSG_CONTROLLER_INIT:String='start'; //'start+0x0d
		public static const MSG_CONTROLLER_ACKNOWLEDGE:String='ok'; //'ok+0x0d
		public static const MSG_CONTROLLER_ACKNOWLEDGE2:String='*okey'; //'*okey0x0d
		
		public static const MSG_SENSOR0_ON:String='*i0=1'; 
		public static const MSG_SENSOR0_OFF:String='*i0=0'; 
		public static const MSG_SENSOR1_ON:String='*i1=1'; 
		public static const MSG_SENSOR1_OFF:String='*i1=0'; 

		public static const STATE_SENSOR0_ON:int=0; 
		public static const STATE_SENSOR0_OFF:int=1; 
		public static const STATE_SENSOR1_ON:int=2; 
		public static const STATE_SENSOR1_OFF:int=3; 

		
		
		public static const MSG_CONTROLLER_ALERT_PREFIX:String='*al'; //
		public static const MSG_CONTROLLER_ERROR_PREFIX:String='err';//err1+0x0d

		public static const MAX_RESEND:int=1;
		public static const ACKNOWLEDGE_TIMEOUT:int	=200;
		
		private static var chanelStateNameMap:Object;
		public static function stateName(state:int):String{
			if(!chanelStateNameMap){
				chanelStateNameMap=new Object;
				chanelStateNameMap[STATE_SENSOR0_ON]='Датчик1 ON';
				chanelStateNameMap[STATE_SENSOR0_OFF]='Датчик1 OFF';
				chanelStateNameMap[STATE_SENSOR1_ON]='Датчик2 ON';
				chanelStateNameMap[STATE_SENSOR1_OFF]='Датчик2 OFF';
			}
			var res:String=chanelStateNameMap[state];
			if(!res) res='State#'+state.toString();
			return res;
		}
		
		
		public var logger:ISimpleLogger;

		private var _isBusy:Boolean;
		public function get isBusy():Boolean{
			return _isBusy;
		}
		
		private var lastCommand:String;
		private var resendCount:int=0;

		public function GlueController(){
			super();
			sufix=MSG_SUFIX;
			cleanMsg=false;
			doubleScanGap=0;
			addEventListener(BarCodeEvent.BARCODE_READED,onMessage,false,int.MAX_VALUE);
			addEventListener(BarCodeEvent.BARCODE_ERR,onComError,false,int.MAX_VALUE);
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
			if(msg==MSG_CONTROLLER_INIT){
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
			//alert, not implemented
			if(msg.substr(0,MSG_CONTROLLER_ALERT_PREFIX.length)==MSG_CONTROLLER_ALERT_PREFIX){
				log('ignore ' +msg);
				return;
			}
			
			//check message
			var chanelState:int=-1;
			switch(msg){
				case MSG_SENSOR0_OFF:{
					chanelState=STATE_SENSOR0_OFF;
					break;
				}
				case MSG_SENSOR0_ON:{
					chanelState=STATE_SENSOR0_ON;
					break;
				}
				case MSG_SENSOR1_OFF:{
					chanelState=STATE_SENSOR1_OFF;
					break;
				}
				case MSG_SENSOR1_ON:{
					chanelState=STATE_SENSOR1_ON;
					break;
				}
				default:{
					chanelState=-1;
					break;
				}
			}
			
			if(chanelState==-1){
				log('! Wrong message error: '+msg);
				dispatchEvent(new ErrorEvent(ErrorEvent.ERROR,false,false,'Не верное сообщение: '+msg,ERROR_WRONG_MESAGE));
				return;
			}
			dispatchEvent(new ControllerMesageEvent(0,chanelState));
		}
		
		override public function set comPort(value:Socket2Com):void{
			super.comPort = value;
		}
		
		
		protected function log(msg:String):void{
			if(logger) logger.log(msg.replace(String.fromCharCode(sufix), "'hex:"+sufix.toString(16)+"'"));
		}

		private var aclTimer:Timer;
		
		protected function sendCmd(cmd:String):void{
			if(!cmd) return;
			if(_isBusy){
				log('! Busy error; command: '+cmd);
				dispatchEvent(new ErrorEvent(ErrorEvent.ERROR,false,false,'Нет потверждения предидущей команды ('+lastCommand+'/'+cmd+')',ERROR_BUSY));
				return;
			}
			log('> '+cmd);
			var msg:String=cmd+String.fromCharCode(sufix);
			_isBusy=true;
			resendCount=0;
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
		
		public function engineStop():void{
			if(!isStarted) return;
			sendCmd(COMMAND_STOP);
		}
		public function pushBook():void{
			if(!isStarted) return;
			sendCmd(COMMAND_PUSH_BOOK);
		}

	}
}