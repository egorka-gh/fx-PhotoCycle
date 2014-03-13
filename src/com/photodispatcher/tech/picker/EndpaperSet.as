package com.photodispatcher.tech.picker{
	import com.photodispatcher.model.Layerset;
	
	public class EndpaperSet extends InterlayerSet{
		
		public var emptyEndpaper:Layerset;

		
		public function EndpaperSet(){
			type=Layerset.LAYERSET_TYPE_ENDPAPER;
		}
		
		override public function init(techGroup:int):Boolean{
			var result:Boolean=super.init(techGroup);
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
				if(synonymMap) synonymMap[emptyEndpaper.name]=emptyEndpaper;
				if(layersets) layersets.addItem(emptyEndpaper); 
			}
			return result;
		}
		
		
	}
}