package com.photodispatcher.provider.fbook.makeup{
	import flash.filesystem.File;

	public class IMMsl{
		public var msl:XML;
		public var fileName:String;
		
		public function IMMsl(msl:XML,fileName:String=''){
			this.msl=msl;
			this.fileName=fileName;
		}
		
		public function getMslString():String{
			if(!msl) return '';
			return xmlToString(msl);
		}
		
		private function xmlToString(xml:XML):String{
			var str:String='';
			if(xml){
				str = IMScript.GM_XML_HEAD+xml.toXMLString();  
				//replace line end chars
				str = str.replace(/\n/g, File.lineEnding);
			}
			return str;
		}

	}
}