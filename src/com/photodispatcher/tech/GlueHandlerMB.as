package com.photodispatcher.tech{
	import com.photodispatcher.event.ControllerMesageEvent;
	import com.photodispatcher.interfaces.ISimpleLogger;
	import com.photodispatcher.service.barcode.SerialProxy;
	import com.photodispatcher.service.modbus.controller.GlueMBController;
	import com.photodispatcher.tech.register.TechBook;
	
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.TimerEvent;
	import flash.utils.Timer;
	
	import mx.controls.Alert;
	
	[Event(name="error", type="flash.events.ErrorEvent")]
	public class GlueHandlerMB extends GlueHandler{

		
		public function GlueHandlerMB(){
			super();
		}
		
		public var serverIP:String='';
		public var serverPort:int=503;
		public var clientIP:String='';
		public var clientPort:int=502;
		
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
				log(event.text);
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
			log('Ожидаю подключение контролера');
			//reset state
			bookQueue=[];
			stopBook=null;
			
			isRunning=true;
			hasPauseRequest=false;
			return true;
		}

		
		override public function resume():void{
			if(!isRunning) return;
			hasPauseRequest=false;
			checkPrepared(true);
			//reset state
		}
		override public function stop(err:String=''):void{
			if(!isRunning) return;
			isRunning=false;
			hasPauseRequest=false;
			if(controller) controller.stop();
		}
		
		override public function removeBook():void{
			
		}
		
		override protected function checkStopBook():Boolean{
			if(stopBook) stopBook=null; 
			return false;
		}
		
		override protected function onControllerMsg(event:ControllerMesageEvent):void{
			if(!isRunning ) return;
			var tb:TechBook=currentBook;//refresh view
			
			if (checkStopBook()) return; //???
			//check sheet/book
			if(tb){
				tb.sheetsDone++;
				if(tb.sheetsDone>tb.sheetsFeeded){
					logErr('Ошибка контроля книги (подано<склеено) '+tb.printGroupId+' '+tb.book);
				}
				if(tb.sheetsDone==(tb.sheetsTotal-1)){
					log('Следующий лист последний '+tb.printGroupId+' '+tb.book+' '+tb.sheetsDone+'/'+tb.sheetsTotal);
					controller.pushBlock();
				}
				if(tb.sheetsDone==tb.sheetsTotal){
					//book complited
					//remove
					tb=bookQueue.shift() as TechBook;
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

		private function logErr(msg:String):void{
			dispatchEvent(new ErrorEvent(ErrorEvent.ERROR,false,false,msg));
		}

		override protected function pushBook():void{
		}
		
	}
}