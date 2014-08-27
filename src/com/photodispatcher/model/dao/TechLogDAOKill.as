package com.photodispatcher.model.dao{
	import com.photodispatcher.model.mysql.entities.OrderState;
	import com.photodispatcher.model.mysql.entities.PrintGroup;
	import com.photodispatcher.model.mysql.entities.SourceType;
	import com.photodispatcher.model.mysql.entities.TechLog;
	
	public class TechLogDAOKill extends BaseDAO{
		
		override protected function processRow(o:Object):Object{
			var a:TechLog = new TechLog();
			//fillRow(o,a);
			return a;
		}

		public function addLog(item:TechLog):void{
			asyncFaultMode=FAULT_IGNORE;
			var sql:String='INSERT INTO tech_log (print_group, sheet, src_id, log_date) VALUES (?,?,?,?)';
			var params:Array=[item.print_group,
								item.sheet,
								item.src_id,
								item.log_date];
			executeSequence([prepareStatement(sql,params)]);
		}

		public function addPrintLog(item:TechLog):void{
			asyncFaultMode=FAULT_IGNORE;
			execute(
				'INSERT INTO tech_log (print_group, sheet, src_id, log_date)'+
				' SELECT pg.id, ?, ?, ?'+
					' FROM print_group pg'+ 
					' WHERE pg.id=? AND pg.state=?'+ 
				' UNION ALL'+
				' SELECT pg.id, ?, ?, ?'+
					' FROM print_group pg'+ 
					' INNER JOIN print_group_file pgf ON pg.id=pgf.print_group AND pgf.book_num=? AND pgf.page_num=?'+
					' WHERE pg.order_id=? AND pg.state=? AND pg.is_reprint=1 AND pg.id!=?'+
				' LIMIT 1',
				[	item.sheet,
					item.src_id,
					item.log_date,
					item.print_group,
					OrderState.PRN_PRINT,
					item.sheet,
					item.src_id,
					item.log_date,
					item.book_num,
					item.page_num,
					PrintGroup.orderIdFromId(item.print_group),
					OrderState.PRN_PRINT,
					item.print_group ]
				,item);
		}

		public function getTechByOrder(orderId:String):Array{
			/*
			var sql:String='SELECT tl.* , tp.name tech_point_name, st.state tech_state, os.name tech_state_name'+
							' FROM print_group pg'+
							' INNER JOIN tech_log tl ON pg.id=tl.print_group'+  
							' INNER JOIN config.tech_point tp ON tl.src_id=tp.id'+
							' INNER JOIN config.src_type st ON tp.tech_type=st.id'+ 
							' INNER JOIN config.order_state os ON st.state = os.id'+
							' WHERE pg.order_id=?'+
							' ORDER BY tl.log_date';
			*/
			var sql:String='SELECT tl.* , tp.name tech_point_name, st.state tech_state, os.name tech_state_name'+
							' FROM tech_log tl'+  
							' INNER JOIN config.tech_point tp ON tl.src_id=tp.id'+
							' INNER JOIN config.src_type st ON tp.tech_type=st.id'+ 
							' INNER JOIN config.order_state os ON st.state = os.id'+
							" WHERE tl.print_group=? OR tl.print_group LIKE ? || '_%'"+
							' ORDER BY tl.log_date';

			runSelect(sql,[orderId, orderId]);
			return itemsArray;
		}

		public function getOTKBooks(orderId:String):Array{
			var sql:String='SELECT tl.print_group, CAST((tl.sheet/100) as int)*100 sheet, tl.log_date log_date, tp.name tech_point_name'+
							' FROM tech_log tl'+  
							' INNER JOIN config.tech_point tp ON tl.src_id=tp.id AND tp.tech_type=?'+
							' WHERE tl.print_group=? AND tl.sheet>99'+
							' GROUP BY tl.print_group, CAST((tl.sheet/100) as int)*100'+
							' ORDER BY tl.sheet';
			
			runSelect(sql,[SourceType.TECH_OTK, orderId]);
			return itemsArray;
		}

		/*
		public function getTechByOrderAgg(orderId:String):Array{
			var sql:String=
				'SELECT tl.print_group, tl.src_id, tp.name tech_point_name, st.state tech_state, os.name tech_state_name,'+
				" strftime('%m/%d/%Y %H:%M:%S',min(tl.log_date)) log_date, strftime('%m/%d/%Y %H:%M:%S', max(sl.state_date)) complite_date" + 
				' FROM print_group pg' + 
				' INNER JOIN tech_log tl ON pg.id=tl.print_group' + 
				' INNER JOIN config.tech_point tp ON tl.src_id=tp.id' + 
				' INNER JOIN config.src_type st ON tp.tech_type=st.id' + 
				' INNER JOIN config.order_state os ON st.state = os.id' +
				' LEFT OUTER JOIN state_log sl ON pg.order_id=sl.order_id AND pg.id=sl.pg_id AND sl.state=st.state' +  
				' WHERE pg.order_id=?' +
				' GROUP BY tl.print_group, tp.name, st.state, os.name';
			runSelect(sql,[orderId]);
			return itemsArray;
		}
		*/

	}
}