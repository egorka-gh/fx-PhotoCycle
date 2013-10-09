package com.photodispatcher.view{
	[Bindable]
	public class PhotoSizeAccum	{
		
		public var caption:String='';
		
		private var _size:int=0;
		public function get size():int{
			return _size;
		}
		public function set size(value:int):void{
			_size = value;
			caption=_size.toString();
		}

		public var paper_id:int=0;
		public var paper:String='';
		public var pg_num:int=0;
		public var file_num:int=0;
		public var len:int=0;
		public var items:Array=[];
		
	}
}