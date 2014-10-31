package com.photodispatcher.util{
	import flash.filesystem.File;
	
	import mx.utils.StringUtil;

	public class StrUtil{
		
		/**
		 * расширение файла в нижнем регистре
		 */
		public static function getFileExtension(filename:String):String{
			if(!filename) return '';
			var extensionIndex:int = filename.lastIndexOf( '.' );
			if (extensionIndex==-1){
				//no ext
				return '';
			}
			var extension:String = filename.substr( extensionIndex + 1).toLowerCase();
			return extension; 
		}

		/**
		 *меняет расширение файла
		 */
		public static function setFileExtension(filename:String, ext:String):String{
			if(!filename) return '';
			var extensionIndex:int = filename.lastIndexOf( '.' );
			if (extensionIndex!=-1){
				//remove ext
				filename=filename.substring(0,extensionIndex);
			}
			filename=filename+'.'+ext;
			return filename; 
		}

		/**
		 *убирает расширение файла
		 */
		public static function removeFileExtension(filename:String):String{
			if(!filename) return filename;
			var extensionIndex:int = filename.lastIndexOf( '.' );
			if (extensionIndex!=-1){
				//remove ext
				filename=filename.substring(0,extensionIndex);
			}
			return filename; 
		}

		/**
		 *имя файла
		 */
		public static function getFileName(path:String):String{
			if(!path) return path;
			var extensionIndex:int = path.lastIndexOf( File.separator );
			if (extensionIndex!=-1){
				//remove ext
				path=path.substring(extensionIndex+1);
			}
			return path; 
		}

		/**
		 * Убирает из строки спец символы и всякую лабуду
		 * так что бы ее можно было использовать в качестве имени файла или папки
		 *   
		 * @param value
		 * @return 
		 * 
		 */
		public static function toFileName(value:String):String{
			if(!value) return value;
			//all scpecial to _
			var re:RegExp=/(http)|(www)|([!@#$%^&*(){}+'":|,[\]\\\/\s])/gi;
			var s:String=value.replace(re,'_');
			//remove more then 2 _
			re=/__+/g;
			s=s.replace(re,'_');
			//remove starting/ending . and _
			re=/(^_*\.*_*)|(_*\.*_*$)/g;
			s=s.replace(re,'');
			return s.replace(re,'');
		}

		/**
		 * добивает слева строку value символом pad, до количества симоволов len
		 *   
		 */
		public static function lPad(value:String,len:int=10, pad:String='0'):String{
			if(!value || value.length>=len) return value; 
			var result:String= StringUtil.repeat(pad,len)+value;
			return result.substr(-len);
		}

		public static function sheetName(book:int,sheet:int):String{
			return StrUtil.lPad(book.toString(),3)+'_'+StrUtil.lPad(sheet.toString(),2);
		}
		
		public static function contentIdToFileName(contentId:String):String{
			if(!contentId) return contentId;
			//namespaces to sub dirs sup:: -> sup\
			var s:String=contentId.replace('::',File.separator);
			return s;
		}

	}
}