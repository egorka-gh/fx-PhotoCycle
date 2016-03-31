package com.photodispatcher.tech
{
	public class TechRegisterGlue extends TechRegisterBase{
		
		public function TechRegisterGlue(printGroup:String, books:int, sheets:int){
			super(printGroup, books, sheets);
			logOk=false;
			_strictSequence=false;
		}
	}
}