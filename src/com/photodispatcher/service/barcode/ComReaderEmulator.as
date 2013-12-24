package com.photodispatcher.service.barcode{
	import com.photodispatcher.event.BarCodeEvent;
	import com.photodispatcher.model.PrintGroup;
	import com.photodispatcher.model.dao.PrintGroupDAO;
	import com.photodispatcher.util.StrUtil;
	
	import flash.events.TimerEvent;
	import flash.utils.Timer;
	import flash.utils.getTimer;

	public class ComReaderEmulator extends ComReader{
		
		public function ComReaderEmulator(doubleScanGap:int=DOUBLE_SCAN_GAP){
			super(doubleScanGap);
		}
		
		override public function set comPort(value:Socket2Com):void{
		}
		
		private var _connected:Boolean=true;
		override public function get connected():Boolean{
			return _connected;
		}
		
		private var started:Boolean;
		override public function get isStarted():Boolean{
			return started;
		}
		
		override public function start(comPort:Socket2Com=null):void{
			if(!pgId){
				started=false;
				return;
			}
			var dao:PrintGroupDAO= new PrintGroupDAO();
			var pg:PrintGroup=dao.getByID(pgId);
			if(!pg){
				started=false;
				return;
			}
			books=pg.book_num;
			sheets=pg.sheet_num;
			
			started=true;
		}
		
		override public function stop():void{
			if(barTimer){
				barTimer.reset();
				barTimer.removeEventListener(TimerEvent.TIMER, onBarTimer);
				barTimer=null;
			}
			started=false;
		}
		
		public var pgId:String='';
		public var books:int=-1;
		public var sheets:int=-1;

		public var book:int=-1;
		public var sheet:int=-1;

		public var pickerInterval:int=5000;

		public function emulateNext():void{
			if(book==-1){
				book=1;
				sheet=1;
			}else{
				sheet++;
				if(sheet>sheets){
					sheet=1;
					book++;
					if(book>books){
						//comlite, reset 
						book=1;
						sheet=1;
					}
				}
			}
			emulateBar();
		}
		
		private var barTimer:Timer;
		private function emulateBar():void{
			if(!barTimer){
				barTimer=new Timer(pickerInterval*2/3,1);
				barTimer.addEventListener(TimerEvent.TIMER, onBarTimer);
			}
			barTimer.start();
		}
		private function onBarTimer(e:TimerEvent):void{
			var barcode:String=StrUtil.lPad(book.toString(),3)+StrUtil.lPad(books.toString(),3)+StrUtil.lPad(sheet.toString(),2)+StrUtil.lPad(sheets.toString(),2)+pgId;
			lastBarcode=barcode;
			lastBarcodeTime=getTimer();	
			dispatchEvent(new BarCodeEvent(BarCodeEvent.BARCODE_READED,barcode));
		}

	}
}