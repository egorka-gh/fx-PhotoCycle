package com.photodispatcher.tech{
	import com.photodispatcher.model.dao.PrintGroupDAO;

	public class TechRegisterFolding extends TechRegisterBase{
		
		//TODO implement login to database
		
		public function TechRegisterFolding(printGroup:String, books:int, sheets:int){
			super(printGroup, books, sheets);
		}
		
		override public function register(book:int, sheet:int):void{
			super.register(book, sheet);
			if(isComplete){
				//set printgroup/order state
				var pdao:PrintGroupDAO=new PrintGroupDAO();
				pdao.setExtraStateByTech(printGroupId,techPoint.tech_type);
			}
		}
		
		
		override public function get canInterrupt():Boolean{
			return true;
		}
		
		override public function get strictSequence():Boolean{
			return true;
		}
		
	}
}