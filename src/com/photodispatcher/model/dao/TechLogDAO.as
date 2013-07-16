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
				'INSERT INTO tech_log (pgfile_id, src_id, log_date)'+
				' SELECT pgf.id,?,? FROM print_group_file pgf WHERE pgf.print_group=? AND pgf.book_num=? AND pgf.page_num=?',
				[	item.src_id,
					item.log_date,
					item.print_group,
					item.book_num,
					item.page_num]
				,item);
		}

	}
}