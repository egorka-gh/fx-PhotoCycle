package com.photodispatcher.tech{
	import com.photodispatcher.event.AsyncSQLEvent;
	import com.photodispatcher.model.TechLog;
	import com.photodispatcher.model.TechPrintGroup;
	import com.photodispatcher.model.dao.BaseDAO;
	import com.photodispatcher.model.dao.PrintGroupDAO;
	import com.photodispatcher.model.dao.TechLogDAO;
	import com.photodispatcher.model.dao.local.TechPrintGroupDAO;
	import com.photodispatcher.util.ArrayUtil;
	
	public class TechRegisterCommon extends TechRegisterBase{
		
		
		public function TechRegisterCommon(printGroup:String, books:int, sheets:int){
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
			//log to local db
			var lDao:TechPrintGroupDAO= new TechPrintGroupDAO();
			lDao.addEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT, onLocalLog);
			lDao.log(tl,books,sheetsPerBook, techPoint.tech_type);
			/*
			if(isComplete){
				//set printgroup/order state
				var pg:TechPrintGroup= new TechPrintGroup();
				pg.id=tl.print_group;
				pg.src_id=tl.src_id;
				complited.push(pg);
				if(!isWriting) writeNext();
				
				//var pdao:PrintGroupDAO=new PrintGroupDAO();
				//pdao.execOnItem=printGroupId;
				//pdao.addEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT, onExtraWrite);
				//pdao.setExtraStateByTech(printGroupId,techPoint.tech_type);
			}
			*/
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