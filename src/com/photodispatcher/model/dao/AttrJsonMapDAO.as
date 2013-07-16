package com.photodispatcher.model.dao{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.model.AttrJsonMap;
	
	public class AttrJsonMapDAO extends BaseDAO {
		private static var jMap:Object; 
		public static function getOrderJson(sourceType:int):Array{
			if(!jMap) jMap=new Object();
			var arr:Array=jMap[sourceType.toString()] as Array;
			if(!arr){
				//load
				var dao:AttrJsonMapDAO= new AttrJsonMapDAO();
				arr=dao.getOrderMapBySourceType(sourceType);
				if(arr) jMap[sourceType.toString()]=arr;
			}
			return arr;
		}

		/**
		 * 
		 * @param sourceType
		 * @return array of AttrJsonMap 
		 * 
		 */
		private function getOrderMapBySourceType(sourceType:int,silent:Boolean=true):Array{
			runSelect('SELECT jm.json_key, at.field, at.list, at.persist'+
									' FROM config.attr_json_map jm INNER JOIN config.attr_type at ON jm.attr_pt=at.id'+
									' WHERE jm.src_type=? AND at.attr_fml=2',[sourceType],silent);
			return itemsArray;
		}

		override protected function processRow(o:Object):Object{
			var a:AttrJsonMap=new AttrJsonMap();
			a.attr_pt=o.attr_pt;
			a.field=o.field;
			a.json_key=o.json_key;
			a.list=o.hasOwnProperty('list')?(o.list=='1'):false;
			a.src_type=o.src_type;
			a.persist=o.hasOwnProperty('persist')?(o.persist=='1'):false;
			return a;
		}
	}
}