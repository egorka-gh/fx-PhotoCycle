package com.photodispatcher.model.dao{
	import com.photodispatcher.model.TechLog;
	
	public class TechLogDAO extends BaseDAO{
		
		override protected function processRow(o:Object):Object{
			var a:TechLog = new TechLog();
			fillRow(o,a);
			return a;
		}

		public function addLog(item:TechLog):void{
			execute(
				'INSERT INTO tech_log (print_group, sheet, src_id, log_date)'+
				' VALUES (?,?,?,?)',
				[	item.print_group,
					item.sheet,
					item.src_id,
					item.log_date]
				,item);
		}

		public function getTechByOrder(orderId:String):Array{
			var sql:String='SELECT tl.* , tp.name tech_point_name, st.state tech_state, os.name tech_state_name'+
							' FROM print_group pg'+
							' INNER JOIN tech_log tl ON pg.id=tl.print_group'+  
							' INNER JOIN config.tech_point tp ON tl.src_id=tp.id'+
							' INNER JOIN config.src_type st ON tp.tech_type=st.id'+ 
							' INNER JOIN config.order_state os ON st.state = os.id'+
							' WHERE pg.order_id=?';
			runSelect(sql,[orderId]);
			return itemsArray;
		}
		

	}
}