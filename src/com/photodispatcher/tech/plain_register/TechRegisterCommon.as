package com.photodispatcher.tech.plain_register{
	
	public class TechRegisterCommon extends TechRegisterBase{
		
		
		public function TechRegisterCommon(printGroup:String, books:int, sheets:int){
			super(printGroup, books, sheets);
			_type=TYPE_COMMON;
			logOk=false;
		}
		
	}
}