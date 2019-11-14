package com.photodispatcher.util{
	import com.adobe.serialization.json.JSONDecoder;
	import com.adobe.serialization.json.JSONEncoder;
	
	import flash.net.ObjectEncoding;
	import flash.net.registerClassAlias;
	import flash.utils.ByteArray;
	import flash.utils.describeType;

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
		
		/*
		simple mapping by property name
		expects simple vanilla object as source 
		maps all dynamic properties
		*/
		public static function dynamicToInstance( object:Object, instance:Object ):*{
			for(var key:String in object){
				if (instance.hasOwnProperty(key)){
					try{
						instance[key] = object[key]	
					}catch(error:Error){	
					}
				}
			}
		}

		/**
		 * Converts a plain vanilla object to be an instance of the class
		 * passed as the second variable.  This is not a recursive funtion
		 * and will only work for the first level of nesting.  When you have
		 * deeply nested objects, you first need to convert the nested
		 * objects to class instances, and then convert the top level object.
		 * 
		 * TODO: This method can be improved by making it recursive.  This would be 
		 * done by looking at the typeInfo returned from describeType and determining
		 * which properties represent custom classes.  Those classes would then
		 * be registerClassAlias'd using getDefinititonByName to get a reference,
		 * and then objectToInstance would be called on those properties to complete
		 * the recursive algorithm.
		 * 
		 * @param object The plain object that should be converted
		 * @param clazz The type to convert the object to
		 */
		public static function objectToInstance( object:Object, clazz:Class ):*
		{
			var bytes:ByteArray = new ByteArray();
			bytes.objectEncoding = ObjectEncoding.AMF0;
			
			// Find the objects and byetArray.writeObject them, adding in the
			// class configuration variable name -- essentially, we're constructing
			// and AMF packet here that contains the class information so that
			// we can simplly byteArray.readObject the sucker for the translation
			
			// Write out the bytes of the original object
			var objBytes:ByteArray = new ByteArray();
			objBytes.objectEncoding = ObjectEncoding.AMF0;
			objBytes.writeObject( object );
			
			// Register all of the classes so they can be decoded via AMF
			var typeInfo:XML = describeType( clazz );
			var fullyQualifiedName:String = typeInfo.@name.toString().replace( /::/, "." );
			registerClassAlias( fullyQualifiedName, clazz );
			
			// Write the new object information starting with the class information
			var len:int = fullyQualifiedName.length;
			bytes.writeByte( 0x10 );  // 0x10 is AMF0 for "typed object (class instance)"
			bytes.writeUTF( fullyQualifiedName );
			// After the class name is set up, write the rest of the object
			bytes.writeBytes( objBytes, 1 );
			
			// Read in the object with the class property added and return that
			bytes.position = 0;
			
			// This generates some ReferenceErrors of the object being passed in
			// has properties that aren't in the class instance, and generates TypeErrors
			// when property values cannot be converted to correct values (such as false
			// being the value, when it needs to be a Date instead).  However, these
			// errors are not thrown at runtime (and only appear in trace ouput when
			// debugging), so a try/catch block isn't necessary.  I'm not sure if this
			// classifies as a bug or not... but I wanted to explain why if you debug
			// you might seem some TypeError or ReferenceError items appear.
			var result:* = bytes.readObject();
			return result;
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