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

		public static function fromRawList(raw:Object):Array{
			var res:Array= [];
			var c:GlueProgramCode;
			for each (var it:Object in raw){
				c = fromRaw(it);
				if (c){
					res.push(c);	
				}
			}
			return res;
		}
		
		public static function compactCodes(codes:Array):Array{
			var arr:Array=[];
			var pattern:RegExp = /^\d{2}$/;
			for each (var it:GlueProgramCode in codes){
				if(it && it.code && it.product && pattern.exec(it.code)) arr.push(it);
			}
			return arr;
		}

		
		public function GlueProgramCode(){
		}
		public var code:String;
		public var product:String;
	}
}