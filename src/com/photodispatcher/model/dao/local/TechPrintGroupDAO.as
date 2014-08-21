package com.photodispatcher.model.dao.local{
	import com.photodispatcher.model.mysql.entities.TechLog;
	import com.photodispatcher.model.TechPrintGroup;
	
	import flash.data.SQLStatement;

	public class TechPrintGroupDAO extends LocalDAO{
		
		override protected function processRow(o:Object):Object{
			var a:TechPrintGroup= new TechPrintGroup();
			fillRow(o,a);
			return a;
		}
		
		/*
		public function start(id:String, books:int, sheets:int, techType:int):void{
			var sequence:Array=[];
			var stmt:SQLStatement;
			var sql:String;
			var params:Array;
			var dt:Date=new Date();

			//create pg
			sql='INSERT INTO tech_print_group (id, tech_type, start_date, books, sheets)'+
				' SELECT ?, ?, ?, ?, ?  WHERE NOT EXISTS (SELECT 1 FROM tech_print_group WHERE id=?)';
			params=[id, techType, dt, books, sheets, id];
			sequence.push(prepareStatement(sql,params));
			
			executeSequence(sequence);
		}
		*/
		
		public function log(item:TechLog, books:int, sheets:int, techType:int):void{
			var sequence:Array=[];
			var stmt:SQLStatement;
			var sql:String;
			var params:Array;
			var dt:Date=new Date();

			//log item
			sql='INSERT INTO tech_log (print_group, sheet, src_id, log_date)'+
				' VALUES ( ?, ?, ?, ?)';
			params=[item.print_group, item.sheet, item.src_id, dt];
			sequence.push(prepareStatement(sql,params));
			
			//create pg
			sql='INSERT OR IGNORE INTO tech_print_group (id, tech_type, start_date, books, sheets)'+
				' SELECT ?, ?, ?, ?, ?  WHERE NOT EXISTS (SELECT 1 FROM tech_print_group WHERE id=?)';
			params=[item.print_group, techType, dt, books, sheets, item.print_group];
			sequence.push(prepareStatement(sql,params));

			//recalc pg
			sql='DELETE FROM tmp_tech_pg';
			sequence.push(prepareStatement(sql));
			
			sql='INSERT INTO tmp_tech_pg (id, end_date, done)'+
				' SELECT tl.print_group, MAX(tl.log_date), COUNT(DISTINCT tl.sheet)'+ 
				' FROM tech_log tl WHERE tl.print_group=? AND tl.src_id=?';
			params=[item.print_group, item.src_id];
			sequence.push(prepareStatement(sql,params));

			sql='UPDATE tech_print_group' +
				' SET end_date=(SELECT end_date FROM tmp_tech_pg t WHERE t.id=tech_print_group.id),'+
					' done=(SELECT done FROM tmp_tech_pg t WHERE t.id=tech_print_group.id)'+
				'  WHERE id=?';
			params=[item.print_group];
			sequence.push(prepareStatement(sql,params));
			
			executeSequence(sequence);
		}
		
		public function removeOld(days:int=10):void{
			var sequence:Array=[];
			var stmt:SQLStatement;
			var sql:String;
			var dt:Date= new Date();
			dt= new Date(dt.fullYear, dt.month, dt.date-days);

			sql='DELETE FROM tmp_tech_pg';
			sequence.push(prepareStatement(sql));
			
			sql='INSERT INTO tmp_tech_pg (id)'+
				' SELECT id FROM tech_print_group WHERE start_date<?';
			sequence.push(prepareStatement(sql,[dt]));

			sql='DELETE FROM tech_log WHERE print_group IN (SELECT id FROM tmp_tech_pg)';
			sequence.push(prepareStatement(sql));

			sql='DELETE FROM tech_print_group WHERE id IN (SELECT id FROM tmp_tech_pg)';
			sequence.push(prepareStatement(sql));

			executeSequence(sequence);
		}

		public function startLoged(pgId:String):void{
			var sequence:Array=[];
			var stmt:SQLStatement;
			var sql:String;
			
			sql='UPDATE tech_print_group' +
				' SET start_loged=1'+
				'  WHERE id=?';
			sequence.push(prepareStatement(sql,[pgId]));
			
			executeSequence(sequence);
		}

		public function setComplite(pgId:String):void{
			var sequence:Array=[];
			var stmt:SQLStatement;
			var sql:String;
			
			//if exists
			sql='UPDATE tech_print_group' +
				' SET done=books*sheets'+
				'  WHERE id=?';
			sequence.push(prepareStatement(sql,[pgId]));
			
			//if not exists
			//create complited & logged
			sql='INSERT OR IGNORE INTO tech_print_group (id, start_loged) VALUES ( ?, 1)';
			sequence.push(prepareStatement(sql,[pgId]));
			
			executeSequence(sequence);
		}

		public function remove(pgId:String):void{
			var sequence:Array=[];
			var stmt:SQLStatement;
			var sql:String;
			
			//clear log
			sql='DELETE FROM tech_log WHERE print_group=?';
			sequence.push(prepareStatement(sql,[pgId]));
			//clear pg
			sql='DELETE FROM tech_print_group WHERE id=?';
			sequence.push(prepareStatement(sql,[pgId]));

			executeSequence(sequence);
		}
		
		public function finde4Transfer():Array{
			var sql:String='SELECT pg.*'+
							' FROM tech_print_group pg'+
							' WHERE pg.done=pg.books*pg.sheets OR pg.start_loged=0';
			runSelect(sql,null,true);
			return itemsArray;
		}

		public function findeIncomplete():Array{
			var sql:String='SELECT pg.*'+
							' FROM tech_print_group pg'+
							' WHERE pg.done!=pg.books OR start_loged=0'
							' ORDER BY pg.start_date';
			runSelect(sql,null,true);
			return itemsArray;
		}

		public function getById(id:String):TechPrintGroup{
			var sql:String='SELECT pg.*'+
							' FROM tech_print_group pg'+
							' WHERE pg.id=?';
			runSelect(sql,[id],true);
			return item as TechPrintGroup;;
		}

	}
}