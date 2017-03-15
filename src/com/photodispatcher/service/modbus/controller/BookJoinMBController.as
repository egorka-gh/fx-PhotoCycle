package com.photodispatcher.service.modbus.controller{
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	
	[Event(name="connectChange", type="flash.events.Event")]
	[Event(name="error", type="flash.events.ErrorEvent")]
	[Event(name="complete", type="flash.events.Event")]
	[Event(name="controllerMesage", type="com.photodispatcher.event.ControllerMesageEvent")]
	public class BookJoinMBController extends EventDispatcher{
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
			super(null);
		}
		
	}
}