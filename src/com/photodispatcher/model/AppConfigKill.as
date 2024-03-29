package com.photodispatcher.model{
	[Bindable]
	public class AppConfigKill extends DBRecord{
		//database props
		public var id:String;
		public var wrk_path:String;
		public var monitor_interval:int;
		public var content_filter:int;
		
		//2013-07-05
		public var fbblok_font:int=0;
		public var fbblok_notching:int=0;
		public var fbblok_bar:int=0;
		public var fbblok_bar_offset:String='+0+0';
		
		public var fbcover_font:int=0;
		public var fbcover_notching:int=0;
		public var fbcover_bar:int=0;
		public var fbcover_bar_offset:String='+0+0';
		
		public var tech_bar:int=0;
		public var tech_bar_step:int=3;
		public var tech_bar_color:int=0;
		public var tech_bar_offset:String='+0+0';
		public var tech_add:int=0;
		

	}
}