package com.photodispatcher.tech.picker{
	import com.photodispatcher.model.mysql.DbLatch;
	import com.photodispatcher.model.mysql.entities.Layerset;
	import com.photodispatcher.model.mysql.services.TechPickerService;
	import com.photodispatcher.util.ArrayUtil;
	
	import flash.events.Event;
	
	import mx.collections.ArrayCollection;
	
	import org.granite.tide.Tide;

	public class InterlayerSet{
		
		[Bindable]
		public var layersets:ArrayCollection;

		protected var _prepared:Boolean;
		protected var synonymMap:Object;
		
		protected var type:int;
		protected var techGroup:int;
		
		public function get prepared():Boolean{
			return _prepared;
		}
			
		public function InterlayerSet(){
			type=Layerset.LAYERSET_TYPE_INTERLAYER;
		}
		
		public function init(techGroup:int):DbLatch{
			_prepared=false;
			this.techGroup=techGroup;
			
			var latch:DbLatch=new DbLatch();
			var svc:TechPickerService=Tide.getInstance().getContext().byType(TechPickerService,true) as TechPickerService;
			latch.addEventListener(Event.COMPLETE,onLoad);
			latch.addLatch(svc.loadLayersets(type, techGroup));
			latch.start();
			return latch;
		}
		protected function onLoad(evt:Event):void{
			var latch:DbLatch= evt.target as DbLatch;
			if(!latch) return;
			latch.removeEventListener(Event.COMPLETE,onLoad);
			layersets=latch.lastDataAC;
			if(!layersets) return;
			var ls:Layerset;
			//fill synonym map
			synonymMap=new Object;
			for each(ls in layersets){
				if(ls.synonyms){
					for each (var syn:String in ls.synonyms) synonymMap[syn]=ls;
				}
			}
			_prepared=true;
		}
		
		public function getBySynonym(synonym:String):Layerset{
			if(!synonymMap || !synonym) return null;
			return (synonymMap[synonym] as Layerset);
		}
	}
}