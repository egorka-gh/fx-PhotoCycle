package com.photodispatcher.tech{
	import com.photodispatcher.model.mysql.DbLatch;
	import com.photodispatcher.model.mysql.services.TechService;
	
	import flash.events.Event;
	
	import org.granite.tide.Tide;
	
	public class TechRegisterPrint extends TechRegisterBase{
		public function TechRegisterPrint(printGroup:String, books:int, sheets:int){
			super(printGroup, books, sheets);
			logOk=false;
		}
		
		override protected function logRegistred(book:int, sheet:int):void{
			super.logRegistred(book, sheet);
			//update meter
			var latch:DbLatch=new DbLatch();
			var svc:TechService=Tide.getInstance().getContext().byType(TechService,true) as TechService;
			latch.addLatch(svc.forwardMeterByTechPoint(techPoint.id, printGroupId));
			latch.addEventListener(Event.COMPLETE, onLogComplie);
			latch.start();
		}
		private function onLogComplie(evt:Event):void{
			var latch:DbLatch=evt.target as DbLatch;
			if(latch && !latch.complite){
				logSequeceErr('Ошибка базы данных: '+latch.error);
			}
		}
		
		
	}
}