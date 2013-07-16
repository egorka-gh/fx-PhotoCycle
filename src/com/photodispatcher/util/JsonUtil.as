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