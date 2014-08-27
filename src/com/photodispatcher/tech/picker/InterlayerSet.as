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
			/*
			//load
			var ilDao:LayersetDAO= new LayersetDAO();
			var arr:Array=ilDao.findAllArray(type,true,techGroup);
			if(!arr) return false;
			var ls:Layerset;
			synonymMap=new Object;
			for each(ls in arr){
				ls.prepareTamplate();
				if(!ls.prepared) return false;
				//add to synonym map by set name
				synonymMap[ls.name]=ls;
			}
			//fill synonym map
			var ddao:DictionaryCommonDAO= new DictionaryCommonDAO();
			var sarr:Array=ddao.getLayersetSynonyms(-1,true);
			if(!sarr) return false;
			var s:SynonymCommon;
			for each(s in sarr){ 
				ls=ArrayUtil.searchItem('id',s.item_id,arr) as Layerset;
				if(ls){
					synonymMap[s.synonym]=ls;
				}
			}
			layersets= new ArrayCollection(arr);
			_prepared=true;
			return _prepared;
			*/
		}
		
		public function getBySynonym(synonym:String):Layerset{
			if(!synonymMap || !synonym) return null;
			return (synonymMap[synonym] as Layerset);
		}
	}
}