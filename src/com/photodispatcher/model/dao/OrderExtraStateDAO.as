package com.photodispatcher.model.dao{
	import com.photodispatcher.model.OrderExtraState;

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

	}
}