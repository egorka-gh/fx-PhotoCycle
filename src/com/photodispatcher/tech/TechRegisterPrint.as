package com.photodispatcher.tech{
	import com.photodispatcher.model.mysql.DbLatch;
	import com.photodispatcher.model.mysql.services.TechService;
	
	import flash.events.Event;
	
	import org.granite.tide.Tide;
	
	public class TechRegisterPrint extends TechRegisterBase{
		public function TechRegisterPrint(printGroup:String, books:int, sheets:int){
			super(printGroup, books, sheets);
			_type=TYPE_PRINT;
			logOk=false;
		}
		
		override protected function logRegistred(book:int, sheet:int):void{
			super.logRegistred(book, sheet);
			//update meter
			var latch:DbLatch=new DbLatch(true);
			var svc:TechService=Tide.getInstance().getContext().byType(TechService,true) as TechService;
			latch.addLatch(svc.forwardMeterByTechPoint(techPoint.id, printGroupId));
			latch.addEventListener(Event.COMPLETE, onforwardMeter);
			latch.start();
		}
		private function onforwardMeter(evt:Event):void{
			var latch:DbLatch=evt.target as DbLatch;
			if(latch) latch.removeEventListener(Event.COMPLETE, onforwardMeter);
			if(latch && !latch.complite){
				logSequeceErr('Ошибка базы данных: '+latch.error);
			}
		}
		
		
	}
}