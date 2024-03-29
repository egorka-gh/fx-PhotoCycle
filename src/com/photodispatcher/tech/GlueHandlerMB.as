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
		public var glueUnloadOffDelay:int=0;
		public var glueUnloadOnDelay:int=0;
		public var gluePlateReturnDelay:int=0;
		public var glueScraperDelay:int=0;
		public var glueScraperRun:int=0;
		public var glueFirstSheetDelay:int=0;

		public var glueSkipSheetDelay:int=0;

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
			controller.glueUnloadOffDelay=glueUnloadOffDelay;
			controller.glueUnloadOnDelay=glueUnloadOnDelay;
			controller.gluePlateReturnDelay=gluePlateReturnDelay;
			controller.glueScraperDelay=glueScraperDelay;
			controller.glueScraperRun=glueScraperRun;
			controller.glueFirstSheetDelay=glueFirstSheetDelay;

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
		
		override public function get isConnected():Boolean
		{
			return controller && controller.connected;
		}
		
		override public function start(startDelay:int=0):Boolean{
			if(isRunning) return true;
			errorMode=false;
			if(!checkPrepared(true)) return false;
			_feederEmpty=false;
			log('Старт');
			log('Старт',2);
			if(!controller.connected)
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
			errorMode=false;
			isRunning=false;
			hasPauseRequest=false;
			//has no stop command
			//if(controller && engineStop) controller.engineStop();
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
			var msg:String='Принудительный выброс блока ';
			if(tb) msg=msg+tb.printGroupId+' '+tb.book+' '+tb.sheetsDone+'/'+tb.sheetsTotal;
			log(msg);
			controller.pushBlock(); // .pushBlockAfterSheet();
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
		
		override public function await(printGroupId:String, book:int, sheet:int, sheetTotal:int, barcode:String=''):void{
			if(!isRunning ) return;
			super.awaitLast(printGroupId, book, sheet, sheetTotal, barcode);

			if (errorMode &&  bookQueue.length == 1){
				//limit sheets in glue while in errorMode 
				//works in fast mode only
				//check if not at the start or end of book
				if (sheet >2 || sheet < (sheetTotal-2)){
					var tb:TechBook = bookQueue.getItemAt(0) as TechBook;
					if ((tb.sheetsFeeded - tb.sheetsPushed) > 20  && (tb.sheetsDone - tb.sheetsPushed)>0 ){
						log('Выгрузка книги >20 листов в режиме ошибки');
						controller.pushBlockAfterSheet();
						tb.sheetsPushed = tb.sheetsFeeded;
					}
				}
			}
			
		}
		override public function awaitLast(printGroupId:String, book:int, sheet:int, sheetTotal:int, barcode:String=''):void{
			if(!isRunning ) return;
			
			//check/skip onesheet book
			if (allowSkipMode && sheetTotal==1){
				//only?? for fast glue vs minimal gap between sheets
				log('Пропуск книги '+book+'('+printGroupId+')');
				skipBook();
				//log('skipBook complited');
				return;
			}
			
			await(printGroupId, book, sheet, sheetTotal, barcode);
			var tb:TechBook;
			if(errorMode){
				tb=bookQueue.getItemAt(bookQueue.length-1) as TechBook;
				
				//book must have more then 1 sheet
				if ((tb.sheetsDone - tb.sheetsPushed)<1) return;

				tb.sheetsTotal = tb.sheetsFeeded;
				//only for fast glue vs minimal gap between sheets
				if(bookQueue.length==1){
					log('Следующий лист последний (awaitLast) '+tb.printGroupId+' '+tb.book+' '+tb.sheetsDone+'/'+tb.sheetsTotal);
					//tb.sheetsTotal = -1;
					controller.pushBlockAfterSheet();
				}
				errorMode=false;
			}
		}
		
		//private var skipTimer:Timer;
		//private var skipAlarmTimer:Timer;
		private function skipBook():void{
			//var tb:TechBook=bookQueue.shift() as TechBook;
			/*
			var tb:TechBook;
			if(bookQueue.length>0) tb=bookQueue.removeItemAt(0) as TechBook;
			if(!tb) return;
			log('Пропуск книги '+tb.printGroupId+' '+tb.book);
			*/
			
			if(glueSkipSheetDelay>50){
				var skipTimer:Timer=new Timer(glueSkipSheetDelay,1);
				skipTimer.addEventListener(TimerEvent.TIMER_COMPLETE, onSkipTimer);
				//log('skipBook timer start');
				skipTimer.start();
			}else{
				//log('skipBook call onSkipTimer');
				onSkipTimer(null);
			}
			if (showSkipAlarm){
				controller.setAlarmOn();
				var skipAlarmTimer:Timer=new Timer(1000,1);
				skipAlarmTimer.addEventListener(TimerEvent.TIMER_COMPLETE, onSkipAlarmTimer);
				skipAlarmTimer.start();
			}
		}
		private function onSkipTimer(e:TimerEvent):void{
			//log('skipBook run onSkipTimer');
			if(e){
				var skipTimer:Timer= e.target as Timer;
				if(skipTimer){
					skipTimer.removeEventListener(TimerEvent.TIMER_COMPLETE, onSkipTimer);
				}
			}
			if(!isRunning ) return;
			//log('skipBook controller.skipSheet');
			controller.skipSheet();
			//refresh view
			currentBook;
		}
		private function onSkipAlarmTimer(e:TimerEvent):void{
			if(e){
				var skipAlarmTimer:Timer= e.target as Timer;
				if(skipAlarmTimer){
					skipAlarmTimer.removeEventListener(TimerEvent.TIMER_COMPLETE, onSkipAlarmTimer);
				}
			}
			controller.setAlarmOff();
		}


		private var lastMsgTime:uint=0;
		
		override protected function onControllerMsg(event:ControllerMesageEvent):void{
			if(!isRunning ) return;
			
			//messages chanel
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
							//TODO в общем случае сбой произошел давно и не однократно
							//даже при плотной подаче должно пройти как минимум 2а белых листа в одной книге 
							//может >= (походу только для медленных конвейеров)
							errorMode=true;
							logErr('Ошибка контроля книги (подано меньше чем склеено) '+tb.printGroupId+' '+tb.book);
							//+1 что бы выкинуло книгу при скане последнего разворота иначе просто отлогит что книга готова
							//??
							if(errorMode) tb.sheetsFeeded = tb.sheetsDone+1;
						}
						if(tb.sheetsDone==(tb.sheetsTotal-1)){
							log('Следующий лист последний '+tb.printGroupId+' '+tb.book+' '+tb.sheetsDone+'/'+tb.sheetsTotal);
							controller.pushBlockAfterSheet();
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
								tb = currentBook;
								/*хреньы
								//возможно книга после errorMode (подано меньше чем склеено) или один разворот
								if(tb && tb.sheetsDone==(tb.sheetsTotal-1)){
									log('Следующий лист последний '+tb.printGroupId+' '+tb.book+' '+tb.sheetsDone+'/'+tb.sheetsTotal);
									controller.pushBlockAfterSheet();
								}
								*/
								/*never happens, i even don't awaite one sheet book
								//skip next one page book
								if (allowSkipMode && tb && tb.skipGlue){
										skipBook();
								}
								*/

							}
						}
					}else{
						errorMode=true;
						logErr('Нет данных о текущей книге');
						return;
					}
				}

				var chanelState:int=-1;
				//common messages
				switch(event.state){
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
						log('Реле безопасности сброшено',2);
						break;
					case GlueMBController.CONTROLLER_BOOK_OUT:
						chanelState=GlueMBController.CONTROLLER_BOOK_OUT;
						log('Склейка: Книга выгружена',2);
						break;
					case GlueMBController.GLUE_LEVEL_ALARM:
						chanelState=GlueMBController.GLUE_LEVEL_ALARM;
						log('Низкий уровень клея',2);
						break;
				}
				if(chanelState!=-1) dispatchEvent(new ControllerMesageEvent(0,chanelState));
				
				if(!hasFeeder) return;
				//Feeder messages
				chanelState=-1;
				switch(event.state){
					//posible bug - GlueMBController && FeederController chanel_state colision
					case GlueMBController.FEEDER_SHEET_IN:
						chanelState=FeederController.CHANEL_STATE_SINGLE_SHEET;
						log('Подача: Лист пошел',2);
						break;
					case GlueMBController.FEEDER_SHEET_PASS:
						chanelState=FeederController.CHANEL_STATE_SHEET_PASS;
						log('Подача: Лист вышел',2);
						break;
					case GlueMBController.FEEDER_REAM_FILLED:
						chanelState=FeederController.CHANEL_STATE_REAM_FILLED;
						_feederEmpty=false;
						log('Подача: Датчик стопы - заполнена',2);
						break;
					case GlueMBController.FEEDER_REAM_EMPTY:
						chanelState=FeederController.CHANEL_STATE_REAM_EMPTY;
						_feederEmpty=true;
						log('Подача: Датчик стопы - пустая',2);
						break;
				}
				if(chanelState!=-1) dispatchEvent(new ControllerMesageEvent(0,chanelState));
				
			}
			
			//command chanel
			if(event.chanel == GlueMBController.CHANEL_CONTROLLER_COMMAND_ACL){
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
		
		override public function destroy():void{
			controller=null;
		}
	}
}