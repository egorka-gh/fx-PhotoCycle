package com.photodispatcher.service.barcode{
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
			started=true;
		}
		
		override public function stop():void{
			started=false;
		}
		
		public var pgId:String='';
		public var books:int=-1;
		public var sheets:int=-1;

		public var book:int=-1;
		public var sheet:int=-1;

		public var pickerInterval:int=5000;

		public function emulateNext():void{
			
		}
	}
}