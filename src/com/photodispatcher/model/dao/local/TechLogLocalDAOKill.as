package com.photodispatcher.model.dao.local{
	import com.photodispatcher.model.mysql.entities.TechLog;
	import com.photodispatcher.model.TechLogLocal;
	
	import flash.data.SQLStatement;

	public class TechLogLocalDAOKill extends LocalDAO{

		override protected function processRow(o:Object):Object{
			var a:TechLogLocal= new TechLogLocal();
			fillRow(o,a);
			return a;
		}

		public function findeAll():Array{
			var sql:String='SELECT * FROM tech_log';
			runSelect(sql);
			return itemsArray;
		}

		public function getByParentId(parentId:String):Array{
			var sql:String='SELECT * FROM tech_log WHERE print_group=?';
			runSelect(sql,[parentId]);
			return itemsArray;
		}
		
		public function log(orderId:String, sheet:int, techId:int):void{
			var sequence:Array=[];
			var stmt:SQLStatement;
			var sql:String;
			var params:Array;
			var dt:Date=new Date();
			
			//log item
			sql='INSERT INTO tech_log (print_group, sheet, src_id, log_date)'+
				' VALUES ( ?, ?, ?, ?)';
			params=[orderId, sheet, techId, dt];
			sequence.push(prepareStatement(sql,params));
			
			executeSequence(sequence);
		}

		public function remove(orderId:String, sheet:int, techId:int):void{
			var sequence:Array=[];
			var stmt:SQLStatement;
			var sql:String;
			var params:Array;
			var dt:Date=new Date();
			
			//log item
			sql='DELETE FROM tech_log'+
				' WHERE print_group=? AND sheet=? AND src_id=?';
			params=[orderId, sheet, techId];
			sequence.push(prepareStatement(sql,params));
			
			executeSequence(sequence);
		}

	}
}