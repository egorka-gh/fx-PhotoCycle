package com.photodispatcher.util{
	public class ArrayUtil{

		public static function searchItemIdx(propName:String, propValue:Object, array:Array, start:int = 0, end:int = -1):int {
			if(!array || array.length==0) return -1;
			var found:int = -1;
			if(end < 0) end = array.length;
			var a:Array = array.slice(start, end);
			a.some(function (element:Object, index:int, arr:Array):Boolean {
				var res:Boolean = (element.hasOwnProperty(propName) && element[propName] == propValue);
				if(res) found = index;
				return res;
			});
			return found;
		}

		public static function searchItem(propName:String, propValue:Object, array:Array, start:int = 0, end:int = -1):Object{
			var idx:int=searchItemIdx(propName, propValue, array, start, end);
			if(idx!=-1){
				return array[idx];
			}
			return null;
		}

		/**
		 * "вращает" массив
		 * [0,1,2,3,4,5] => (firstIndex = 4) => [4,5,0,1,2,3]
		 */
		public static function rotateArray(firstIndex:int, array:Array):Array {
			
			return array.slice(firstIndex).concat(array.slice(0,firstIndex));
			
		}

	}
}