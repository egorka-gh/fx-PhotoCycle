package com.photodispatcher.model.dao{
	import com.photodispatcher.model.Suborder;
	
	public class SuborderDAO extends BaseDAO{
		
		public function SuborderDAO(){
			super();
		}
		
		override protected function processRow(o:Object):Object{
			var a:Suborder = new Suborder();
			fillRow(o,a);
			//don't set before a.state, u'l lost actual state_date
			if(o.state_date) a.state_date= new Date(o.state_date);
			
			return a;
		}
		
		public function getByOrder(orderId:String, extraInfo:Boolean=false):Array{
			var sql:String;
			sql='SELECT so.*, st.name src_type_name, bt.name proj_type_name';
			if(extraInfo) sql+=', oei.endpaper, oei.interlayer, oei.calc_type, oei.cover, oei.format, oei.corner_type, oei.kaptal';
			sql=sql+' FROM suborders so'+
					' INNER JOIN config.src_type st ON so.src_type=st.id'+
					' INNER JOIN config.book_type bt ON so.proj_type=bt.id';
			if(extraInfo) sql+=' LEFT OUTER JOIN order_extra_info oei ON so.id=oei.id';
			sql+=	' WHERE so.order_id=?';
			//trace(sql);
			var params:Array=[orderId];
			runSelect(sql,params);
			return itemsArray;
		}


	}
}