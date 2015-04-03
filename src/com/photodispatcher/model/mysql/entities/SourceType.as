/**
 * Generated by Gas3 v2.3.2 (Granite Data Services).
 *
 * NOTE: this file is only generated if it does not exist. You may safely put
 * your custom code here.
 */

package com.photodispatcher.model.mysql.entities {

    [Bindable]
    [RemoteClass(alias="com.photodispatcher.model.mysql.entities.SourceType")]
    public class SourceType extends SourceTypeBase {
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
		public static const LAB_THERMO:int=23;
		
		public static const TECH_PRINT:int=300;//=10;
		public static const TECH_FOLDING:int=320;//12;
		public static const TECH_LAMINATION:int=330;//13;
		public static const TECH_PICKING:int=340;//14;
		public static const TECH_GLUING:int=350;//15;
		public static const TECH_BFOLDING:int=318;//16;
		public static const TECH_COVER_MADE:int=335;//17;
		public static const TECH_CUTTING:int=360;//18;
		public static const TECH_COVER_BLOK_PICKING:int=370;//19;
		public static const TECH_COVER_BLOK_JOIN:int=380;//20;
		public static const TECH_PRINT_POST:int=210;//21;
		public static const TECH_OTK:int=450;//22;
		
    }
}