package com.photodispatcher.util{
	import com.adobe.serialization.json.JSONDecoder;
	import com.adobe.serialization.json.JSONEncoder;

	public class JsonUtil{
		
		public static function encode( value:Object ):String
		{	
			return new JSONEncoder( value ).getString();
		}
		
		
		public static function decode( text:String, strict:Boolean = true):*
		{	
			return new JSONDecoder( text, strict ).getValue();
		}
		
		
		//calc_data.=>type:cover.value
		//calc_data indexed array
		//=>type:cover - search in array object vs proverty type==cover
		//.value - gets from founded object property value
		public static function getRawVal(key:String, jo:Object):Object{
			if(!key) return null; 
			var path:Array=key.split('.');
			var value:Object=jo;
			var obj:Object;
			
			for each(var subkey:String in path){
				obj=searchRawValInArray(subkey,value);
				if(obj){
					value=obj;
				}else{
					if (value.hasOwnProperty(subkey)){
						value=value[subkey];
					}else{
						return null;
					}
				}
			}
			if (value!=jo){
				return value;
			}else{
				return null;
			}
		}
		
		private static function searchRawValInArray(searchKey:String, array:Object):Object{
			if(!searchKey || searchKey.substr(0,2)!='=>') return null;
			searchKey=searchKey.substr(2);
			if(!searchKey) return null;
			var arr:Array= (array as Array);
			if(!arr || arr.length==0) return null;
			var pArr:Array=searchKey.split(':');
			if (pArr.length!=2) return null;
			var key:String=pArr[0];
			var val:String=pArr[1];
			var o:Object;
			for each(o in arr){
				if(o.hasOwnProperty(key) && o[key]==val){
					return o;
				}
			}
			return null;
		}
		
		
		public static function parseDate(s:String):Date{
			//json date, parsed as "2012-05-17 15:52:08"
			var d:Date=new Date();
			if(!s) return d;
			var a1:Array=s.split(' ');
			if(!a1 || a1.length!=2) return d;
			var a2:Array=(a1[0] as String).split('-');
			if(!a2 || a2.length!=3) return d;
			var a3:Array=(a1[1] as String).split(':');
			if(!a3 || a3.length<3){
				try{
					d= new Date(int(a2[0]), int(a2[1])-1, int(a2[2]), 0, 0, 0);
				}catch(error:Error){	
					d=new Date();
				}
			}else{
				try{
					d=new Date(int(a2[0]), int(a2[1])-1, int(a2[2]), int(a3[0]), int(a3[1]), int(a3[2]));
				}catch(error:Error){	
					d=new Date();
				}
			}
			return d;
		}

		
		/**
		 * Использует нативную библиотеку FP 11.2
		 * @param value
		 * @param replacer
		 * @param space
		 * @return 
		 * 
		 */
		/*
		public static function encodeNative( value:Object , replacer:* = null, space:* = null):String
		{	
			//return new JSONEncoder( o ).getString();
			return JSON.stringify(value, replacer, space);
		}
		*/
		/**
		 * Использует нативную библиотеку FP 11.2
		 * @param text
		 * @param reviver
		 * @return 
		 * 
		 */
		/*
		public static function decodeNative( text:String, reviver:Function = null):*
		{	
			//return new JSONDecoder( s, strict ).getValue();
			return JSON.parse(text, reviver);
		}
		*/
		
	}
}