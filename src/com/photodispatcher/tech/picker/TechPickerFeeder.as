package com.photodispatcher.tech.picker{
	import com.photodispatcher.event.ControllerMesageEvent;
	import com.photodispatcher.model.mysql.entities.LayerSequence;
	
	import flash.events.ErrorEvent;
	import flash.events.Event;

	[Event(name="error", type="flash.events.ErrorEvent")]
	public class TechPickerFeeder extends TechPicker{
		
		public function TechPickerFeeder(techGroup:int){
			super(techGroup);
		}
		
		override protected function onControllerMsg(event:ControllerMesageEvent):void{
			//controller.close(currentTray);
			// TODO Auto Generated method stub
			super.onControllerMsg(event);
		}
		
		override protected function nextStep():void{
			//controller.close(currentTray);
			// TODO Auto Generated method stub
			super.nextStep();
		}
		
		override protected function startDevices():void
		{
			// TODO Auto Generated method stub
			super.startDevices();
		}
		
		override protected function feedLayer(ls:LayerSequence):void
		{
			// TODO Auto Generated method stub
			super.feedLayer(ls);
		}
		
		override protected function feedSheet():void
		{
			// TODO Auto Generated method stub
			super.feedSheet();
		}
		
		override protected function onLatchTimeout(event:ErrorEvent):void{
			//controller.close(currentTray);
			// TODO Auto Generated method stub
			super.onLatchTimeout(event);
		}
		
		override protected function onLatchRelease(event:Event):void
		{
			// TODO Auto Generated method stub
			super.onLatchRelease(event);
		}
		
		
		
		
	}
}