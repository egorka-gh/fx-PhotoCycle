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
	public class FeederController extends ComDevice{
		
		public static const ERROR_CONTROLLER_ERROR:int=-1;
		
		public static const ERROR_ACKNOWLEDGE_TIMEOUT:int	=-100;
		public static const ERROR_REINIT:int				=-101;
		public static const ERROR_WRONG_MESAGE:int			=-102;
		public static const ERROR_BUSY:int					=-104;
		public static const ERROR_COM:int					=-105;
		
		/*
		*b0=1#013 *b0=0#013 компрессор
		*b1=1#013 *b1=0#013 подать питание
		*b2=1#013 импульс
		
		*stck#013 - датчик стопы
		*sngs#013 - одинарный лист
		*dbls#013 - двойной лист
		*pass#013 - лист ушел
		
		*/

		public static const MSG_SUFIX:int=0x0D;

		//public static const COMMAND_BUTTON_PREFIX:String='*b'; 
		public static const COMMAND_COMPRESSOR_ON:String='*b0=1'; 
		public static const COMMAND_COMPRESSOR_OFF:String='*b0=0'; 
		public static const COMMAND_POWER_ON:String='*b1=1'; 
		public static const COMMAND_POWER_OFF:String='*b1=0'; 
		public static const COMMAND_FEED:String='*b2=1'; 
		public static const COMMAND_CHECK_REAM_EMPTY:String='*gets'; 
		
		public static const MSG_CONTROLLER_INIT:String='start'; //'start+0x0d
		public static const MSG_CONTROLLER_ACKNOWLEDGE:String='ok'; //'ok+0x0d
		public static const MSG_CONTROLLER_ACKNOWLEDGE2:String='*okey'; //'*okey0x0d
		
		public static const MSG_SHEET_PASS:String='*pass'; 
		public static const MSG_SINGLE_SHEET:String='*sngs'; 
		public static const MSG_DOUBLE_SHEET:String='*dbls'; 
		public static const MSG_REAM_EMPTY_OLD:String='*stck'; 
		public static const MSG_REAM_EMPTY:String='*st=0'; 
		public static const MSG_REAM_FILLED:String='*st=1'; 

		public static const CHANEL_STATE_SHEET_PASS:int=0; 
		public static const CHANEL_STATE_SINGLE_SHEET:int=1; 
		public static const CHANEL_STATE_DOUBLE_SHEET:int=2; 
		public static const CHANEL_STATE_REAM_EMPTY:int=3; 
		public static const CHANEL_STATE_REAM_FILLED:int=4; 

		public static const REAM_STATE_UNKNOWN:int=0; 
		public static const REAM_STATE_EMPTY:int=10; 
		public static const REAM_STATE_COUNTDOWN:int=50; 
		public static const REAM_STATE_FILLED:int=100; 
		
		
		public static const MSG_CONTROLLER_ALERT_PREFIX:String='*al'; //
		public static const MSG_CONTROLLER_ERROR_PREFIX:String='err';//err1+0x0d

		public static const MAX_RESEND:int=1;
		public static const ACKNOWLEDGE_TIMEOUT:int	=200;
		
		private static var chanelStateNameMap:Object;
		public static function chanelStateName(state:int):String{
			if(!chanelStateNameMap){
				chanelStateNameMap=new Object;
				chanelStateNameMap[CHANEL_STATE_SHEET_PASS]='Лист вышел';
				chanelStateNameMap[CHANEL_STATE_SINGLE_SHEET]='Одинарный лист';
				chanelStateNameMap[CHANEL_STATE_DOUBLE_SHEET]='Двойной лист';
				chanelStateNameMap[CHANEL_STATE_REAM_EMPTY]='Пустая стопа';
				chanelStateNameMap[CHANEL_STATE_REAM_FILLED]='Стопа заполнена';
			}
			var res:String=chanelStateNameMap[state];
			if(!res) res='State#'+state.toString();
			return res;
		}
		
		
		public var logger:ISimpleLogger;

		public var tray:int=-1;
		
		private var _isBusy:Boolean;
		public function get isBusy():Boolean{
			return _isBusy;
		}
		
		private var _feederEmpty:Boolean=false;
		public function get reamEmpty():Boolean{
			return _feederEmpty;
		}
		
		private var lastCommand:String;
		private var resendCount:int=0;

		public function FeederController(){
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
			if(msg==MSG_REAM_EMPTY_OLD){
				log('Датчик стопы (старая версия)');
				return;
			}
			
			//check message
			var chanelState:int=-1;
			switch(msg){
				case MSG_SHEET_PASS:{
					chanelState=CHANEL_STATE_SHEET_PASS;
					break;
				}
				case MSG_SINGLE_SHEET:{
					chanelState=CHANEL_STATE_SINGLE_SHEET;
					break;
				}
				case MSG_DOUBLE_SHEET:{
					chanelState=CHANEL_STATE_DOUBLE_SHEET;
					break;
				}
				case MSG_REAM_EMPTY:{
					chanelState=CHANEL_STATE_REAM_EMPTY;
					_feederEmpty=true;
					break;
				}
				case MSG_REAM_FILLED:{
					chanelState=CHANEL_STATE_REAM_FILLED;
					_feederEmpty=false;
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
			dispatchEvent(new ControllerMesageEvent(tray,chanelState));
		}
		
		override public function set comPort(value:Socket2Com):void{
			super.comPort = value;
			if(value) tray=value.tray-1; //zero based
		}
		
		
		protected function log(msg:String):void{
			if(logger) logger.log(msg.replace(String.fromCharCode(sufix), "'hex:"+sufix.toString(16)+"'"));
		}

		private var aclTimer:Timer;
		
		protected function sendCmd(cmd:String, ignoreACL:Boolean=false):void{
			if(!cmd) return;
			if(!ignoreACL && _isBusy){
				log('! Busy error; command: '+cmd);
				dispatchEvent(new ErrorEvent(ErrorEvent.ERROR,false,false,'Нет потверждения предидущей команды ('+lastCommand+'/'+cmd+')',ERROR_BUSY));
				return;
			}
			log('> '+cmd);
			var msg:String=cmd+String.fromCharCode(sufix);
			if(!ignoreACL){
				_isBusy=true;
				resendCount=0;
				lastCommand=msg;
				if(!aclTimer){
					aclTimer= new Timer(ACKNOWLEDGE_TIMEOUT,1);
					aclTimer.addEventListener(TimerEvent.TIMER, onAclTimer);
				}
				aclTimer.start();
			}
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
			sendCmd(COMMAND_POWER_ON);
		}
		public function engineOff():void{
			if(!isStarted) return;
			sendCmd(COMMAND_POWER_OFF);
		}
		
		public function vacuumOn():void{
			if(!isStarted) return;
			sendCmd(COMMAND_COMPRESSOR_ON);
		}
		public function vacuumOff():void{
			if(!isStarted) return;
			sendCmd(COMMAND_COMPRESSOR_OFF);
		}

		public function feed():void{
			if(!isStarted) return;
			sendCmd(COMMAND_FEED);
		}

		public function checkReam():void{
			if(!isStarted) return;
			sendCmd(COMMAND_CHECK_REAM_EMPTY, true);
		}

	}
}