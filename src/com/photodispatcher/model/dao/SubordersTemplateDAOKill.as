package com.photodispatcher.model.dao{
	import com.photodispatcher.model.SubordersTemplate;

	public class SubordersTemplateDAOKill extends BaseDAO{

		override protected function processRow(o:Object):Object{
			var a:SubordersTemplate = new SubordersTemplate();
			fillRow(o,a);
			return a;
		}
		
		public function findAllArray():Array{
			var sql:String='SELECT * FROM config.suborders_template';
			runSelect(sql,[],true);
			var res:Array=itemsArray;
			return res;
		}

	}
}