package com.photodispatcher.model{
	import com.photodispatcher.model.dao.SourcePropertyDAO;
	
	public class SourceProperty  extends DBRecord{
		
		public static const HF_PREFIX:String='hotFolderPrefix';
		public static const HF_IMG_FOLDER:String='imageSubFolder';
		public static const HF_SUFIX_NOREADY:String='hotFolderSufixNotReady';
		public static const HF_SUFIX_READY:String='hotFolderSufixtReady';
		public static const PRN_SCRIPT_FILE:String='printScriptFileName';
		public static const PRN_SCRIPT_END_FILE:String='printEndFileName';
		public static const PRN_SCRIPT_HEADER:String='printScriptHeader';
		public static const PRN_SCRIPT_BODY1:String='printScriptBody01';
		public static const PRN_SCRIPT_BODY2:String='printScriptBody02';
		public static const LAB_ICON:String='labLogo';

		private static var srcTypeMap:Object;
		
		public static function getProperty(sourceType:int,name:String):String{
			if(!srcTypeMap) srcTypeMap= new Object();
			var propMap:Object;
			if (!srcTypeMap.hasOwnProperty(sourceType.toString())){
				var dao:SourcePropertyDAO= new SourcePropertyDAO();
				var a:Array=dao.sourceTypePropertyArr(sourceType);
				if(a){
					propMap= new Object();
					var p:SourceProperty;
					for each(var o:Object in a){
						p=o as SourceProperty;
						if(p) propMap[p.name]=p.value;
					}
					srcTypeMap[sourceType.toString()]=propMap;
				}
			}else{
				propMap=srcTypeMap[sourceType.toString()];
			}
			var result:String;
			if(propMap) result=propMap[name];	
			return result?result:''; 	
		}
		
		//database props
		public var name:String;
		public var value:String;
		
	}
}