package com.photodispatcher.tech.picker{
	import com.photodispatcher.model.Endpaper;
	import com.photodispatcher.model.SynonymCommon;
	import com.photodispatcher.model.dao.DictionaryCommonDAO;
	import com.photodispatcher.model.dao.EndpaperDAO;
	import com.photodispatcher.util.ArrayUtil;
	
	import mx.collections.ArrayCollection;

	public class EndpaperSet{
		
		[Bindable]
		public var enpapers:ArrayCollection;

		private var synonymMap:Object;
		
		private var emptyEp:Endpaper;
		public function get emptyEndpaper():Endpaper{
			return emptyEp;
		}

		private var _prepared:Boolean;
		public function get prepared():Boolean{
			return _prepared;
		}

		public function EndpaperSet(){
			_prepared=init();	
		}
		
		private function init():Boolean{
			//get endpapers
			var dao:EndpaperDAO= new EndpaperDAO();
			var epArr:Array= dao.findAllArray(true);
			if(!epArr) return false;

			synonymMap=new Object;
			var ep:Endpaper;
			for each(ep in epArr){
				//add to synonym map by name
				synonymMap[ep.name]=ep;
				if(ep.id==0) emptyEp=ep;
			}

			//get synonyms
			var sdao:DictionaryCommonDAO= new DictionaryCommonDAO();
			var syArr:Array=sdao.getEndpaperSynonyms(-1,true);
			if(!syArr) return false;
			var s:SynonymCommon;
			for each(s in syArr){ 
				ep=ArrayUtil.searchItem('id',s.item_id,epArr) as Endpaper;
				if(ep){
					synonymMap[s.synonym]=ep;
				}
			}
			enpapers= new ArrayCollection(epArr);
			return true;
		}
		
		public function checkSynonym(synonym:String):Boolean{
			if(!synonym) return true;
			return synonymMap.hasOwnProperty(synonym);
		}

		public function getBySynonym(synonym:String):Endpaper{
			if(!synonym || !synonymMap) return emptyEp;
			return synonymMap.hasOwnProperty(synonym)?(synonymMap[synonym] as Endpaper):null;
		}
		
	}
}