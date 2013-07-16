package com.photodispatcher.model.dao{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.model.AttrType;
	
	public class AttrTypeDAO extends BaseDAO{
		override protected function processRow(o:Object):Object{
			var a:AttrType= new AttrType();
			a.id=o.id;
			a.name=o.name;
			a.attr_fml=o.attr_fml;
			a.field=o.field;
			a.list=o.list=='1';
			a.persist= o.persist==1;
			
			a.loaded = true;
			return a;
		}

		public function findAll(attrFml:int=1,list:int=1):Array{
			var where:String;
			var params:Array=[];
			if (attrFml!=-1){
				where=' AND at.attr_fml = ?';
				params.push(attrFml);
			}
			if (list!=-1){
				where=where+' AND at.list = ?';
				params.push(list?'1':'0');
			}
			
			var sql:String='SELECT at.* FROM config.attr_type at WHERE at.persist=1'+where;
			runSelect(sql,params);
			return itemsArray;
		}

	}
}