package com.photodispatcher.provider.fbook{
	public class TripleState	{
		public static const TRIPLE_STATE_ERR:int=-1;
		public static const TRIPLE_STATE_NON:int=0;
		public static const TRIPLE_STATE_WARNING:int=1;
		public static const TRIPLE_STATE_OK:int=2;
		
		public static function getMinState(states:Array):int{
			if(!states || states.length==0){
				return TRIPLE_STATE_NON;
			}
			var result:int=0;
			var i:int;
			for each (i in states){
				result=Math.min(i,result);
			}
			if(result<TRIPLE_STATE_ERR) result=TRIPLE_STATE_ERR; 	
			if(result>TRIPLE_STATE_OK) result=TRIPLE_STATE_OK;
			return result;
		}
	}
}