package com.photodispatcher.model.dao{
	import com.photodispatcher.model.OrderExtraStateProlong;

	public class OrderExtraStateProlongDAOKill extends BaseDAO{

		override protected function processRow(o:Object):Object{
			var a:OrderExtraStateProlong = new OrderExtraStateProlong();
			fillRow(o,a);
			return a;
		}
		
		public function getByOrder(orderId:String):Array{
			var sql:String='SELECT es.*, os.name state_name'+
				' FROM order_exstate_prolong es'+
				' INNER JOIN config.order_state os ON os.id=es.state'+
				' WHERE es.id=?'+
				' ORDER BY es.state_date';
			runSelect(sql,[orderId]);
			return itemsArray;
		}

	}
}