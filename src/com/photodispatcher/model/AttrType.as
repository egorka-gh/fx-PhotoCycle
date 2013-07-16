package com.photodispatcher.model{
	import com.photodispatcher.model.dao.AttrTypeDAO;
	
	import flash.text.ReturnKeyLabel;

	public class AttrType extends DBRecord{
		//database props
		public var id:int;
		public var attr_fml:int;
		public var name:String;
		public var field:String;
		public var list:Boolean;
		public var persist:Boolean;
		
		
		private static var printAttrs:Array;
		
		private static function initPrintAttrs():void{
			var dao:AttrTypeDAO= new AttrTypeDAO();
			printAttrs=dao.findAll();
		}

		public static function getPrintAttrs():Array{
			if(!printAttrs){
				initPrintAttrs();
			}
			return printAttrs;
		}
	}
}