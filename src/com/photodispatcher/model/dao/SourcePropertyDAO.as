package com.photodispatcher.model.dao{
	import com.photodispatcher.model.SourceProperty;

	public class SourcePropertyDAO extends BaseDAO{

		override protected function processRow(o:Object):Object{
			var a:SourceProperty= new SourceProperty();
			a.name=o.name;
			a.value=o.value;
			
			a.loaded = true;
			return a;
		}

		public function sourceTypePropertyArr(src_type:int,silent:Boolean=true):Array{
			var sql:String='SELECT p.name, pv.value' +
							' FROM config.src_type_prop_val pv INNER JOIN config.src_type_prop p ON pv.src_type_prop = p.id' +
							' WHERE pv.src_type = ?';
			runSelect(sql,[src_type],silent);
			var res:Array=itemsArray;
			return res;
		}
	
	}
}