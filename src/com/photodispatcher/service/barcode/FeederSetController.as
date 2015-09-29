package com.photodispatcher.service.barcode{
	import com.photodispatcher.event.BarCodeEvent;
	import com.photodispatcher.event.ControllerMesageEvent;
	import com.photodispatcher.interfaces.ISimpleLogger;
	
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.TimerEvent;
	import flash.utils.Timer;
	
	public class FeederSetController extends ValveController{
		/*uses set of FeederController to implement ValveController behavior
		*/
		
		protected static const TRAY_ALL:int=-1;
		protected static const TRAY_NONE:int=-100;

		
		public function FeederSetController(){
		}
		
		
		private var _controllers:Array=[];
		private var trayMap:Object=new Object();
		public function get controllers():Array{
			return _controllers;
		}
		public function set controllers(value:Array):void{
			var fc:FeederController;
			//stop listen
			if(_controllers){
				for each(fc in _controllers){
					fc.logger=null;
					fc.removeEventListener(ErrorEvent.ERROR, onControllerErr);
					fc.removeEventListener(BarCodeEvent.BARCODE_DISCONNECTED, onControllerDisconnect);
					fc.removeEventListener(Event.COMPLETE, onControllerCommandComplite);
					fc.removeEventListener(ControllerMesageEvent.CONTROLLER_MESAGE_EVENT,onControllerMsg);
				}
			}
			_controllers=[];
			trayMap=new Object();
			if(value){
				for each(fc in value){
					if(fc && fc.tray>=0){
						fc.logger=logger;
						_controllers.push(fc);
						trayMap[fc.tray]=fc;
						//start listen
						fc.addEventListener(ErrorEvent.ERROR, onControllerErr);
						fc.addEventListener(BarCodeEvent.BARCODE_DISCONNECTED, onControllerDisconnect);
						fc.addEventListener(Event.COMPLETE, onControllerCommandComplite);
						fc.addEventListener(ControllerMesageEvent.CONTROLLER_MESAGE_EVENT,onControllerMsg);
					}
				}
			}
		}

		protected var currTray:int=TRAY_NONE;
		
		protected function onControllerErr(event:ErrorEvent):void{
			if(currTray==TRAY_NONE) return;
			currTray=TRAY_NONE;
			dispatchEvent(new ErrorEvent(event.type,false,false,event.text, event.errorID));
		}

		protected function onControllerDisconnect(event:BarCodeEvent):void{
			var evt:BarCodeEvent= new BarCodeEvent(event.type,event.barcode,event.error);
			dispatchEvent(evt);
		}
		
		protected function onControllerCommandComplite(event:Event):void{
			var fc:FeederController=event.target as FeederController;
			if(fc) log('<лоток'+(fc.tray+1).toString()+' acl');
			if(currTray==TRAY_NONE) return;
			if(currTray==TRAY_ALL){
				//waite all
				var done:Boolean=true;
				for each(fc in controllers){
					if(fc.isBusy){
						done=false;
						break;
					}
				}
				if(done){
					currTray=TRAY_NONE;
					dispatchEvent(new Event(Event.COMPLETE));
				}
			}else if(fc && fc.tray==currTray){
				currTray=TRAY_NONE;
				dispatchEvent(new Event(Event.COMPLETE));
			}else{
				dispatchEvent(new ErrorEvent(ErrorEvent.ERROR,false,false,'Wrong tray ACL'));
			}
		}

		protected function onControllerMsg(event:ControllerMesageEvent):void{
			/*
			if(event.state==FeederController.CHANEL_STATE_SINGLE_SHEET 
				|| event.state==FeederController.CHANEL_STATE_DOUBLE_SHEET 
				|| event.state==FeederController.CHANEL_STATE_SHEET_PASS){
				//stop refeed timer
				if(feedTimer) feedTimer.reset();
			}
			*/
			//redispatch
			log('<лоток '+ (event.chanel+1).toString()+' ' + FeederController.chanelStateName(event.state));
			var evt:ControllerMesageEvent= new ControllerMesageEvent(event.chanel,event.state);
			dispatchEvent(evt);
		}
		
		override public function get logger():ISimpleLogger{
			return super.logger;
		}
		
		override public function set logger(value:ISimpleLogger):void{
			super.logger = value;
			var fc:FeederController;
			for each(fc in controllers) fc.logger=value;
		}
		
		
		override public function close(valve:int):void{
			// do nothing
			dispatchEvent(new Event(Event.COMPLETE));
		}
		
		override public function closeAll():void{
			// do nothing
			dispatchEvent(new Event(Event.COMPLETE));
		}
		
		override public function engineOff():void{
			//waite all
			log('мотор off');
			currTray=TRAY_ALL;
			var fc:FeederController;
			for each(fc in controllers) fc.engineOff();
		}
		
		override public function engineOn():void{
			//waite all
			log('мотор on');
			currTray=TRAY_ALL;
			var fc:FeederController;
			for each(fc in controllers) fc.engineOn();
		}

		override public function vacuumOff():void{
			//waite all
			log('компрессор off');
			currTray=TRAY_ALL;
			var fc:FeederController;
			for each(fc in controllers) fc.vacuumOff();
		}
		
		override public function vacuumOn():void{
			//waite all
			log('компрессор on');
			currTray=TRAY_ALL;
			var fc:FeederController;
			for each(fc in controllers) fc.vacuumOn();
		}
		
		override public function get isBusy():Boolean{
			//serial behavior
			var fc:FeederController;
			for each(fc in controllers){
				if(fc.isBusy) return true;
			}
			return false;
		}
		
		override public function open(valve:int):void{
			//get controller
			var tray:int=valve;
			var fc:FeederController=trayMap[tray] as FeederController;
			if(!fc){
				dispatchEvent(new ErrorEvent(ErrorEvent.ERROR,false,false,'Не настроен контроллер для лотка '+tray.toString(),ERROR_CONTROLLER_ERROR));
				return;
			}
			if(!fc.connected){
				dispatchEvent(new ErrorEvent(ErrorEvent.ERROR,false,false,'Контроллер '+fc.comCaption+' не подключен, лоток '+tray.toString(),ERROR_CONTROLLER_ERROR));
				return;
			}
			log('>открыть лоток'+(tray+1).toString()+'('+(fc.tray+1).toString()+')');
			currTray=tray;
			fc.feed();
			//startFeedTimer();
		}
		
		/*
		private var _turnInterval:int=300;
		public function get turnInterval():int{
			return _turnInterval;
		}
		public function set turnInterval(value:int):void{
			if(value<300) value=300;
			_turnInterval = value;
			if(feedTimer) feedTimer.delay=_turnInterval;
		}

		private var feedTimer:Timer;
		
		protected function startFeedTimer():void{
			if(turnInterval<300) return;
			
			if(!feedTimer){
				feedTimer= new Timer(turnInterval,1);
				feedTimer.addEventListener(TimerEvent.TIMER, onFeedDelayTimer);
			}
			feedTimer.start();
		}
		private function onFeedDelayTimer(evt:TimerEvent):void{
			//try to reopen tray
			if(currTray<0) return;
			var fc:FeederController=trayMap[currTray] as FeederController;
			if(!fc || !fc.connected) return;
			log('Лоток '+(currTray+1).toString()+' повторная подача листа.');
			fc.feed();
		}
		*/

		
		override public function send(msg:String):void{
			// do nothing
		}
		
		override public function get connected():Boolean{
			if(!controllers || controllers.length==0) return false;
			var res:Boolean=false;
			if(controllers){
				var fc:FeederController;
				for each(fc in controllers){
					if(!fc.connected) return false;
				}
			}
			return true;
		}

		override public function get isStarted():Boolean{
			if(!controllers || controllers.length==0) return false;
			var res:Boolean=false;
			if(controllers){
				var fc:FeederController;
				for each(fc in controllers){
					if(!fc.isStarted) return false;
				}
			}
			return true;
		}
		
		
		override protected function destroyCom():void{
			controllers=null;
			logger=null;
		}
		
		override public function get lastCode():String{
			return '';
		}
		
		override public function start(comPort:Socket2Com=null):void{
			if(controllers){
				var fc:FeederController;
				for each(fc in controllers){
					if(fc) fc.start();
				}
			}
		}
		
		override public function stop():void{
			if(controllers){
				var fc:FeederController;
				for each(fc in controllers){
					if(fc) fc.stop();
				}
			}
			controllers=[];
		}
		
		
	}
}