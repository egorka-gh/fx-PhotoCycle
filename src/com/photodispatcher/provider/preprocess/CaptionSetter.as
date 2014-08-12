package com.photodispatcher.provider.preprocess{
	import com.photodispatcher.model.mysql.entities.Order;
	import com.photodispatcher.model.mysql.entities.PrintGroup;
	import com.photodispatcher.model.mysql.entities.PrintGroupFile;
	import com.photodispatcher.util.StrUtil;
	
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;

	public class CaptionSetter{
		
		public static const RELATIONS_FILE_NAME:String= 'relations.txt';
		//public static const CAPTION_MAX_LEN:int=12;
		
		public static function restoreFileCaption(order:Order, rootFolder:String):void{
			if(!order || !rootFolder || !order.printGroups || order.printGroups.length==0) return;
			var orderFolder:File;
			try{
				orderFolder=new File(rootFolder);
			}catch(err:Error){
				return;
			}
			if(!orderFolder || !orderFolder.exists || !orderFolder.isDirectory) return;
			orderFolder=orderFolder.resolvePath(order.ftp_folder);
			if(!orderFolder || !orderFolder.exists || !orderFolder.isDirectory) return;
				
			var pg:PrintGroup;
			for each(pg in order.printGroups){
				restorePgFilesCaption(pg, orderFolder);
			}
		}
		
		private static function restorePgFilesCaption(pg:PrintGroup, orderFolder:File):void{
			if(!pg || pg.book_type!=0) return;
			if(!pg.files || pg.files.length==0) return;
			
			//var pgfs:Array=pg.files;
			var pgf:PrintGroupFile;
			
			
			var pgFolder:File=orderFolder.resolvePath(pg.path);
			if(!pgFolder.exists || !pgFolder.isDirectory) return;
			var relationsFile:File=pgFolder.resolvePath(RELATIONS_FILE_NAME);
			if(!relationsFile.exists || relationsFile.isDirectory) return;
			
			//read relations.txt
			var txt:String;
			try{
				var fs:FileStream=new FileStream();
				fs.open(relationsFile,FileMode.READ);
				txt=fs.readUTFBytes(fs.bytesAvailable);
				fs.close();
			} catch(err:Error){
				return;
			}
			
			/*
			0000 - DSC_0059.JPG 
			0001 - DSC_0286.JPG 
			*/
			var re:RegExp;
			//remove spaces
			re=new RegExp(' ','g');
			txt=txt.replace(re, '');
			//split by line ending
			re=new RegExp(File.lineEnding,'g');
			txt=txt.replace(re, '\n');
			var lines:Array=txt.split('\n');
			if(!lines || lines.length==0) return;
			var line:String;
			var idx:int;
			var captionMap:Object=new Object();
			var key:String;
			var value:String;
			//build caption map
			for each(line in lines){
				if(line){
					idx=line.indexOf('-');
					if(idx!=-1){
						key=line.substring(0,idx);
						value=line.substr(idx+1);
						if(key && value){
							captionMap[key]=value;
						}
					}
				}
			}
			/*
			re=/[^a-z0-9\-_.,]/gi;
			var caption:String;
			*/
			//set caption
			for each(pgf in pg.files){
				if(pgf){
					key=StrUtil.getFileName(pgf.file_name);
					key=StrUtil.removeFileExtension(key);
					idx=key.indexOf('_');
					if(idx!=-1){
						key=key.substr(idx+1);
					}
					if(key){
						value=captionMap[key];
						if(value){
							/*
							caption=value.substr(0,CAPTION_MAX_LEN).replace(re,'X');
							pgf.caption=caption;
							*/
							pgf.caption=value;
						}
					}
				}
			}
		}
		
	}
}