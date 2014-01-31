package com.photodispatcher.tech{
	import com.photodispatcher.model.TechLog;
	import com.photodispatcher.model.dao.PrintGroupDAO;
	import com.photodispatcher.model.dao.TechLogDAO;
	
	public class TechRegisterPrint extends TechRegisterBase{
		public function TechRegisterPrint(printGroup:String, books:int, sheets:int){
			super(printGroup, books, sheets);
		}
		
		override public function register(book:int, sheet:int):void{
			super.register(book, sheet);
			//log to data base
			var tl:TechLog= new TechLog();
			tl.log_date=new Date();
			tl.setSheet(book,sheet);
			tl.print_group=printGroupId;
			tl.src_id= techPoint.id;
			var dao:TechLogDAO=new TechLogDAO();
			dao.addLog(tl);
			if(isComplete){
				//set printgroup/order state
				var pdao:PrintGroupDAO=new PrintGroupDAO();
				pdao.setPrintStateByTech(printGroupId);
			}
		}
		
	}
}