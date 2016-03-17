package com.photodispatcher.tech{
	import com.photodispatcher.model.mysql.DbLatch;
	import com.photodispatcher.model.mysql.entities.TechLog;
	import com.photodispatcher.model.mysql.services.TechService;
	
	import flash.events.Event;
	
	import org.granite.tide.Tide;

	public class TechRegisterFolding extends TechRegisterBase{
		
		public function TechRegisterFolding(printGroup:String, books:int, sheets:int){
			super(printGroup, books, sheets);
			_logSequenceErr=false;
			logOk=false;
			calcOnLog=true;
			//_canInterrupt=true;
			//_strictSequence=true;
		}
		
		override protected function logRegistred(book:int, sheet:int):void{
			if(sheet<2 || sheet==sheets){
				//log first end end sheets to data base
				var tl:TechLog= new TechLog();
				tl.log_date=new Date();
				tl.setSheet(book,sheet);
				tl.print_group=printGroupId;
				tl.src_id= techPoint.id;

				var latch:DbLatch=new DbLatch(true);
				var svc:TechService=Tide.getInstance().getContext().byType(TechService,true) as TechService;
				latch.addEventListener(Event.COMPLETE, onLogComplie);
				latch.addLatch(svc.logByPg(tl,1));
				latch.start();
			}
		}
		private function onLogComplie(evt:Event):void{
			var latch:DbLatch=evt.target as DbLatch;
			if(latch) latch.removeEventListener(Event.COMPLETE, onLogComplie);
			if(latch && !latch.complite){
				logSequeceErr('Ошибка базы данных: '+latch.error);
			}
		}


		/*
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
		*/

	}
}