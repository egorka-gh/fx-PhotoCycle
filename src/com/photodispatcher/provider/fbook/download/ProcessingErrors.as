package com.photodispatcher.provider.fbook.download{
	public class ProcessingErrors{
		public static const DOWNLOAD_DOWNLOAD_ERROR:int = 1;
		public static const DOWNLOAD_EMPTY_RESPONCE_ERROR:int = 2;
		public static const DOWNLOAD_FILESYSTEM_ERROR:int = 3;
		public static const DOWNLOAD_FONT_ERROR:int = 4;
		public static const DOWNLOAD_TXT_RENDER_ERROR:int = 5;
		
		
		public static const FATAL_ERRORS:Array=[DOWNLOAD_EMPTY_RESPONCE_ERROR, DOWNLOAD_FILESYSTEM_ERROR, DOWNLOAD_FONT_ERROR];
		
		public static function isFatalError(err:int):Boolean{
			return FATAL_ERRORS.indexOf(err)!=-1;
		}
		
		public static function getErrorText(err:int):String{
			var res:String;
			switch(err){
				case DOWNLOAD_DOWNLOAD_ERROR:
					res='Ошибка загрузки элемента.';
					break;
				case DOWNLOAD_EMPTY_RESPONCE_ERROR:
					res='Ошибка загрузки элемента (неверный путь или ошибка доступа на сервере).';
					break;
				case DOWNLOAD_FILESYSTEM_ERROR:
					res='Ошибка записи файла.';
					break;
				case DOWNLOAD_FONT_ERROR:
					res='Ошибка загрузки фонта.';
					break;
				case DOWNLOAD_TXT_RENDER_ERROR:
					res='Ошибка подготовки текста.';
					break;
				default:
					res='Не известная ошибка #'+err.toString()+'.';
			}					
			return res;
		}
	}
}