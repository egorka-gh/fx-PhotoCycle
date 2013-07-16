package com.photodispatcher.provider.fbook.download{
	public class DownloadErrorItem{
		public var id:String;
		public var content_type:String;
		public var path:String;
		public var err:int;
		public var used:int=0;
		private var _pages:Array=[];
		
		public function DownloadErrorItem(err:int){
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
	}
}