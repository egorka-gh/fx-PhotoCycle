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
		//2018-01-22
		6 - Податчик. Высота стопы - появился сигнал
		7 - Податчик. Высота стопы - пропал сигнал
		8 - Податчик. Датчик листа - появился сигнал
		9 - Податчик. Датчик листа - пропал сигнал
		10 - Реле безопасности. Безопасность в режиме работы. Ошибок нет. Цикл работы машины запущен
		11 - Реле безопасности. Безопасность в ошибке. Машина остановлена. Необходимо сделать сброс реле безопасности (по физической кнопке) и заупстить цикл работы(по физической кнопке). Цикл остановлен
		12 - Пришел новый лист, но задняя плита не сошла с датчика исходного положения
		13 - Пришел новый лист, но передняя плита не в исходном положении
		14 - Авария насоса. Закончился клей для преедачи на компьютер
		//2018-05-14
		19 - датчик выгрузки книги (Книга выгружена)
		
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

		//2018-01-22
		D10(адрес регистра 0x000A) Safety_Time - время ожидания прихода листа для разрешения перемещения передней плиты (формат записи BCD, 1 = 100ms). По-умолчанию 20 (0x0200) = 2 секунды 
		D11(адрес регистра 0x000B) Feeder_Power_Switch_WORD - подача питания на податчик ( 0x0001 - включить, 0x0000 - выключить)
		D12(адрес регистра 0x000С) Feeder_Pump_Switch_WORD - подача питания на компрессор податчика ( 0x0001 - включить, 0x0000 - выключить)
		D13(адрес регистра 0x000D) Feeder_Pop_Paper_WORD - податчик. подать лист ( 0x0001 - пуск)
		D14(адрес регистра 0x000E) - Податчик. Высота стопы - 1 заполнен, 0 - пусто
		D15(адрес регистра 0x000F) White_paper_delay_time -  Время задержки после прихода сигнала на датчик "белого листа" (формат записи BCD, 1 = 10ms)
		D16(адрес регистра 0x0010) Book_ejection_delay_time - Время задержки перед открытием бункера (после прохода датчика "запрессовки" (экс датчик исх. положения задней плиты) (формат записи BCD, 1 = 10ms)
		D17(адрес регистра 0x0011) Final_squeezing_time - Время допрессовки  прижимной плитой после прохода датчика "запрессовки" (экс датчик исх. положения задней плиты) (формат записи BCD, 1 = 10ms)

		D18(адрес регистра 0x0012) Red_Lamp_Sound - ѕодача звукового сигнала + красна€ лампа. ћигание с периодом 1 секунда  ( 0x0001 - true, 0x0000 - false)
		D19(адрес регистра 0x0013) Unload_Off_delay Таймер выключения бункера выгрузки (формат записи BCD, 1 = 10ms) 
		D20(адрес регистра 0x0014) Unload_On_delay Таймер включения бункера выгрузки (формат записи BCD, 1 = 10ms)
		D21(адрес регистра 0x0015) Таймер дожимаплиты на последнем листе (формат записи BCD, 1 = 10ms)
		D22(адрес регистра 0x0016) Экстренный выброс блока (послать 1)
		
		//2018-12-27
		D30 (адрес регистра 0x001E) Scraper_hold_WORD - “аймер удержани€ сигнала "скребка" (формат записи BCD, 1 = 10ms)
		D29 (адрес регистра 0x001D) Scraper_delay_WORD - “аймер ожидани€ после ухода передней плиты назад на последнем листе перед включением "скребка" (формат записи BCD, 1 = 10ms)
		*/
		
		public static const CHANEL_CONTROLLER_MESSAGE:int			=0;
		public static const CHANEL_CONTROLLER_COMMAND_ACL:int		=1;
		
		public static const CONTROLLER_PRESS_PAPER_IN:int	=0;
		public static const CONTROLLER_PRESS_DONE:int	=1;
		public static const CONTROLLER_PAPER_SENSOR:int	=2;
		public static const CONTROLLER_PRESS_PUSH_TIMEOUT:int	=3;
		public static const CONTROLLER_PRESS_PULL_TIMEOUT:int	=4;
		public static const CONTROLLER_PUSH_TIMEOUT:int	=5;
		//2018-01-22
		public static const FEEDER_REAM_FILLED:int=6; 
		public static const FEEDER_REAM_EMPTY:int=7; 
		public static const FEEDER_SHEET_IN:int=8; 
		public static const FEEDER_SHEET_PASS:int=9; 
		public static const FEEDER_ALARM_OFF:int=10; 
		public static const FEEDER_ALARM_ON:int=11; 
		public static const CONTROLLER_NEW_SHEET_ERROR1:int	=12;
		public static const CONTROLLER_NEW_SHEET_ERROR2:int	=13;
		public static const GLUE_LEVEL_ALARM:int=14; 
		public static const CONTROLLER_BOOK_OUT:int	=19;

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

		//2018-01-22
		public static const FEEDER_REGISTER_SAFETY_TIME:int						=10;
		public static const FEEDER_REGISTER_POWER_SWITCH:int					=11;
		public static const FEEDER_REGISTER_PUMP_SWITCH:int						=12;
		public static const FEEDER_REGISTER_PUSH_PAPER:int						=13;
		public static const FEEDER_REGISTER_REAM_FILLED:int						=14;
		public static const CONTROLLER_REGISTER_WHITE_PAPER_DELAY:int			=15;
		public static const CONTROLLER_REGISTER_BOOK_EJECTION_DELAY:int			=16;
		public static const CONTROLLER_REGISTER_FINAL_SQUEEZING_TIME:int		=17;

		public static const CONTROLLER_REGISTER_ALARM_LAMP_SOUND:int			=18;
		
		public static const CONTROLLER_REGISTER_UNLOAD_OFF_DELAY:int			=19;
		public static const CONTROLLER_REGISTER_UNLOAD_ON_DELAY:int				=20;
		public static const CONTROLLER_REGISTER_PLATE_RETURN_DELAY:int			=21;
		public static const CONTROLLER_REGISTER_BLOCK_OUT:int					=22;
		//2018-12-27
		public static const CONTROLLER_REGISTER_SCRAPER_DELAY:int				=29;
		public static const CONTROLLER_REGISTER_SCRAPER_RUN:int					=30;
		
		public function GlueMBController(){
			super();
		}
		
		public var hasFeeder:Boolean=false;
		
		public var timeoutMainPlateForward:int;
		public var timeoutMainPlateRevers:int;
		public var timeoutUnload:int;
		public var sideStopOffDelay:int=0;
		public var sideStopOnDelay:int=0;
		
		public var whitePaperDelay:int=0;
		public var bookEjectionDelay:int=0;
		public var finalSqueezingTime:int=0;
		public var glueUnloadOffDelay:int=0;
		public var glueUnloadOnDelay:int=0;
		public var gluePlateReturnDelay:int=0;
		public var glueScraperDelay:int=0;
		public var glueScraperRun:int=0;

		public var pumpSensFilterTime:int;
		public var pumpWorkTime:int;
		public var pumpEnable:Boolean;
		//feeder
		public var feederSafetyTime:int;

		//feeder
		public function setFeederSafetyTime(msec:int):void{
			if(client && client.connected){
				client.writeRegister(FEEDER_REGISTER_SAFETY_TIME, ModbusBytes.int2bcd(int(msec/100)));
			}else{
				logErr('Контроллер не подключен');
			}
		}

		public function feederPower(on:Boolean):void{
			if(client && client.connected){
				var val:int=0;
				if(on) val=1;
				waiteCmd=FEEDER_REGISTER_POWER_SWITCH;
				client.writeRegister(waiteCmd, val);
			}else{
				logErr('Контроллер не подключен');
			}
		}

		public function feederPump(on:Boolean):void{
			if(client && client.connected){
				var val:int=0;
				if(on) val=1;
				waiteCmd=FEEDER_REGISTER_PUMP_SWITCH;
				client.writeRegister(waiteCmd, val);
			}else{
				logErr('Контроллер не подключен');
			}
		}
		public function feederFeed():void{
			if(client && client.connected){
				waiteCmd=FEEDER_REGISTER_PUSH_PAPER;
				client.writeRegister(waiteCmd, 1);
			}else{
				logErr('Контроллер не подключен');
			}
		}
		public function feederGetReamState():void{
			if(client && client.connected){
				waiteCmd=FEEDER_REGISTER_REAM_FILLED;
				client.readHoldingRegisters(FEEDER_REGISTER_REAM_FILLED,1);
			}else{
				logErr('Контроллер не подключен');
			}
		}

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

		public function setWhitePaperDelay(msec:int):void{
			//if(!hasFeeder) return;
			if(client && client.connected){
				client.writeRegister(CONTROLLER_REGISTER_WHITE_PAPER_DELAY, ModbusBytes.int2bcd(int(msec/10)));
			}else{
				logErr('Контроллер не подключен');
			}
		}

		public function setBookEjectionDelay(msec:int):void{
			//if(!hasFeeder) return;
			if(client && client.connected){
				client.writeRegister(CONTROLLER_REGISTER_BOOK_EJECTION_DELAY, ModbusBytes.int2bcd(int(msec/10)));
			}else{
				logErr('Контроллер не подключен');
			}
		}

		public function setFinalSqueezingTime(msec:int):void{
			//if(!hasFeeder) return;
			if(client && client.connected){
				client.writeRegister(CONTROLLER_REGISTER_FINAL_SQUEEZING_TIME, ModbusBytes.int2bcd(int(msec/10)));
			}else{
				logErr('Контроллер не подключен');
			}
		}

		public function setUnloadOffDelay(msec:int):void{
			//if(!hasFeeder) return;
			if(client && client.connected){
				client.writeRegister(CONTROLLER_REGISTER_UNLOAD_OFF_DELAY, ModbusBytes.int2bcd(int(msec/10)));
			}else{
				logErr('Контроллер не подключен');
			}
		}

		public function setUnloadOnDelay(msec:int):void{
			//if(!hasFeeder) return;
			if(client && client.connected){
				client.writeRegister(CONTROLLER_REGISTER_UNLOAD_ON_DELAY, ModbusBytes.int2bcd(int(msec/10)));
			}else{
				logErr('Контроллер не подключен');
			}
		}

		public function setPlateReturnDelay(msec:int):void{
			//if(!hasFeeder) return;
			if(client && client.connected){
				client.writeRegister(CONTROLLER_REGISTER_PLATE_RETURN_DELAY, ModbusBytes.int2bcd(int(msec/10)));
			}else{
				logErr('Контроллер не подключен');
			}
		}
		
		public function pushBlockAfterSheet():void{
			//write Final_paper_D
			if(client && client.connected){
				client.writeRegister(CONTROLLER_REGISTER_FINAL_PAPER,1);
			}else{
				logErr('Контроллер не подключен');
			}
		}

		public function pushBlock():void{
			//write Final_paper_D
			if(client && client.connected){
				client.writeRegister(CONTROLLER_REGISTER_BLOCK_OUT,1);
			}else{
				logErr('Контроллер не подключен');
			}
		}
		
		public function setAlarmOn():void{
			if(client && client.connected){
				client.writeRegister(CONTROLLER_REGISTER_ALARM_LAMP_SOUND, 1);
			}else{
				logErr('Контроллер не подключен');
			}
		}
		public function setAlarmOff():void{
			if(client && client.connected){
				client.writeRegister(CONTROLLER_REGISTER_ALARM_LAMP_SOUND, 0);
			}else{
				logErr('Контроллер не подключен');
			}
		}
		
		public function setScraperDelay(msec:int):void{
			if(client && client.connected){
				client.writeRegister(CONTROLLER_REGISTER_SCRAPER_DELAY, ModbusBytes.int2bcd(int(msec/10)));
			}else{
				logErr('Контроллер не подключен');
			}
		}

		public function setScraperRun(msec:int):void{
			if(client && client.connected){
				client.writeRegister(CONTROLLER_REGISTER_SCRAPER_RUN, ModbusBytes.int2bcd(int(msec/10)));
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
				//if(hasFeeder){
					setWhitePaperDelay(whitePaperDelay);
					if(bookEjectionDelay>10) setBookEjectionDelay(bookEjectionDelay);
					setFinalSqueezingTime(finalSqueezingTime);
					setUnloadOffDelay(glueUnloadOffDelay);
					setUnloadOnDelay(glueUnloadOnDelay);
					setPlateReturnDelay(gluePlateReturnDelay);
					setScraperDelay(glueScraperDelay);
					setScraperRun(glueScraperRun);
				//}
			}
		}
		
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
				
				case GLUE_LEVEL_ALARM:
				case CONTROLLER_NEW_SHEET_ERROR1:
				case CONTROLLER_NEW_SHEET_ERROR2:
				case FEEDER_ALARM_ON:
				case FEEDER_ALARM_OFF:
				case FEEDER_SHEET_IN:
				case FEEDER_SHEET_PASS:
				case FEEDER_REAM_FILLED:
				case FEEDER_REAM_EMPTY:
				case CONTROLLER_BOOK_OUT:{
					//notify handler
					dispatchEvent(new ControllerMesageEvent(CHANEL_CONTROLLER_MESSAGE,adu.pdu.value));
					break;
				}
				case CONTROLLER_PRESS_PAPER_IN:{
					//notify handler
					dispatchEvent(new ControllerMesageEvent(CHANEL_CONTROLLER_MESSAGE,CONTROLLER_PRESS_PAPER_IN));
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
			}else if(cmd==FEEDER_REGISTER_REAM_FILLED){
				//emulate ream message
				if(adu && adu.pdu && adu.pdu.functionCode==ModbusPDU.FUNC_READ_HOLDING_REGISTERS){
					if(adu.pdu.hasValue(0)){
						if(adu.pdu.getValue(0)==0){
							dispatchEvent(new ControllerMesageEvent(CHANEL_CONTROLLER_MESSAGE,FEEDER_REAM_EMPTY));
						}else{
							dispatchEvent(new ControllerMesageEvent(CHANEL_CONTROLLER_MESSAGE,FEEDER_REAM_FILLED));
						}
					}
				}
			}else{
				//command acl
				dispatchEvent(new ControllerMesageEvent(CHANEL_CONTROLLER_COMMAND_ACL,cmd));
			}
		}
		
		

	}
}