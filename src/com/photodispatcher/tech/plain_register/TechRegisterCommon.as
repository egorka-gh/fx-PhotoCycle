package com.photodispatcher.tech.plain_register{
	
	public class TechRegisterCommon extends TechRegisterBase{
		
		
		public function TechRegisterCommon(printGroup:String, books:int, sheets:int, disconnected:Boolean=false){
			super(printGroup, books, sheets, disconnected);
			_type=TYPE_COMMON;
			logOk=false;
		}
		
	}
}