package com.photodispatcher.tech.picker{
	import com.photodispatcher.model.Layerset;
	import com.photodispatcher.model.SynonymCommon;
	import com.photodispatcher.model.dao.DictionaryCommonDAO;
	import com.photodispatcher.model.dao.LayersetDAO;
	import com.photodispatcher.util.ArrayUtil;
	
	import mx.collections.ArrayCollection;

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
		
		public function init(techGroup:int):Boolean{
			_prepared=false;
			this.techGroup=techGroup;
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
		}
		
		public function getBySynonym(synonym:String):Layerset{
			if(!synonymMap || !synonym) return null;
			return (synonymMap[synonym] as Layerset);
		}
	}
}