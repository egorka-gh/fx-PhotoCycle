package com.photodispatcher.service.glue
{
	import flash.net.SharedObject;
	
	import mx.collections.ArrayCollection;

	[Bindable]
	public class GlueProxyCfg
	{
		
		public static function fromRaw(raw:Object):GlueProxyCfg{
			if(!raw) return null;
			var res: GlueProxyCfg= new GlueProxyCfg();
			res.label=raw.label;
			res.ip=raw.ip;
			res.port=8000;
			return res;
		}

		public static function load():ArrayCollection{
			var res:ArrayCollection= new ArrayCollection();
			var so:SharedObject = SharedObject.getLocal('appProps','/');
			var items=so.data.glueProxies;
			if(items){
				for each (var it:Object in items){
					var gp:GlueProxyCfg=fromRaw(it);
					if(gp) res.addItem(gp);
				}
			}
			if(res.length==0){
				if(so.data.glueIP){
					var g: GlueProxyCfg= new GlueProxyCfg();
					g.ip=so.data.glueIP;
					g.port=8000;
					res.addItem(g);
				}
			}
			return res;
		}

		public static function save(list:ArrayCollection):void{
			var so:SharedObject = SharedObject.getLocal('appProps','/');
			so.data.glueProxies=list.source;
			so.flush();
		}

		public var label:String;
		public var ip:String;
		public var port:int=8000;
	}
}