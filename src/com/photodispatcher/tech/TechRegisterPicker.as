package com.photodispatcher.tech{
	import flash.events.Event;

	public class TechRegisterPicker extends TechRegisterBase{
		
		public function TechRegisterPicker(printGroup:String, books:int, sheets:int){
			super(printGroup, books, sheets);
			logOk=false;
		}
		
		override public function get strictSequence():Boolean{
			return true;
		}
		
	}
}