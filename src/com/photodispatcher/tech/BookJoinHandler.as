package com.photodispatcher.tech{
	import com.photodispatcher.event.ControllerMesageEvent;
	import com.photodispatcher.interfaces.ISimpleLogger;
	import com.photodispatcher.service.modbus.controller.BookJoinMBController;
	import com.photodispatcher.service.modbus.controller.MBController;
	
	import flash.events.ErrorEvent;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	
	[Event(name="error", type="flash.events.ErrorEvent")]
	public class BookJoinHandler extends EventDispatcher{
		
		public function BookJoinHandler(){
			super(null);
		}
		
		public var serverIP:String='';
		public var serverPort:int=503;
		public var clientIP:String='';
		public var clientPort:int=502;
		
		public var logger:ISimpleLogger;

		[Bindable]
		public var isRunning:Boolean;

		private var _controller:BookJoinMBController;
		[Bindable]
		public function get controller():BookJoinMBController{
			return _controller;
		}
		public function set controller(value:BookJoinMBController):void{
			if(_controller){
				_controller.removeEventListener(ErrorEvent.ERROR, onControllerErr);
				_controller.removeEventListener(ControllerMesageEvent.CONTROLLER_MESAGE_EVENT,onControllerMsg);
				_controller.stop();
			}
			_controller = value;
			if(_controller){
				_controller.addEventListener(ErrorEvent.ERROR, onControllerErr);
				_controller.addEventListener(ControllerMesageEvent.CONTROLLER_MESAGE_EVENT,onControllerMsg);
			}
		}
		
		public function init():void{
			if(!serverIP || !serverPort || !clientIP || !clientPort){
				controller=null;
				return;
			}
			if(controller && controller.connected){
				controller.stop();
			}else{
				controller= new BookJoinMBController();
			}
			controller.serverIP=serverIP;
			controller.serverPort=serverPort;
			controller.clientIP=clientIP;
			controller.clientPort=clientPort;
			//TODO set other props
			/*
			controller.sideStopOffDelay=glueSideStopOffDelay;
			controller.sideStopOnDelay=glueSideStopOnDelay;
			*/
			controller.start();
		}
		
		protected function checkPrepared(alert:Boolean=false):Boolean{
			var prepared:Boolean= controller && controller.serverStarted;
			if(!prepared && alert){
				log('Не инициализирован контролер склейки');
			}
			return 	prepared;
		}
		
		public function start():Boolean{
			if(isRunning) return true;
			if(!checkPrepared(true)) return false;
			log('Старт');
			log('Ожидаю подключение контролера');
			//TODO reset state
			
			isRunning=true;
			
			return true;
		}
		
		public function stop():void{
			if(!isRunning) return;
			isRunning=false;
			if(controller) controller.stop();
		}

		protected function onControllerMsg(event:ControllerMesageEvent):void{
			if(!isRunning ) return;
			//if(event.chanel==MBController.MESSAGE_CHANEL_SERVER) return;
			if(event.chanel==MBController.MESSAGE_CHANEL_CLIENT){
				log('Котролер: положение рейки '+event.state.toString());
			}else{
				//MESSAGE_CHANEL_SERVER
				switch(event.state){
					case BookJoinMBController.CONTROLLER_FIND_REFERENCE_COMPLITE:
						log('Котролер: поиск исходной позиции выполнен');
						break;
					case BookJoinMBController.CONTROLLER_PAPER_SENSOR_IN:
						log('Котролер: блок пошел');
						break;
					case BookJoinMBController.CONTROLLER_PAPER_SENSOR_OUT:
						log('Котролер: блок вышел');
						break;
					case BookJoinMBController.CONTROLLER_GOTO_RELATIVE_POSITION_COMPLITE:
						log('Котролер: переход на позицию выполнен');
						break;
					case BookJoinMBController.CONTROLLER_ERR_HASNO_REFERENCE:
						logErr('Ошибка контролера: Не определена исходная позиция');
						break;
					case BookJoinMBController.CONTROLLER_ERR_GOTO_TIMEOUT:
						logErr('Ошибка контролера: Таймаут перехода на заданную позицию');
						break;
				}
			}
			//TODO implement
		}
		
		protected function onControllerErr(event:ErrorEvent):void{
			if(event.errorID!=0){
				logErr('Ошибка контролера: '+event.text);
			}else{
				log(event.text);
			}
		}

		
		protected function log(msg:String):void{
			if(logger) logger.log('Контролер. '+msg);
		}

		private function logErr(msg:String):void{
			dispatchEvent(new ErrorEvent(ErrorEvent.ERROR,false,false,msg));
		}

	}
}