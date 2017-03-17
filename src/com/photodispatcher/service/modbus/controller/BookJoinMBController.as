package com.photodispatcher.service.modbus.controller{
	import com.photodispatcher.event.ControllerMesageEvent;
	import com.photodispatcher.service.modbus.ModbusRequestEvent;
	import com.photodispatcher.service.modbus.ModbusResponseEvent;
	import com.photodispatcher.service.modbus.data.ModbusADU;
	import com.photodispatcher.service.modbus.data.ModbusBytes;
	
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	
	[Event(name="connectChange", type="flash.events.Event")]
	[Event(name="error", type="flash.events.ErrorEvent")]
	[Event(name="complete", type="flash.events.Event")]
	[Event(name="controllerMesage", type="com.photodispatcher.event.ControllerMesageEvent")]
	public class BookJoinMBController extends MBController{
		/*
		D0 (адрес регистра 0x0000) - Find_reference - выход в исходное ( 0x0001 - запустить, сброс в 0x0000 - автоматически)
		D1* (адрес регистра 0x0001) - Goto_relative_position - значение позиции относительно опорной точки (0x0000 - 0xFFFF,  рабочие значения около 2000 импульсов, 1 импульс != 1 мм, надо подбирать)
		*для старта необходимо обращение к D2
		D2 (адрес регистра 0x0002) - Start_goto_position - переход в относительное положение по адресу D1 ( 0x0001 - запустить, сброс в 0x0000 - автоматически)
		D3 (адрес регистра 0x0003) - Current_pos - текущее положения шагового двигателя относительно опорного датчика (до момента выхода в исходное значение 0xFFFF)
		D12 (адрес регистра 0x000С) - Target Frequency - скорость перемещения в Гц (характеристика двигателя от 200-1000Гц, номинальная скорость 350Гц, т.к. при 200Гц(макс. момент) резонанс
		D22 (адрес регистра 0x000С) - Output Timeout delay - время таймаута при переходе в положение (формат записи BCD)
		
		События отпарвляемы в PC(адрес регистра по modbus 0):
		0 - поиск исходного положения завершен
		1 - фотодатчик фронт (лог.1)
		2 - фотодатчик спад (лог.0)
		3 - 8 - резерв(функционал заложен) для 3 датчиков по аналогии с D1-D2
		9 - переход в заданное положение завершен
		10 - ошибка перехода в положение. не выполнен поиск исходного положения
		11 - ошибка перехода в положение. превышено допустимое время (10секунд по умолчанию) подачи управляющего сигнала. (в первую очередь смотреть в сторону перехода в исходное). при сработке данной ошибки, необходимо заново искать исходное положение
		*/

		public static const CONTROLLER_FIND_REFERENCE_COMPLITE:int			=0;
		public static const CONTROLLER_PAPER_SENSOR_IN:int					=1;
		public static const CONTROLLER_PAPER_SENSOR_OUT:int					=2;
		public static const CONTROLLER_GOTO_RELATIVE_POSITION_COMPLITE:int	=9;
		public static const CONTROLLER_ERR_HASNO_REFERENCE:int				=10;
		public static const CONTROLLER_ERR_GOTO_TIMEOUT:int					=11;

		public static const CONTROLLER_REGISTER_FIND_REFERENCE:int			=0;
		public static const CONTROLLER_REGISTER_SET_RELATIVE_POSITION:int	=1;
		public static const CONTROLLER_REGISTER_GOTO_RELATIVE_POSITION:int	=2;
		public static const CONTROLLER_REGISTER_GET_RELATIVE_POSITION:int	=3;
		public static const CONTROLLER_REGISTER_SET_ENGINE_FREQUENCY:int	=12;
		public static const CONTROLLER_REGISTER_GOTO_RELATIVE_POSITION_TIMEOUT:int	=22;

		
		public function BookJoinMBController(){
			super();
		}
		
		protected var waiteCmd:int=-1;
		
		public function findReference():void{
			if(client && client.connected){
				client.writeRegister(CONTROLLER_REGISTER_FIND_REFERENCE,1);
				waiteCmd=-1;
			}else{
				logErr('Контроллер не подключен');
			}
		}
		
		public function gotoPosition(value:int):void{
			if(client && client.connected){
				client.writeRegister(CONTROLLER_REGISTER_SET_RELATIVE_POSITION,value);
				waiteCmd=CONTROLLER_REGISTER_SET_RELATIVE_POSITION;
			}else{
				logErr('Контроллер не подключен');
			}
		}

		public function getPosition():void{
			if(client && client.connected){
				client.readHoldingRegisters(CONTROLLER_REGISTER_GET_RELATIVE_POSITION,1);
				waiteCmd=CONTROLLER_REGISTER_GET_RELATIVE_POSITION;
			}else{
				logErr('Контроллер не подключен');
			}
		}

		public function setEngineFrequency(value:int):void{
			if(client && client.connected){
				client.writeRegister(CONTROLLER_REGISTER_SET_ENGINE_FREQUENCY,value);
				waiteCmd=-1;
			}else{
				logErr('Контроллер не подключен');
			}
		}

		public function setGotoTimeout(msec:int):void{
			//msec/100 ???
			if(client && client.connected){
				client.writeRegister(CONTROLLER_REGISTER_GOTO_RELATIVE_POSITION_TIMEOUT,ModbusBytes.int2bcd(int(msec/100)));
				waiteCmd=-1;
			}else{
				logErr('Контроллер не подключен');
			}
		}
		
		override protected function onClientConnect(evt:Event):void{
			super.onClientConnect(evt);
			// TODO implement client init
		}
		
		override protected function onServerADU(evt:ModbusRequestEvent):void{
			super.onServerADU(evt);
			//adu proccessing
			var adu:ModbusADU=evt.adu;
			if(!adu) return;
			//check adr
			if(adu.pdu.address!=0){
				logMsg('wrong register address ' +adu.pdu.address);
				return;
			}
			switch(adu.pdu.value){
				case CONTROLLER_FIND_REFERENCE_COMPLITE:
				case CONTROLLER_PAPER_SENSOR_IN:
				case CONTROLLER_PAPER_SENSOR_OUT:
				case CONTROLLER_GOTO_RELATIVE_POSITION_COMPLITE:
				case CONTROLLER_ERR_HASNO_REFERENCE:
				case CONTROLLER_ERR_GOTO_TIMEOUT:
					//notify handler
					dispatchEvent(new ControllerMesageEvent(MBController.MESSAGE_CHANEL_SERVER,adu.pdu.value));
					break;
				default:{
					logMsg('Неизвестный код сообщения '+adu.pdu.value);
					break;
				}
			}

			/*
			switch(adu.pdu.value){
				case CONTROLLER_FIND_REFERENCE_COMPLITE:{
					//notify handler
					dispatchEvent(new ControllerMesageEvent(0,CONTROLLER_FIND_REFERENCE_COMPLITE));
					txt='Поиск исходного положения завершен';
					break;
				}
				case CONTROLLER_PAPER_SENSOR_IN:{
					dispatchEvent(new ControllerMesageEvent(0,CONTROLLER_PAPER_SENSOR_IN));
					txt='Лист пошел';
					break;
				}
				case CONTROLLER_PAPER_SENSOR_OUT:{
					dispatchEvent(new ControllerMesageEvent(0,CONTROLLER_PAPER_SENSOR_OUT));
					txt='Лист вышел';
					break;
				}
				case CONTROLLER_GOTO_RELATIVE_POSITION_COMPLITE:{
					dispatchEvent(new ControllerMesageEvent(0,CONTROLLER_GOTO_RELATIVE_POSITION_COMPLITE));
					txt='Переход в заданное положение завершен';
					break;
				}
				case CONTROLLER_ERR_HASNO_REFERENCE:{
					dispatchEvent(new ControllerMesageEvent(0,CONTROLLER_ERR_HASNO_REFERENCE));
					txt='Не выполнен поиск исходного положения';
					break;
				}
				case CONTROLLER_ERR_GOTO_TIMEOUT:{
					dispatchEvent(new ControllerMesageEvent(0,CONTROLLER_ERR_GOTO_TIMEOUT));
					txt='Таймаут перехода в заданное положение';
					break;
				}
				default:{
					txt='Неизвестный код сообщения '+adu.pdu.value;
					break;
				}
			}
			if(txt) logMsg(txt);
			*/

		}

		override public function start():void{
			super.start();
			waiteCmd=-1;
		}
		
		override public function stop():void{
			super.stop();
			waiteCmd=-1;
		}
		
		override protected function onClientADU(evt:ModbusResponseEvent):void{
			if(waiteCmd==-1) return;
			var cmd:int=waiteCmd;
			waiteCmd=-1;
			switch (cmd){
				case CONTROLLER_REGISTER_SET_RELATIVE_POSITION:{
					//start move
					if(client && client.connected){
						client.writeRegister(CONTROLLER_REGISTER_GOTO_RELATIVE_POSITION,1);
					}
					break;
				}
				case CONTROLLER_REGISTER_GET_RELATIVE_POSITION:{
					var adu:ModbusADU=evt.adu;
					if(adu && adu.pdu && adu.pdu.hasValue(0)){
						dispatchEvent(new ControllerMesageEvent(MBController.MESSAGE_CHANEL_CLIENT,adu.pdu.getValue(0)));
					}
					break;
				}
			}
		}
		
		override protected function onClientErr(evt:ErrorEvent):void{
			super.onClientErr(evt);
			waiteCmd=-1;
		}
		
	}
}