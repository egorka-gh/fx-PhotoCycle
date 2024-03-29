package com.photodispatcher.service.barcode{
	import com.adobe.protocols.dict.events.ErrorEvent;
	import com.photodispatcher.event.BarCodeEvent;
	import com.photodispatcher.event.SerialProxyEvent;
	import com.photodispatcher.interfaces.ISimpleLogger;
	
	import flash.events.TimerEvent;
	import flash.utils.Timer;

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
		public static const MSG_DELEMITER:int=0x09;

		public var logger:ISimpleLogger;
		private var aclTimer:Timer;

		public function EBS6kController(){
			super();
			sufix=MSG_SUFIX;
			cleanMsg=false;
			doubleScanGap=0;
		}
		
		public function sendMessage(message:String):void{
			if(!message) return;
			var msg:String=message+String.fromCharCode(MSG_SUFIX);
			log('> '+msg);
			if(!aclTimer){
				aclTimer= new Timer(ACKNOWLEDGE_TIMEOUT,1);
				aclTimer.addEventListener(TimerEvent.TIMER, onAclTimer);
			}
			aclTimer.start();
			send(msg);
		}

		public function sendMessages(messages:Array):void{
			if(!messages) return;
			var msg:String='';
			for each(var str:String in messages){
				if(str){
					if(msg) msg+=String.fromCharCode(MSG_DELEMITER);
					msg+=str;
				}else{
					//err
					msg='';
					break;
				}
			}
			sendMessage(msg);
		}

		override protected function onComData(event:SerialProxyEvent):void{
			//awaits ACK only
			//no ACK control, no error if no respoce from printer, just log responce
			stopTimer();
			buffer='';

			var mesage:String=event.data;
			if(mesage && mesage.charCodeAt(0)==MSG_ACK){
				if(aclTimer) aclTimer.reset();
			}
			mesage=mesage.replace(String.fromCharCode(MSG_ACK),'[ACK]');
			log('< '+mesage);
			dispatchEvent(new BarCodeEvent(BarCodeEvent.BARCODE_READED,mesage));
		}

		protected function log(msg:String):void{
			if(!logger) return;
			var str:String=msg.replace(String.fromCharCode(MSG_SUFIX), "(h"+MSG_SUFIX.toString(16)+")");
			str=str.replace(String.fromCharCode(MSG_ACK), "(h"+MSG_ACK.toString(16)+")");
			str=str.replace(String.fromCharCode(MSG_DELEMITER), "(h"+MSG_DELEMITER.toString(16)+")");
			logger.log(this.comCaption+' '+ str);
		}
		
		private function onAclTimer(evt:TimerEvent):void{
			//just log
			aclTimer.reset();
			log('! ACK timeout');
		}

	}
}