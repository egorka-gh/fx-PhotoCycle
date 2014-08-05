package com.photodispatcher.model{
	public class SourceTypeKill extends DBRecord{

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
		public static const TECH_PICKING:int=14;
		public static const TECH_GLUING:int=15;
		public static const TECH_BFOLDING:int=16;
		public static const TECH_COVER_MADE:int=17;
		public static const TECH_CUTTING:int=18;
		public static const TECH_COVER_BLOK_PICKING:int=19;
		public static const TECH_COVER_BLOK_JOIN:int=20;
		public static const TECH_PRINT_POST:int=21;
		public static const TECH_OTK:int=22;

		//database props
		public var id:int;
		public var loc_type:int;
		public var name:String;
		public var state:int;
		public var book_part:int;
	}
}