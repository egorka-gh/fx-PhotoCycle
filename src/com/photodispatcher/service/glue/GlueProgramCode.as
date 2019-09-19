package com.photodispatcher.service.glue
{
	import mx.collections.ArrayCollection;

	[Bindable]
	public class GlueProgramCode{

		public static function fromRaw(raw:Object):GlueProgramCode{
			var res:GlueProgramCode = new GlueProgramCode();
			res.code = raw.code;
			res.product = raw.product;
			if(!res.code || !res.product){
				return null;
			}
			return res;
		}

		public static function fromRawList(raw:Object):ArrayCollection{
			var res:ArrayCollection= new ArrayCollection();
			var c:GlueProgramCode;
			for each (var it:Object in raw){
				c = fromRaw(it);
				if (c){
					res.addItem(c);	
				}
			}
			return res;
		}
		
		public function GlueProgramCode(){
		}
		public var code:String;
		public var product:String;
	}
}