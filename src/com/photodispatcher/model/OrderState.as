package com.photodispatcher.model{
	public class OrderState extends DBRecord{
		//err state
		public static const ERR_PRINT_POST:int=-300;
		public static const ERR_PRINT_POST_FOLDER_NOT_FOUND:int=-301;
		public static const ERR_PRINT_LAB_FOLDER_NOT_FOUND:int=-302;
		public static const ERR_READ_LOCK:int=-309;
		public static const ERR_WRITE_LOCK:int=-310;
		public static const ERR_FTP:int=-311;
		public static const ERR_WEB:int=-312;
		public static const ERR_FILE_SYSTEM:int=-314;
		public static const ERR_PREPROCESS:int=-315;
		public static const ERR_PREPROCESS_REMOTE:int=-316;
		public static const ERR_LOAD_REMOTE:int=-317;//04.04.2013
		public static const ERR_GET_PROJECT:int=-318;//22.05.2013
		
		//flow state
		public static const WAITE_FTP:int=100;
		public static const FTP_FORWARD:int=101;
		public static const FTP_WEB_CHECK:int=105;
		public static const FTP_WEB_OK:int=106;
		public static const FTP_WAITE_SUBORDER:int=107; //22.05.13
		public static const FTP_GET_PROJECT:int=108; //22.05.13
		public static const FTP_LIST:int=109;
		public static const FTP_LOAD:int=110;
		public static const FTP_DEPLOY:int=111;//04.04.2013
		public static const FTP_REMOTE:int=112;//04.04.2013
		public static const FTP_COMPLETE:int=113;//04.04.2013
		public static const PREPROCESS_WAITE:int=114;
		public static const PREPROCESS_RESIZE:int=115;
		public static const PREPROCESS_PDF:int=120;
		public static const PREPROCESS_DEPLOY:int=124;
		public static const PREPROCESS_REMOTE:int=125;
		public static const PREPROCESS_COMPLETE:int=140;
		public static const PRN_WAITE_ORDER_STATE:int=199;
		public static const PRN_WAITE:int=200;
		public static const PRN_QUEUE:int=203;
		public static const PRN_WEB_CHECK:int=205;
		public static const PRN_WEB_OK:int=206;
		public static const PRN_POST:int=210;
		public static const PRN_CANCEL:int=215;
		public static const PRN_POST_FORWARD:int=220;
		public static const PRN_PRINT:int=250;
		public static const PRN_COMPLETE:int=300;
		public static const CANCELED_OLD:int=310;
		public static const TECH_FOLDING:int=320;
		public static const TECH_LAMINATION:int=330;
		public static const TECH_PICKING:int=340;
		public static const TECH_GLUING:int=350;
		public static const CANCELED:int=510;

		//database props
		[Bindable]
		public var id:int;
		[Bindable]
		public var name:String;
		[Bindable]
		public var runtime:int;
		[Bindable]
		public var extra:int;

	}
}