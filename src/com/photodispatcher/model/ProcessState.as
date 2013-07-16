package com.photodispatcher.model{
	public class ProcessState{
		public static const STATE_OFFLINE:int=0;
		public static const STATE_OK_WAITE:int=1;
		public static const STATE_RUNINNG:int=2;
		public static const STATE_ERROR:int=3;

		[Bindable]
		public var state:int;
		[Bindable]
		public var caption:String;
		[Bindable]
		public var lastError:String;

		public function ProcessState(state:int=STATE_OK_WAITE,caption:String='Ожидание'){
			this.state=state;
			this.caption=caption;
		}
		
		public function setState(state:int,caption:String=null):void{
			this.state=state;
			if (caption!=null) this.caption=caption;
			if(this.state==STATE_ERROR) lastError=this.caption;
		}

		public function addCaption(caption:String):void{
			this.caption=this.caption+' '+caption;
		}
	}
}