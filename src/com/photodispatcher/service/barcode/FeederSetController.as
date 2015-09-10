package com.photodispatcher.service.barcode{
	import com.photodispatcher.event.BarCodeEvent;
	import com.photodispatcher.event.ControllerMesageEvent;
	import com.photodispatcher.interfaces.ISimpleLogger;
	
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.TimerEvent;
	
	public class FeederSetController extends ValveController{
		/*uses set of FeederController to implement ValveController behavior
		*/
		
		public function FeederSetController(){
		}
		
		
		private var _controllers:Array=[];
		private var trayMap:Object=new Object();
		public function get controllers():Array{
			return _controllers;
		}
		public function set controllers(value:Array):void{
			//stop listen
			if(_controllers){
				for each(fc in _controllers){
					fc.removeEventListener(ErrorEvent.ERROR, onControllerErr);
					fc.removeEventListener(BarCodeEvent.BARCODE_DISCONNECTED, onControllerDisconnect);
					fc.removeEventListener(Event.COMPLETE, onControllerCommandComplite);
					fc.removeEventListener(ControllerMesageEvent.CONTROLLER_MESAGE_EVENT,onControllerMsg);
				}
			}
			_controllers=[];
			trayMap=new Object();
			if(value){
				var fc:FeederController;
				for each(fc in value){
					if(fc && fc.tray>0){
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

		protected var currTray:int=0;
		
		protected function onControllerErr(event:ErrorEvent):void{
			if(currTray!=0){
				var fc:FeederController=event.target as FeederController;
				if(fc && fc.tray==currTray) currTray=0;
			}
			dispatchEvent(event);
		}

		protected function onControllerDisconnect(event:BarCodeEvent):void{
			dispatchEvent(event);
		}
		
		protected function onControllerCommandComplite(event:Event):void{
			var fc:FeederController=event.target as FeederController;
			if(currTray==-1){
				//waite all
				var fc:FeederController;
				var done:Boolean=true;
				for each(fc in controllers){
					if(fc.isBusy){
						done=false;
						break;
					}
				}
				if(done){
					currTray=0;
					dispatchEvent(new Event(Event.COMPLETE));
				}
			}else if(fc && fc.tray==currTray){
				currTray=0;
				dispatchEvent(new Event(Event.COMPLETE));
			}
		}

		protected function onControllerMsg(event:ControllerMesageEvent):void{
			//redispatch
			dispatchEvent(event);
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
			currTray=-1;
			var fc:FeederController;
			for each(fc in controllers) fc.engineOff();
		}
		
		override public function engineOn():void{
			//waite all
			currTray=-1;
			var fc:FeederController;
			for each(fc in controllers) fc.engineOn();
		}

		override public function vacuumOff():void{
			//waite all
			currTray=-1;
			var fc:FeederController;
			for each(fc in controllers) fc.vacuumOff();
		}
		
		override public function vacuumOn():void{
			//waite all
			currTray=-1;
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
			var tray:int=valve+1;
			var fc:FeederController=trayMap[tray] as FeederController;
			if(!fc){
				dispatchEvent(new ErrorEvent(ErrorEvent.ERROR,false,false,'Не настроен контроллер для лотка '+tray.toString(),ERROR_CONTROLLER_ERROR));
				return;
			}
			if(!fc.connected){
				dispatchEvent(new ErrorEvent(ErrorEvent.ERROR,false,false,'Контроллер '+fc.comCaption+' не подключен, лоток '+tray.toString(),ERROR_CONTROLLER_ERROR));
				return;
			}
			currTray=tray;
			fc.feed();
		}
		
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
			// TODO Auto Generated method stub
			//super.destroyCom();
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