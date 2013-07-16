package com.photodispatcher.model.dao{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.model.SourceType;
	
	import mx.collections.ArrayCollection;

	public class SourceTypeDAO extends BaseDAO{
		
		override protected function processRow(o:Object):Object{
			var a:SourceType= new SourceType();
			/*
			a.id=o.id;
			a.loc_type=o.loc_type;
			a.name=o.name;
			
			a.loaded = true;
			*/
			fillRow(o,a);
			return a;
		}
		
		public function findAll(locationType:int=1):ArrayCollection{
			var sql:String='SELECT st.* FROM config.src_type st WHERE st.loc_type = ?';
			runSelect(sql,[locationType]);
			//var res:ArrayCollection=getList(sql,[locationType]);
			return itemsList;
		}
	}
}