package com.photodispatcher.tech.picker{
	import com.photodispatcher.model.Layerset;
	import com.photodispatcher.model.SynonymCommon;
	import com.photodispatcher.model.dao.DictionaryCommonDAO;
	import com.photodispatcher.model.dao.LayersetDAO;
	import com.photodispatcher.util.ArrayUtil;
	
	import mx.collections.ArrayCollection;

	public class InterlayerSet{
		
		[Bindable]
		public var interlayers:ArrayCollection;

		private var _prepared:Boolean;
		private var synonymMap:Object;
		
		public function get prepared():Boolean{
			return _prepared;
		}
			
		public function InterlayerSet(){
			_prepared=init();
		}
		
		private function init():Boolean{
			//load
			var ilDao:LayersetDAO= new LayersetDAO();
			var arr:Array=ilDao.findAllArray(1,true);
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
			interlayers= new ArrayCollection(arr);
			return true;
		}
		
		public function getBySynonym(synonym:String):Layerset{
			if(!synonymMap || !synonym) return null;
			return (synonymMap[synonym] as Layerset);
		}
	}
}