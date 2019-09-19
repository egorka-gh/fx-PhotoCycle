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

		public static function loadList():ArrayCollection{
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

		public static function saveList(list:ArrayCollection):void{
			var so:SharedObject = SharedObject.getLocal('appProps','/');
			so.data.glueProxies=list.source;
			so.flush();
		}

		public static function save(gp: GlueProxyCfg):void{
			var so:SharedObject = SharedObject.getLocal('appProps','/');
			so.data.glueProxy=gp;
			so.flush();
		}

		public static function load():GlueProxyCfg{
			var so:SharedObject = SharedObject.getLocal('appProps','/');
			var res:GlueProxyCfg=fromRaw(so.data.glueProxy);
			if(!res){
				res= new GlueProxyCfg();
				res.port=8000;
			}
			return res;
		}

		public var label:String;
		public var ip:String;
		public var port:int=8000;
	}
}