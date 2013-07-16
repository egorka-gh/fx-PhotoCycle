package com.photodispatcher.service.barcode{
	import com.photodispatcher.event.BarCodeEvent;
	
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.KeyboardEvent;
	import flash.events.TimerEvent;
	import flash.utils.Timer;
	
	import mx.core.FlexGlobals;
	
	[Event(name="barcodeReaded", type="com.photodispatcher.event.BarCodeEvent")]
	[Event(name="barcodeError", type="com.photodispatcher.event.BarCodeEvent")]
	public class BarcodeReaderKbd extends EventDispatcher{
		
		public static const TIMEUOT:int=500;
		
		private static const STATE_WAIT:int=0;
		private static const STATE_CAPTURE:int=1;

		[Bindable]
		public var isStarted:Boolean=false;
		public var prefix:uint=0;
		public var sufix:uint=13; //LF default
		
		private var barcode:String='';
		private var state:int=STATE_WAIT;
		private var timer:Timer;
		
		public function BarcodeReaderKbd(){
			super(null);
		}
		
		public function start():void{
			state=STATE_WAIT;
			barcode='';
			if(sufix==0){
				dispatchEvent(new BarCodeEvent(BarCodeEvent.BARCODE_ERR, barcode, 'Barcode sufix not defined'));
				return;
			}
			FlexGlobals.topLevelApplication.addEventListener(KeyboardEvent.KEY_DOWN,keyHandler);
			isStarted=true;
		}
		
		public function stop():void{
			FlexGlobals.topLevelApplication.removeEventListener(KeyboardEvent.KEY_DOWN,keyHandler);
			if(timer){
				timer.reset();
				timer.removeEventListener(TimerEvent.TIMER, onTimer);
				timer=null;
			}
			barcode='';
			state=STATE_WAIT;
			isStarted=false;
		}
		
		private function keyHandler(event:KeyboardEvent):void{
			if(event.altKey || event.ctrlKey || event.shiftKey) return;
			//trace('charCode: '+event.charCode.toString());
			newChar(event.charCode);
		}
		
		private function newChar(charCode:uint):void{
			if (charCode==0) return;
			var ch:String = String.fromCharCode(charCode);
			if(state==STATE_WAIT){
				if(prefix==0){
					barcode=ch;
					state=STATE_CAPTURE;
				}else if(prefix==charCode){
					barcode='';
					state=STATE_CAPTURE;
				}
				startTimer();
				return;
			}else if (state==STATE_CAPTURE){
				if(charCode==sufix){
					//complited
					stopTimer();
					state=STATE_WAIT;
					dispatchEvent(new BarCodeEvent(BarCodeEvent.BARCODE_READED,barcode));
					return;
				}
				barcode+=ch;
				startTimer();
			} 
		}
		
		private function startTimer():void{
			if(!timer){
				timer=new Timer(TIMEUOT,1);
				timer.addEventListener(TimerEvent.TIMER, onTimer);
			}else{
				timer.reset();
			}
			timer.start();
		}
		private function stopTimer():void{
			if(timer) timer.reset();
		}

		private function onTimer(event:TimerEvent):void{
			if (state==STATE_CAPTURE){
				var e:BarCodeEvent=new BarCodeEvent(BarCodeEvent.BARCODE_ERR, barcode, 'Timeout error');
				state=STATE_WAIT;
				barcode='';
				dispatchEvent(e);
			}
		}
	}
}