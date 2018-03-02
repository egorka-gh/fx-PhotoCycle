package com.photodispatcher.tech{
	import com.photodispatcher.event.ControllerMesageEvent;
	import com.photodispatcher.interfaces.ISimpleLogger;
	import com.photodispatcher.service.barcode.FeederController;
	import com.photodispatcher.service.barcode.SerialProxy;
	import com.photodispatcher.service.modbus.controller.GlueMBController;
	import com.photodispatcher.tech.register.TechBook;
	
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.TimerEvent;
	import flash.utils.Timer;
	import flash.utils.getTimer;
	
	import mx.collections.ArrayCollection;
	import mx.controls.Alert;
	
	[Event(name="error", type="flash.events.ErrorEvent")]
	[Event(name="complete", type="flash.events.Event")]
	[Event(name="controllerMesage", type="com.photodispatcher.event.ControllerMesageEvent")]
	public class GlueHandlerMB extends GlueHandler{

		
		public function GlueHandlerMB(){
			super();
		}
		
		public var serverIP:String='';
		public var serverPort:int=503;
		public var clientIP:String='';
		public var clientPort:int=502;
		
		public var glueSideStopOffDelay:int=0;
		public var glueSideStopOnDelay:int=0;
		
		public var pumpSensFilterTime:int=0;
		public var pumpWorkTime:int=0;
		public var pumpEnable:Boolean=false;

		public var whitePaperDelay:int=0;
		public var bookEjectionDelay:int=0;
		public var finalSqueezingTime:int=0;


		private var _controller:GlueMBController;
		[Bindable]
		public function get controller():GlueMBController{
			return _controller;
		}
		public function set controller(value:GlueMBController):void{
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

		override protected function onControllerErr(event:ErrorEvent):void{
			if(event.errorID!=0){
				pauseRequest('Ошибка контролера: '+event.text);
			}else{
				log(event.text,2);
			}
		}

		
		override public function init(serialProxy:SerialProxy):void{
			if(!serverIP || !serverPort || !clientIP || !clientPort){
				controller=null;
				return;
			}
			if(controller && controller.connected){
				controller.stop();
			}else{
				controller= new GlueMBController();
			}
			controller.serverIP=serverIP;
			controller.serverPort=serverPort;
			controller.clientIP=clientIP;
			controller.clientPort=clientPort;
			controller.hasFeeder=hasFeeder;
			controller.sideStopOffDelay=glueSideStopOffDelay;
			controller.sideStopOnDelay=glueSideStopOnDelay;
			
			controller.whitePaperDelay=whitePaperDelay;
			controller.bookEjectionDelay=bookEjectionDelay;
			controller.finalSqueezingTime=finalSqueezingTime;


			controller.pumpSensFilterTime=pumpSensFilterTime;
			controller.pumpWorkTime=pumpWorkTime;
			controller.pumpEnable=pumpEnable;

			controller.start();
		}
		
		override protected function checkPrepared(alert:Boolean=false):Boolean{
			var prepared:Boolean= controller && controller.serverStarted;
			if(!prepared && alert){
				//Alert.show('Не инициализирован контролер склейки');
				log('Не инициализирован контролер склейки');
			}
			return 	prepared;
		}
		
		override public function start(startDelay:int=0):Boolean{
			if(isRunning) return true;
			if(!checkPrepared(true)) return false;
			log('Старт');
			log('Старт',2);
			log('Ожидаю подключение контролера',2);
			//reset state
			bookQueue=new ArrayCollection();
			stopBook=null;
			
			isRunning=true;
			hasPauseRequest=false;
			return true;
		}
		
		override public function reset():void{
			log('Сброс очереди склейки');
			//reset state
			bookQueue=new ArrayCollection();
			stopBook=null;
			hasPauseRequest=false;
		}
		
		override public function resume():void{
			if(!isRunning) return;
			hasPauseRequest=false;
			checkPrepared(true);
			//reset state
		}
		override public function stop(err:String='', engineStop:Boolean=false):void{
			if(!isRunning) return;
			isRunning=false;
			hasPauseRequest=false;
			if(controller && engineStop) controller.stop();
		}
		
		override public function removeBook():void{
			if(isRunning && !nonStopMode) return;
			if(isRunning){
				//var tb:TechBook=bookQueue.shift() as TechBook;
				var tb:TechBook;
				if(bookQueue.length>0) tb=bookQueue.removeItemAt(0) as TechBook;
				if(tb){
					log('Убираю книгу '+tb.printGroupId+' '+tb.book);
					//refresh view
					currentBook;
				}
			}
			var msg:String='Следующий лист последний ';
			if(tb) msg=msg+tb.printGroupId+' '+tb.book+' '+tb.sheetsDone+'/'+tb.sheetsTotal;
			log(msg);
			controller.pushBlock();
		}
		
		override protected function checkStopBook():Boolean{
			if(stopBook) stopBook=null; 
			return false;
		}
		
		//public var hasFeeder:Boolean=false;
		private var _feederEmpty:Boolean=false;
		override public function get reamEmpty():Boolean{
			return _feederEmpty;
		}
		override public function feederPower(on:Boolean):void{
			controller.feederPower(on);
		}
		override public function feederPump(on:Boolean):void{
			controller.feederPump(on);
		}
		override public function feederFeed():void{
			controller.feederFeed();
		}
		override public function feederGetReamState():void{
			controller.feederGetReamState();
		}
		
		private var lastMsgTime:uint=0;
		
		override protected function onControllerMsg(event:ControllerMesageEvent):void{
			if(!isRunning ) return;
			
			if(event.chanel == GlueMBController.CHANEL_CONTROLLER_MESSAGE){
				//event.state - message
				if(event.state==GlueMBController.CONTROLLER_PRESS_PAPER_IN){
					//CONTROLLER_PRESS_PAPER_IN message
					//check wrong sencor trigg
					if(repeatedSignalGap>0){
						var newTime:uint=getTimer();
						if((newTime-lastMsgTime) < repeatedSignalGap){
							log('Повторное срабатывание датчика');
							return;
						}
						lastMsgTime=newTime;
					}
					
					var tb:TechBook=currentBook;//refresh view
					
					if (checkStopBook()) return; //???
					//check sheet/book
					if(tb){
						tb.sheetsDone++;
						if(tb.sheetsDone>tb.sheetsFeeded){
							logErr('Ошибка контроля книги (подано меньше чем склеено) '+tb.printGroupId+' '+tb.book);
						}
						if(tb.sheetsDone==(tb.sheetsTotal-1)){
							log('Следующий лист последний '+tb.printGroupId+' '+tb.book+' '+tb.sheetsDone+'/'+tb.sheetsTotal);
							controller.pushBlock();
						}
						if(tb.sheetsDone==tb.sheetsTotal){
							//book complited
							//remove
							//tb=bookQueue.shift() as TechBook;
							tb=null;
							if(bookQueue.length>0) tb=bookQueue.removeItemAt(0) as TechBook;
							if(tb){
								log('Книга завершена '+tb.printGroupId+' '+tb.book);
								//refresh view
								currentBook;
							}
						}
					}else{
						logErr('Нет данных о текущей книге');
						return;
					}
				}
				if(!hasFeeder) return;
				var chanelState:int=-1;
				switch(event.state){
					//posible bug - GlueMBController && FeederController chanel_state colision
					case GlueMBController.CONTROLLER_NEW_SHEET_ERROR1:
						logErr('Пришел новый лист, но задняя плита не сошла с датчика исходного положения');
						break;
					case GlueMBController.CONTROLLER_NEW_SHEET_ERROR2:
						logErr('Пришел новый лист, но передняя плита не в исходном положении');
						break;
					case GlueMBController.FEEDER_ALARM_ON:
						logErr('Сработало Реле безопасности');
						break;
					case GlueMBController.FEEDER_ALARM_OFF:
						break;
					case GlueMBController.FEEDER_SHEET_IN:
						chanelState=FeederController.CHANEL_STATE_SINGLE_SHEET;
						break;
					case GlueMBController.FEEDER_SHEET_PASS:
						chanelState=FeederController.CHANEL_STATE_SHEET_PASS;
						break;
					case GlueMBController.FEEDER_REAM_FILLED:
						chanelState=FeederController.CHANEL_STATE_REAM_FILLED;
						_feederEmpty=false;
						break;
					case GlueMBController.FEEDER_REAM_EMPTY:
						chanelState=FeederController.CHANEL_STATE_REAM_EMPTY;
						_feederEmpty=true;
						break;
					case GlueMBController.GLUE_LEVEL_ALARM:
						chanelState=GlueMBController.GLUE_LEVEL_ALARM;
						break;
				}
				if(chanelState!=-1) dispatchEvent(new ControllerMesageEvent(0,chanelState));
				
			}if(event.chanel == GlueMBController.CHANEL_CONTROLLER_COMMAND_ACL){
				//command acl
				//event.state - command register
				if(!hasFeeder) return;
				switch(event.state){
					case GlueMBController.FEEDER_REGISTER_POWER_SWITCH:
					case GlueMBController.FEEDER_REGISTER_PUMP_SWITCH:
					case GlueMBController.FEEDER_REGISTER_PUSH_PAPER:
						dispatchEvent(new Event(Event.COMPLETE));
						break;
				}
				
			}
			
		}

		private function logErr(msg:String):void{
			dispatchEvent(new ErrorEvent(ErrorEvent.ERROR,false,false,msg));
		}

		override protected function pushBook():void{
		}
		
		
	}
}