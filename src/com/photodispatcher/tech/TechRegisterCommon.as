package com.photodispatcher.tech{
	
	public class TechRegisterCommon extends TechRegisterBase{
		
		
		public function TechRegisterCommon(printGroup:String, books:int, sheets:int){
			super(printGroup, books, sheets);
		}
		
		/*
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
			//log to local db
			var lDao:TechPrintGroupDAO= new TechPrintGroupDAO();
			lDao.addEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT, onLocalLog);
			lDao.log(tl,books,sheetsPerBook, techPoint.tech_type);
		}
		
		private function onLocalLog(evt:AsyncSQLEvent):void{
			var lDao:TechPrintGroupDAO=evt.target as TechPrintGroupDAO;
			if (lDao) lDao.removeEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT, onLocalLog);
			checkComplited();
		}
		
		override protected function writeNext():TechPrintGroup{
			var pg:TechPrintGroup=super.writeNext();
			if(pg){
				var pdao:PrintGroupDAO=new PrintGroupDAO();
				pdao.execOnItem=pg;
				pdao.addEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT, onExtraWrite);
				if(pg.isComplite){
					pdao.setExtraStateByTech(pg.id, pg.tech_type);
				}else{
					pdao.startExtraStateByTech(pg.id, pg.tech_type);
				}
			}
			return pg; 
		}
		*/
		
	}
}