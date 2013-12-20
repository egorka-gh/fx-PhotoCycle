package com.photodispatcher.service.barcode{
	import com.photodispatcher.event.ControllerMesageEvent;
	
	import flash.events.Event;
	import flash.events.TimerEvent;
	import flash.utils.Timer;

	public class ValveControllerEmulator extends ValveController{
		
		public var pickerInterval:int=5000;
		
		public function ValveControllerEmulator(){
			super();
		}
		
		private var _isBusy:Boolean;
		override public function get isBusy():Boolean{
			return _isBusy;
		}
		
		private var currValve:int=-1;;
		override public function open(valve:int):void{
			currValve=valve;
			log('<'+COMMAND_VALVE_PREFIX+currValve.toString(10)+COMMAND_STATE_SEPARATOR+'0');
			emulateACL();
			emulateOpen();
		}
		override public function close(valve:int):void		{
			log('<'+COMMAND_VALVE_PREFIX+valve.toString(10)+COMMAND_STATE_SEPARATOR+'1');
			currValve=-1;
			emulateACL();
		}
		
		override public function closeAll():void{
		}
		
		
		private var aclTimer:Timer;
		private function emulateACL():void{
			_isBusy=true;
			if(!aclTimer){
				aclTimer=new Timer(ValveController.ACKNOWLEDGE_TIMEOUT,1);
				aclTimer.addEventListener(TimerEvent.TIMER, onACLTimer);
			}
			aclTimer.start();
		}
		private function onACLTimer(e:TimerEvent):void{
			_isBusy=false;
			log('>'+MSG_CONTROLLER_ACKNOWLEDGE);
			dispatchEvent(new Event(Event.COMPLETE));
		}

		private var openTimer:Timer;
		private function emulateOpen():void{
			if(!openTimer){
				openTimer=new Timer(Math.round(pickerInterval*2/3),1);
				openTimer.addEventListener(TimerEvent.TIMER, onOpenTimer);
			}
			openTimer.start();
		}
		private function onOpenTimer(e:TimerEvent):void{
			log('>'+MSG_CONTROLLER_SENSOR_PREFIXF+'0=1');
			dispatchEvent(new ControllerMesageEvent(0,1));
			emulateSheet();
		}

		private var sheetTimer:Timer;
		private function emulateSheet():void{
			if(!sheetTimer){
				sheetTimer=new Timer(300,1);
				sheetTimer.addEventListener(TimerEvent.TIMER, onSheetTimer);
			}
			sheetTimer.start();
		}
		private function onSheetTimer(e:TimerEvent):void{
			log('>'+MSG_CONTROLLER_SENSOR_PREFIXF+'0=0');
			dispatchEvent(new ControllerMesageEvent(0,0));
		}
		
		override public function get connected():Boolean{
			return true;
		}
		
		override public function get isStarted():Boolean{
			return started;
		}
		
		private var started:Boolean;
		override public function start(comPort:Socket2Com=null):void{
			started= true;
		}
		
		override public function stop():void{
			started= false;
			_isBusy=false;
			if(aclTimer){
				aclTimer.reset();
				aclTimer.removeEventListener(TimerEvent.TIMER, onACLTimer);
				aclTimer=null;
			}
			if(openTimer){
				openTimer.reset();
				openTimer.removeEventListener(TimerEvent.TIMER, onOpenTimer);
				openTimer=null;
			}
			if(sheetTimer){
				sheetTimer.reset();
				sheetTimer.removeEventListener(TimerEvent.TIMER, onSheetTimer);
				sheetTimer=null;
			}
		}
		
		
	}
}