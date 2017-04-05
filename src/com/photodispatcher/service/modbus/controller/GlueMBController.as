package com.photodispatcher.service.modbus.controller{
	import com.photodispatcher.event.ControllerMesageEvent;
	import com.photodispatcher.service.modbus.ModbusClient;
	import com.photodispatcher.service.modbus.ModbusRequestEvent;
	import com.photodispatcher.service.modbus.ModbusResponseEvent;
	import com.photodispatcher.service.modbus.ModbusServer;
	import com.photodispatcher.service.modbus.data.ModbusADU;
	import com.photodispatcher.service.modbus.data.ModbusBytes;
	import com.photodispatcher.service.modbus.data.ModbusPDU;
	
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.TimerEvent;
	import flash.utils.Timer;
	
	[Event(name="connectChange", type="flash.events.Event")]
	[Event(name="error", type="flash.events.ErrorEvent")]
	[Event(name="complete", type="flash.events.Event")]
	[Event(name="controllerMesage", type="com.photodispatcher.event.ControllerMesageEvent")]
	public class GlueMBController extends MBController{
		/*
		ПЛК -> ПК
		Регистр  0:
		0 - датчик на изгибе пришел сигнал
		1 - лист склеился (датчик на задней плите)
		2 - датчик на конвейере фронт
		3 - главная(передняя) плита, таймаут выхода вперед на датчик задней плиты
		4 - главная(передняя) плита, таймаут выхода назад на датчик исходного положения
		5 - таймаут датчика на выгрузке (видимо чтото застряло и перекрыло датчик)
		6 - резерв датчик уровня клея
		7 - резерв
		
		ПК -> ПЛК (6ая функция - запись регистра)
		D0 (адрес регистра 0x0000) Main_Plate_Forward_Timeout_Time - время таймаута при переходе передней плиты на датчик задней плиты (формат записи BCD (пример 0x0010 = 1 
		секунда(10*100мс))) 
		D1 (адрес регистра 0x0001) Main_Plate_Reverse_Timeout_Time - время таймаута при переходе передней плиты в исходное (формат записи BCD)
		D2 (адрес регистра 0x0002) Unload_Timeout_Time - таймаут датчика на выгрузке (формат записи BCD)
		D3 (адрес регистра 0x0003) Final_paper_D - следующий лист будет последним ( 0x0001 - true, сброс в 0x0000 - автоматически)
		D4 (адрес регистра 0x0003) Ignore_Errors - игнорирование  ошибок ( 0x0001 - true, 0x0000 - false). При изменении состояния необходима перезагрузка.
		
		D5 (адрес регистра 0x0005) Side_Stop_Off_delay - Таймер выключения боковых упоров (формат записи BCD)
		D6 (адрес регистра 0x0006) Side_Stop_On_delay - Таймер включения боковых упоров (формат записи BCD)
		
		D7 (адрес регистра 0x0007) Pump_Sens_Filter - Время ожидания "чистого" сигнала (фильтр) (формат записи BCD, 1 = 100ms). По-умолчанию 1 секунда (0x0010)
		D8 (адрес регистра 0x0008) Pump_Work_Time - Время работы насоса (формат записи BCD, 1 = 100ms). По-умолчанию 10 секунд (0x0100)
		D9 (адрес регистра 0x0009) Pump_Enable - включение/выключение регулирования уровня клея насосом. ( 0x0001 - true, 0x0000 - false)
		*/
		public static const CONTROLLER_PRESS_PAPER_IN:int	=0;
		public static const CONTROLLER_PRESS_DONE:int	=1;
		public static const CONTROLLER_PAPER_SENSOR:int	=2;
		public static const CONTROLLER_PRESS_PUSH_TIMEOUT:int	=3;
		public static const CONTROLLER_PRESS_PULL_TIMEOUT:int	=4;
		public static const CONTROLLER_PUSH_TIMEOUT:int	=5;

		public static const CONTROLLER_REGISTER_MAIN_PLATE_FORWARD_TIMEOUT:int	=0;
		public static const CONTROLLER_REGISTER_MAIN_PLATE_REVERSE_TIMEOUT:int	=1;
		public static const CONTROLLER_REGISTER_UNLOAD_TIMEOUT:int				=2;
		public static const CONTROLLER_REGISTER_FINAL_PAPER:int					=3;
		public static const CONTROLLER_REGISTER_IGNORE_ERRORS:int				=4;
		public static const CONTROLLER_REGISTER_SIDE_STOP_OFF_DELAY:int			=5;
		public static const CONTROLLER_REGISTER_SIDE_STOP_ON_DELAY:int			=6;

		public static const CONTROLLER_REGISTER_PUMP_SENS_FILTER:int			=7;
		public static const CONTROLLER_REGISTER_PUMP_WORK_TIME:int				=8;
		public static const CONTROLLER_REGISTER_PUMP_ENABLE:int					=9;
		
		public function GlueMBController(){
			super();
		}
		
		public var timeoutMainPlateForward:int;
		public var timeoutMainPlateRevers:int;
		public var timeoutUnload:int;
		public var sideStopOffDelay:int=0;
		public var sideStopOnDelay:int=0;

		public var pumpSensFilterTime:int;
		public var pumpWorkTime:int;
		public var pumpEnable:Boolean;

		//Main_Plate_Forward_Timeout_Time
		public function setMainPlateForwardTimeout(msec:int):void{
			if(client && client.connected){
				client.writeRegister(CONTROLLER_REGISTER_MAIN_PLATE_FORWARD_TIMEOUT, ModbusBytes.int2bcd(int(msec/10)));
			}else{
				logErr('Контроллер не подключен');
			}
		}

		//Main_Plate_Revers_Timeout_Time
		public function setMainPlateReversTimeout(msec:int):void{
			if(client && client.connected){
				client.writeRegister(CONTROLLER_REGISTER_MAIN_PLATE_REVERSE_TIMEOUT, ModbusBytes.int2bcd(int(msec/10)));
			}else{
				logErr('Контроллер не подключен');
			}
		}
		
		public function setUnloadTimeout(msec:int):void{
			if(client && client.connected){
				client.writeRegister(CONTROLLER_REGISTER_UNLOAD_TIMEOUT, ModbusBytes.int2bcd(int(msec/10)));
			}else{
				logErr('Контроллер не подключен');
			}
		}

		public function setSideStopOffDelay(msec:int):void{
			if(client && client.connected){
				client.writeRegister(CONTROLLER_REGISTER_SIDE_STOP_OFF_DELAY, ModbusBytes.int2bcd(int(msec/10)));
			}else{
				logErr('Контроллер не подключен');
			}
		}

		public function setSideStopOnDelay(msec:int):void{
			if(client && client.connected){
				client.writeRegister(CONTROLLER_REGISTER_SIDE_STOP_ON_DELAY, ModbusBytes.int2bcd(int(msec/10)));
			}else{
				logErr('Контроллер не подключен');
			}
		}
		
		public function readSideStopDelays():void{
			if(client && client.connected){
				logMsg('Считывание таймеров боковых упоров');
				waiteCmd=CONTROLLER_REGISTER_SIDE_STOP_OFF_DELAY;
				client.readHoldingRegisters(CONTROLLER_REGISTER_SIDE_STOP_OFF_DELAY,2);
			}else{
				logErr('Контроллер не подключен');
			}
		}

		public function setPumpSensFilterTime(sec:int):void{
			if(client && client.connected){
				client.writeRegister(CONTROLLER_REGISTER_PUMP_SENS_FILTER, ModbusBytes.int2bcd(int(sec/100)));
			}else{
				logErr('Контроллер не подключен');
			}
		}
		public function setPumpWorkTime(sec:int):void{
			if(client && client.connected){
				client.writeRegister(CONTROLLER_REGISTER_PUMP_WORK_TIME, ModbusBytes.int2bcd(int(sec/100)));
			}else{
				logErr('Контроллер не подключен');
			}
		}
		public function setPumpEnable(state:Boolean):void{
			if(client && client.connected){
				var val:int=0;
				if(state) val=1;
				client.writeRegister(CONTROLLER_REGISTER_PUMP_ENABLE, val);
			}else{
				logErr('Контроллер не подключен');
			}
		}

		
		public function pushBlock():void{
			//write Final_paper_D
			if(client && client.connected){
				client.writeRegister(CONTROLLER_REGISTER_FINAL_PAPER,1);
			}else{
				logErr('Контроллер не подключен');
			}
		}
		
		
		override protected function onClientConnect(evt:Event):void{
			dispatchEvent(new Event('connectChange'));
			if(client && client.connected){
				//if(timeoutMainPlateForward>0) setMainPlateForwardTimeout(timeoutMainPlateForward);
				//if(timeoutMainPlateRevers>0) setMainPlateReversTimeout(timeoutMainPlateRevers);
				//if(timeoutUnload>0) setUnloadTimeout(timeoutUnload);
				if(sideStopOffDelay>10) setSideStopOffDelay(sideStopOffDelay);
				if(sideStopOnDelay>10) setSideStopOnDelay(sideStopOnDelay);
				if(pumpSensFilterTime>0) setPumpSensFilterTime(pumpSensFilterTime);
				if(pumpWorkTime>0) setPumpWorkTime(pumpWorkTime);
				setPumpEnable(pumpEnable);
				/*
				var timer:Timer= new Timer(1500,1);
				timer.addEventListener(TimerEvent.TIMER,onClientConnectTimer);
				timer.start();
				*/
			}
		}
		/*
		private function onClientConnectTimer(evt:TimerEvent):void{
			var timer:Timer=evt.target as Timer;
			if(timer) timer.removeEventListener(TimerEvent.TIMER,onClientConnectTimer);
			readSideStopDelays();
		}
		*/
		
		override protected function onServerADU(evt:ModbusRequestEvent):void{
			//msg from controller
			super.onServerADU(evt);
			var txt:String;
			var adu:ModbusADU=evt.adu;

			if(!adu) return;

			txt='';
			//check adr
			if(adu.pdu.address!=0){
				logMsg('wrong register address ' +adu.pdu.address);
				return;
			}
			switch(adu.pdu.value){
				case CONTROLLER_PRESS_PAPER_IN:{
					//notify handler
					dispatchEvent(new ControllerMesageEvent(0,0));
					txt='Подача листа на пресс';
					break;
				}
				case CONTROLLER_PRESS_DONE:{
					txt='Лист склеен';
					break;
				}
				case CONTROLLER_PAPER_SENSOR:{
					txt='Датчик листа конвейера';
					break;
				}
				case CONTROLLER_PRESS_PUSH_TIMEOUT:{
					logErr('Таймаут нажатия пресса');
					break;
				}
				case CONTROLLER_PRESS_PULL_TIMEOUT:{
					logErr('Таймаут отжатия пресса');
					break;
				}
				case CONTROLLER_PUSH_TIMEOUT:{
					logErr('Таймаут выхода блока');
					break;
				}
					
				default:{
					txt='Неизвестный код сообщения '+adu.pdu.value;
					break;
				}
			}
			if(txt) logMsg(txt);
		}
		
		override protected function onClientADU(evt:ModbusResponseEvent):void{
			var adu:ModbusADU=evt.adu;
			if(waiteCmd==-1) return;
			var cmd:int=waiteCmd;
			waiteCmd=-1;
			if(cmd==CONTROLLER_REGISTER_SIDE_STOP_OFF_DELAY){
				if(adu && adu.pdu && adu.pdu.functionCode==ModbusPDU.FUNC_READ_HOLDING_REGISTERS){
					if(adu.pdu.hasValue(0)) logMsg('Значение. Таймер выключения боковых упоров: 0x'+adu.pdu.getValue(0).toString(16));
					if(adu.pdu.hasValue(1)) logMsg('Значение. Таймер включения боковых упоров: 0x'+adu.pdu.getValue(1).toString(16));
				}
				
			}
		}
		
		

	}
}