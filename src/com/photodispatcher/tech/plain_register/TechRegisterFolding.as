package com.photodispatcher.tech.plain_register{
	import com.photodispatcher.model.mysql.DbLatch;
	import com.photodispatcher.model.mysql.entities.TechLog;
	import com.photodispatcher.model.mysql.services.TechService;
	
	import flash.events.Event;
	
	import org.granite.tide.Tide;

	public class TechRegisterFolding extends TechRegisterBase{
		
		public function TechRegisterFolding(printGroup:String, books:int, sheets:int, disconnected:Boolean=false){
			super(printGroup, books, sheets, disconnected);
			_type=TYPE_FOLDING;
			_logSequenceErr=false;
			logOk=false;
			//calcOnLog=true;
			calcOnLog=false;
		}

	}
}