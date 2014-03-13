package com.photodispatcher.model{
	
	import com.photodispatcher.model.dao.ContentFilterAliasDAO;
	import com.photodispatcher.model.dao.ContentFilterDAO;
	
	import mx.collections.ArrayList;
	
	import spark.components.gridClasses.GridColumn;

	public class ContentFilter extends DBRecord{

		private static var _filters:Array;
		public static function get filters():Array{
			if(!_filters) initFilters();
			return _filters;
		}

		private static function initFilters():void{
			var d:ContentFilterDAO= new ContentFilterDAO();
			var arr:Array=d.findAllArray(true);
			if(!arr) return;
			var f:ContentFilter;
			for each (f in arr){
				if(!f.loadAliases()) return;
			}
			_filters=arr;
		}

		
		//database props
		[Bindable]
		public var id:int;
		[Bindable]
		public var name:String;
		[Bindable]
		public var is_photo_allow:Boolean=false;
		[Bindable]
		public var is_retail_allow:Boolean=false;
		[Bindable]
		public var is_pro_allow:Boolean=false;
		[Bindable]
		public var is_alias_filter:Boolean=false;
		
		//childs
		public var aliases:Array;
	
		public static function gridColumns():ArrayList{
			var result:ArrayList= new ArrayList();
			var col:GridColumn;
			col= new GridColumn('id'); col.headerText='ID'; col.visible=false; result.addItem(col);
			col= new GridColumn('name'); col.headerText='Наименование'; result.addItem(col);
			return result;
		}
		
		public function loadAliases():Boolean{
			if (!is_alias_filter) return true;
			var d:ContentFilterAliasDAO= new ContentFilterAliasDAO();
			var arr:Array=d.findByFilter(id);
			var a:ContentFilterAlias;
			if(arr){
				aliases=[];
				for each(a in arr) aliases.push(a.alias);
				return true;
			}
			return false;
		}
		
		public function allowAlias(alias:int):Boolean{
			if(!is_alias_filter) return true;
			if(!aliases) return true; // not init??
			return aliases.indexOf(alias)!=-1;
		}

		public function allowPrintGroup(pg:PrintGroup):Boolean{
			if(!pg) return false;
			if(pg.book_type==0 && !is_photo_allow) return false;
			if(pg.bookTemplate && !allowAlias(pg.bookTemplate.book)) return false;
			return true; 
		}

	}
}