package com.photodispatcher.model.dao{
	import com.photodispatcher.model.ContentFilterAlias;

	public class ContentFilterAliasDAO extends BaseDAO{

		override protected function processRow(o:Object):Object{
			var a:ContentFilterAlias = new ContentFilterAlias();
			fillRow(o,a);
			return a;
		}

		public function findByFilter(filter:int):Array{
			var sql:String;
			sql='SELECT l.*'+
				' FROM config.content_filter_alias l WHERE l.filter = ?';
			runSelect(sql,[filter],true);
			return itemsArray;
		}
	}
}