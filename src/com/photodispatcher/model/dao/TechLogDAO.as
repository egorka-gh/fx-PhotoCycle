package com.photodispatcher.model.dao{
	import com.photodispatcher.model.TechLog;
	
	public class TechLogDAO extends BaseDAO{
		
		override protected function processRow(o:Object):Object{
			var a:TechLog = new TechLog();
			fillRow(o,a);
			return a;
		}

		public function addLog(item:TechLog):void{
			/*
			execute(
				'INSERT INTO tech_log (pgfile_id, src_id, log_date)'+
				' SELECT pgf.id,?,? FROM print_group_file pgf WHERE pgf.print_group=? AND pgf.book_num=? AND pgf.page_num=?',
				[	item.src_id,
					item.log_date,
					item.print_group,
					item.book_num,
					item.page_num]
				,item);
			*/
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
			var sql:String='SELECT tl.* , s.name tech_point_name, st.state tech_state, os.name tech_state_name'+
							' FROM print_group pg'+
							' INNER JOIN tech_log tl ON pg.id=tl.print_group'+  
							' INNER JOIN config.sources s ON tl.src_id=s.id'+
							' INNER JOIN config.src_type st ON s.type_id=st.id'+ 
							' INNER JOIN config.order_state os ON st.state = os.id'+
							' WHERE pg.order_id=?';
			runSelect(sql,[orderId]);
			return itemsArray;
		}
		

	}
}