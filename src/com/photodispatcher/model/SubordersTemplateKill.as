package com.photodispatcher.model{
	import com.photodispatcher.model.dao.SubordersTemplateDAO;
	import com.photodispatcher.model.mysql.entities.OrderState;

	public class SubordersTemplateKill extends DBRecord	{
		//database props
		public var id:int;
		public var src_type:int;
		public var folder:String;
		public var sub_src_type:int;
		
		private static var templates:Object;

		public static function translatePath(path:String, sourceType:int):SubordersTemplate{
			if (!templates){
				//init map by sorce_type~folder
				var dao:SubordersTemplateDAO= new SubordersTemplateDAO();
				var a:Array=dao.findAllArray();
				if(a==null) throw new Error('Блокировка чтения (SubordersTemplate.translatePath)',OrderState.ERR_READ_LOCK);
				templates=new Object();
				var t:SubordersTemplate;
				var key:String;
				for each(t in a){
					if(t){
						templates[t.src_type.toString()+'~'+t.folder]=t;
					}
				}
			}
			return templates[sourceType.toString()+'~'+path];
		}
	}
}