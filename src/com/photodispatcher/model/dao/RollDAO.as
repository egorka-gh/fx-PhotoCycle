package com.photodispatcher.model.dao{
	import com.photodispatcher.model.LabDevice;
	import com.photodispatcher.model.Roll;
	

	public class RollDAO extends BaseDAO{

		public function findAllArray(silent:Boolean=true):Array {
			var sql:String;
			sql='SELECT l.* FROM config.roll l ORDER BY l.width';
			runSelect(sql,null,silent );
			return itemsArray ;
		}

		override protected function processRow(o:Object):Object{
			var a:Roll= new Roll();
			fillRow(o,a);
			return a;
		}

	}
}