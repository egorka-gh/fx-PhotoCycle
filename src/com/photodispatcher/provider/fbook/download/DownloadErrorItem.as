package com.photodispatcher.provider.fbook.download{
	public class DownloadErrorItem{
		public var id:String;
		public var content_type:String;
		public var path:String;
		public var err:int;
		public var used:int=0;
		private var _pages:Array=[];
		
		public function DownloadErrorItem(err:int=0){
			this.err=err;
		}
		
		public function usedOnPage(page:int):void{
			used++;
			if (_pages.indexOf(page)==-1) _pages.push(page);
		}
		
		public function get pageList():String{
			if(_pages){
				return _pages.join(', ');
			}
			return '';
		}
		
		public function toRaw():Object{
			var raw:Object= new Object;
			
			raw.id=id;
			raw.content_type=content_type;
			raw.path=path;
			raw.err=err;
			raw.used=used;
			raw.pages=_pages;
			
			return raw;
		}

		public static function fromRaw(raw:Object):DownloadErrorItem{
			if(!raw) return null;
			var errItem:DownloadErrorItem= new DownloadErrorItem();

			errItem.id=raw.id;
			errItem.content_type=raw.content_type;
			errItem.path=raw.path;
			errItem.err=raw.err;
			errItem.used=raw.used;
			errItem._pages=raw.pages;

			return errItem;
		}

	}
}