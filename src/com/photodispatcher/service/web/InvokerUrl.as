package com.photodispatcher.service.web{
	public class InvokerUrl{
		private var _url:String;
		private var _locUrl:String;

		public function InvokerUrl(url:String, locationUrl:String=null){
			_url=url;
			_locUrl=locationUrl;
		}

		public function get url():String{
			return _url;
		}
		public function get locationUrl():String{
			return _locUrl;
		}
	}
}