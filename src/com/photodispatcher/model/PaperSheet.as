package com.photodispatcher.model
{
	[Bindable]
	public class PaperSheet
	{
		
		public var name:String; 
		public var thickness:Number;
		public var height:Number;
		
		public function PaperSheet(name:String = "", thickness:Number = 0, height:Number = 0){
			this.name=name;
			this.thickness=thickness;
			this.height=height;
		}
	}
}