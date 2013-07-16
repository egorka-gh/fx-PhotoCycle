package com.photodispatcher.util{
	public class UnitUtil{
		/**
		 * переводит миллиметры в пиксели для 300 dpi
		 */
		public static const MM2PIXELS_300:Number = 11.811;
		
		/**
		 * переводит миллиметры в пиксели для 300 dpi
		 */
		public static function mm2Pixels300(value:Number):int{
			if(value){
				return Math.ceil(value*MM2PIXELS_300);
			}
			return 0;
		}
	}
}