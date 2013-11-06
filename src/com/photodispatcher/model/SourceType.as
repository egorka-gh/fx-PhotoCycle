package com.photodispatcher.model{
	public class SourceType extends DBRecord{

		public static const SRC_PROFOTO:int=1;
		public static const SRC_FOTOKNIGA:int=4;
		public static const SRC_FBOOK:int=7;
		public static const SRC_FBOOK_MANUAL:int=11;
		
		public static const LAB_FUJI:int=2;
		public static const LAB_NORITSU:int=3;
		public static const LAB_NORITSU_NHF:int=8;
		public static const LAB_XEROX:int=5;
		public static const LAB_PLOTTER:int=6;
		public static const LAB_VIRTUAL:int=9;

		public static const TECH_PRINT:int=10;
		public static const TECH_FOLDING:int=12;
		public static const TECH_LAMINATION:int=13;

		//database props
		public var id:int;
		public var loc_type:int;
		public var name:String;
		public var state:int;
		public var book_part:int;
	}
}