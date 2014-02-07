package com.photodispatcher.tech.picker{
	import com.photodispatcher.model.Layerset;
	
	public class EndpaperSet extends InterlayerSet{
		
		public var emptyEndpaper:Layerset;
		
		public function EndpaperSet(){
			_prepared=init(2);
		}
		
		override protected function init(type:int):Boolean{
			var result:Boolean=super.init(type);
			var ls:Layerset;
			if(result){
				var arr:Array=layersets.source;
				for each(ls in arr){
					if (ls.is_passover){
						emptyEndpaper=ls;
						break;
					}
				}
			}
			if(!emptyEndpaper){
				emptyEndpaper= new Layerset();
				emptyEndpaper.is_passover=true;
				emptyEndpaper.name='Без форзаца';
				if(synonymMap) synonymMap[ls.name]=ls;
				if(layersets) layersets.addItem(ls); 
			}
			return result;
		}
		
		
	}
}