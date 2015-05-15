package com.photodispatcher.service.barcode{
	public class EBS6kController extends ComDevice{
		/*
		Передайте текст через интерфейс RS232. Передавать можно только ASCII-знаки. Каждый текст должен 
		заканчиваться знаком ENTER-(0D hex) . Возможно передать до 6 подтекстов в составе одного текста.
		( подтексты разделяются при подготовке знаком „Ctrl I“ - Tab?
		После получения знака ( 0Dhex) принтер посылает ответный сигнал знаком ACK-(06 hex) .
		*/
		public static const ERROR_ACKNOWLEDGE_TIMEOUT:int	=100;

		public static const MSG_SUFIX:int=0x0D;
		public static const ACKNOWLEDGE_TIMEOUT:int	=200;

		public static const MSG_ACK:int=0x06;

		public function EBS6kController(){
			super();
			//sufix=MSG_SUFIX;
			cleanMsg=false;
			doubleScanGap=0;
			addEventListener(BarCodeEvent.BARCODE_READED,onMessage,false,int.MAX_VALUE);
			addEventListener(BarCodeEvent.BARCODE_ERR,onComError,false,int.MAX_VALUE);
		}
		
		
	}
}