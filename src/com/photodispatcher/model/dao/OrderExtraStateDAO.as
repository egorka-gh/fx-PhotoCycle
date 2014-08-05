package com.photodispatcher.model.dao{
	import com.photodispatcher.model.OrderExtraState;
	import com.photodispatcher.model.mysql.entities.SourceType;

	public class OrderExtraStateDAO extends BaseDAO{
		
		override protected function processRow(o:Object):Object{
			var a:OrderExtraState = new OrderExtraState();
			fillRow(o,a);
			return a;
		}

		public function getByOrder(orderId:String):Array{
			var sql:String='SELECT es.*, os.name state_name'+
							' FROM order_extra_state es'+
							' INNER JOIN config.order_state os ON os.id=es.state'+
							' WHERE es.id=?'+
							' ORDER BY IFNULL(es.state_date,es.start_date)';
			runSelect(sql,[orderId]);
			return itemsArray;
		}

		public function getOtkOrders():Array{
			var sql:String='SELECT es.*, os.name state_name, pg.book_num books, count(distinct tl.sheet) books_done'+
							' FROM config.src_type st'+
							' INNER JOIN order_extra_state es ON es.state=st.state AND es.state_date IS NULL'+
							' INNER JOIN config.order_state os ON os.id=es.state'+
							" LEFT OUTER JOIN print_group pg ON pg.id=es.id || '_1'"+     
							' LEFT OUTER JOIN config.tech_point tp ON tp.tech_type=st.id'+     
							' LEFT OUTER JOIN tech_log tl ON tl.src_id=tp.id AND tl.print_group=es.id AND tl.sheet!=0'+
							' WHERE st.id=?'+
							' GROUP BY es.id, es.sub_id'+ 
							' ORDER BY es.start_date';
			runSelect(sql,[SourceType.TECH_OTK]);
			return itemsArray;
		}

	}
}