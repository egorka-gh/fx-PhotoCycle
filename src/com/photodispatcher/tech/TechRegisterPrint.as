package com.photodispatcher.tech{
	import com.photodispatcher.event.AsyncSQLEvent;
	import com.photodispatcher.model.mysql.entities.TechLog;
	import com.photodispatcher.model.TechPrintGroup;
	import com.photodispatcher.model.dao.PrintGroupDAO;
	import com.photodispatcher.model.dao.TechLogDAO;
	import com.photodispatcher.model.dao.local.TechPrintGroupDAO;
	
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
			//dao.addLog(tl);
			dao.addPrintLog(tl);
			
			/*
			if(isComplete){
				//set printgroup/order state
				var pdao:PrintGroupDAO=new PrintGroupDAO();
				pdao.setPrintStateByTech(printGroupId,true);
			}
			*/
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
					//pdao.setExtraStateByTech(pg.id, pg.tech_type);
					pdao.setPrintStateByTech(pg.id,true);
				}else{
					pdao.startExtraStateByTech(pg.id, pg.tech_type);
				}
			}
			return pg; 
		}

		override public function finalise():Boolean{
			if(!isComplete){
				//4 reprint set printgroup/order state (partial print???) 
				var pdao:PrintGroupDAO=new PrintGroupDAO();
				pdao.setPrintStateByTech(printGroupId,false);
			}
			return super.finalise();
		}
		
	}
}