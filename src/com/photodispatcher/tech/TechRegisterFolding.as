package com.photodispatcher.tech{
	import com.photodispatcher.event.AsyncSQLEvent;
	import com.photodispatcher.model.mysql.entities.TechLog;
	import com.photodispatcher.model.TechPrintGroup;
	import com.photodispatcher.model.dao.PrintGroupDAO;
	import com.photodispatcher.model.dao.TechLogDAO;
	import com.photodispatcher.model.dao.local.TechPrintGroupDAO;

	public class TechRegisterFolding extends TechRegisterBase{
		
		public function TechRegisterFolding(printGroup:String, books:int, sheets:int){
			super(printGroup, books, sheets);
			_canInterrupt=true;
			_strictSequence=true;
		}
		
		private var startLoged:Boolean=false;
		
		override public function register(book:int, sheet:int):void{
			super.register(book, sheet);

			var tl:TechLog= new TechLog();
			tl.log_date=new Date();
			tl.setSheet(book,sheet);
			tl.print_group=printGroupId;
			tl.src_id= techPoint.id;
			
			if(sheet<2 || sheet==sheets){
				//log first end end sheets to data base
				var dao:TechLogDAO=new TechLogDAO();
				dao.addLog(tl);
			}

			var lDao:TechPrintGroupDAO;
			if(!startLoged){
				//log to local db
				lDao= new TechPrintGroupDAO();
				lDao.addEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT, onLocalLog);
				lDao.log(tl,books,sheetsPerBook, techPoint.tech_type);
				startLoged=true;
			}else if(isComplete){
				/*
				//set printgroup/order state
				var pdao:PrintGroupDAO=new PrintGroupDAO();
				pdao.setExtraStateByTech(printGroupId,techPoint.tech_type);
				*/
				//set complite in local db
				lDao= new TechPrintGroupDAO();
				lDao.addEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT, onLocalLog);
				lDao.setComplite(printGroupId);
			}
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

	}
}