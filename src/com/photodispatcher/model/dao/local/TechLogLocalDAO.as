package com.photodispatcher.model.dao.local{
	import com.photodispatcher.model.TechLogLocal;

	public class TechLogLocalDAO extends LocalDAO{

		override protected function processRow(o:Object):Object{
			var a:TechLogLocal= new TechLogLocal();
			fillRow(o,a);
			return a;
		}

		public function getByParentId(parentId:String):Array{
			var sql:String='SELECT * FROM tech_log WHERE print_group=?';
			runSelect(sql,[parentId]);
			return itemsArray;
		}

	}
}