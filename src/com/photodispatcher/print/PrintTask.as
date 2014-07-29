package com.photodispatcher.print{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.model.BookSynonym;
	import com.photodispatcher.model.OrderState;
	import com.photodispatcher.model.PrintGroup;
	import com.photodispatcher.model.PrintGroupFile;
	import com.photodispatcher.model.mysql.entities.Source;

	import com.photodispatcher.model.SourceProperty;
	import com.photodispatcher.model.SourceType;
	import com.photodispatcher.util.StrUtil;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	
	import spark.formatters.DateTimeFormatter;
	
	[Event(name="complete", type="flash.events.Event")]
	public class PrintTask extends EventDispatcher{
		public static const KEY_DATE:String='print_date';
		public static const KEY_ORDER_ID:String='order_id';
		public static const KEY_GROUP_ID:String='group_id';
		public static const KEY_JOB_ID:String='job_id';
		public static const KEY_CHANNEL:String='prt_code';
		public static const KEY_IMG_COUNT:String='img_cnt';

		public static const KEY_IMG_NUM:String='img_num';
		public static const KEY_IMG_FILE:String='img_file';
		public static const KEY_IMG_PRT_QTTY:String='prt_qty';
		public static const KEY_IMG_CORRECTION:String='img_corr';
		public static const KEY_IMG_RESIZE:String='img_resize';
		public static const KEY_IMG_PAPE:String='img_pape';
		public static const KEY_IMG_FORMAT:String='img_format';
		public static const KEY_IMG_WIDTH:String='img_width';
		public static const KEY_IMG_LENGTH:String='img_length';
		public static const KEY_IMG_BACKPRINT_LINE2:String='img_backprint2';
		public static const CAPTION_MAX_LEN:int=12;

		//4 fuji only
		private static const FUJI_RESIZES:Object={'0':'NONE','18':'NONE','19':'FILLIN','20':'FITIN'};
		private static const FUJI_CORRECTIONS:Object={'16':'TRUE','17':'FALSE','0':'FALSE'};

		//4 noritsu_nhf
		private static const NORITSU_NHF_RESIZES:Object={'0':'Real','19':'Crop','20':'Shrink'};
		public static const NORITSU_NHF_PAPE:Object={'10':'1','11':'2','12':'4','13':'3'};//{'10':'Глянцевая','11':'Матовая','12':'Металлик','13':'Шелк'};
		private static const NORITSU_NHF_IMG_FORMAT:Object={'jpg':'Jpeg','bmp':'bmp','tiff':'tiff','png':'png'};
		
		public var hasErr:Boolean=false;
		public var errMsg:String;
		
		public var printGrp:PrintGroup;
		public var revers:Boolean;
		private var lab:LabBase;
		
		private var dstFolder:File;
		private var srcFolder:File;
		private var currCopyIdx:int=0;
		private var currCopyFile:File;
		
		private var printContext:Object;
		private var printScript:String='';
		private var printBody01:String='';
		private var printBody02:String='';
		private var printBodyTemp01:String;
		private var printBodyTemp02:String;
		

		public function PrintTask(printGroup:PrintGroup, lab:LabBase, revers:Boolean){
			super(null);
			this.printGrp=printGroup;
			this.lab=lab;
			this.revers=revers;
			printContext= new Object();
			printContext[KEY_ORDER_ID]=printGrp.order_id;
			printContext[KEY_GROUP_ID]=printGrp.humanId;
			printContext[KEY_JOB_ID]=printGrp.numericId;
			//printContext[KEY_IMG_COUNT]=printGrp.files.length;
			printContext[KEY_IMG_COUNT]=printGrp.printFiles.length;
			var dtFmt:DateTimeFormatter=new DateTimeFormatter();
			//4 noritsu
			dtFmt.dateTimePattern='yyyy:MM:dd:HH:mm:ss';//2012:07:13:15:02:51
			printContext[KEY_DATE]=dtFmt.format(new Date());
			switch(lab.src_type){
				case SourceType.LAB_FUJI:
					//4 fuji
					printContext[KEY_IMG_CORRECTION]=FUJI_CORRECTIONS[printGrp.correction.toString()];
					printContext[KEY_IMG_RESIZE]=FUJI_RESIZES[printGrp.cutting.toString()];
					break;
				case SourceType.LAB_NORITSU_NHF:
					//4 noritsu_nhf
					printContext[KEY_IMG_RESIZE]=NORITSU_NHF_RESIZES[printGrp.cutting.toString()];
					printContext[KEY_IMG_PAPE]=NORITSU_NHF_PAPE[printGrp.paper.toString()];
					printContext[KEY_IMG_WIDTH]=printGrp.width.toString();
					printContext[KEY_IMG_LENGTH]=printGrp.height.toString();
					break;
				default:
					break;
			}

		}
		
		public function post():void{
			if(!printGrp || !lab){
				if(printGrp) printGrp.state=OrderState.ERR_PRINT_POST;
				dispatchErr('Не верные параметры запуска.');
				return;
			}
			/*
			//check channel 
			if (!lab.canPrint(printGrp)){
				printGrp.state=OrderState.ERR_PRINT_POST;
				dispatchErr('Группа печати '+printGrp.id+' не может быть распечатана в '+lab.name+'.');
				return;
			}
			*/
			printContext[KEY_CHANNEL]=lab.printChannelCode(printGrp);

			//check dest folder
			try{
				dstFolder= new File(lab.hot);
			}catch(e:Error){}
			if(!dstFolder || !dstFolder.exists || !dstFolder.isDirectory){ 
				printGrp.state=OrderState.ERR_PRINT_LAB_FOLDER_NOT_FOUND;
				dispatchErr('Hot folder "'+lab.hot+'" лаборатории "'+lab.name+'" не доступен.');
				return;
			}

			//check src folder
			//look up prt folder in print & wrk folders
			var src:Source=Context.getSource(printGrp.source_id);
			var srcFName:String;
			var dir:File;
			if(src){
				//check print folder
				srcFName=src.getPrtFolder()+File.separator+printGrp.order_folder+File.separator+printGrp.path;
				try{ 
					srcFolder=new File(srcFName);
				}catch(e:Error){}
				if(srcFolder && srcFolder.exists){
					dir=srcFolder.resolvePath(PrintGroup.SUBFOLDER_PRINT);
					if(!dir.exists || !dir.isDirectory) srcFolder=null;
				}else{
					srcFolder=null;
				}
				if(!srcFolder){
					//check wrk folder
					srcFName=src.getWrkFolder()+File.separator+printGrp.order_folder+File.separator+printGrp.path;
					try{ 
						srcFolder=new File(srcFName);
					}catch(e:Error){}
					if(srcFolder && srcFolder.exists){
						dir=srcFolder.resolvePath(PrintGroup.SUBFOLDER_PRINT);
						if(!dir.exists || !dir.isDirectory) srcFolder=null;
					}else{
						srcFolder=null;
					}
				}
			}
			
			if(!srcFolder){
				// set order err state 
				printGrp.state=OrderState.ERR_PRINT_POST_FOLDER_NOT_FOUND;
				dispatchErr('Папка группы печати '+printGrp.id+' "'+srcFName+'" не найдена.');
				return;
			}
			
			var groupFolderName:String=lab.orderFolderName(printGrp);
			var sufix:String=SourceProperty.getProperty(lab.src_type,SourceProperty.HF_SUFIX_NOREADY);
			if(sufix){
				//add sufix
				groupFolderName=groupFolderName+sufix;
			}
			if(groupFolderName) dstFolder=dstFolder.resolvePath(groupFolderName);
			if(lab.src_type!=SourceType.LAB_XEROX && groupFolderName!=''){
				//attemt to create group folder in hot
				try{
					if(dstFolder.exists) dstFolder.deleteDirectory(true); 
					dstFolder.createDirectory();
				}catch(e:Error){
					printGrp.state=OrderState.ERR_FILE_SYSTEM;
					dispatchErr('Ошибка создания папки "'+dstFolder.nativePath+'". '+e.message);
					return;
				}
			}else{
				//check chanel folder 4 xerox
				if(!dstFolder.exists  || !dstFolder.isDirectory){
					printGrp.state=OrderState.ERR_PRINT_LAB_FOLDER_NOT_FOUND;
					dispatchErr('Подпапка канала "'+dstFolder.nativePath+'" лаборатории "'+lab.name+'" не найдена.');
					return;
				}
			}
			
			//set state &  linck vs lab
			printGrp.state=OrderState.PRN_POST;
			printGrp.destination=lab.id;
			
			//add printscript header
			printBodyTemp01=loadFile(SourceProperty.getProperty(lab.src_type,SourceProperty.PRN_SCRIPT_BODY1));
			printBodyTemp02=loadFile(SourceProperty.getProperty(lab.src_type,SourceProperty.PRN_SCRIPT_BODY2));
			printScript=loadFile(SourceProperty.getProperty(lab.src_type,SourceProperty.PRN_SCRIPT_HEADER));
			if (hasErr) return; //err in loadFile 
			printScript=fillScript(printScript);
			
			//start to copy files
			currCopyIdx=-1;
			copyNext();
		}
		
		private function copyNext():void{
			var newState:int;
			currCopyIdx++;
			if(printGrp.printFiles==null){
				printGrp.state=OrderState.ERR_READ_LOCK;
				dispatchErr('Ошибка чтения');
				return;
			}
			if(currCopyIdx >=printGrp.printFiles.length){
				//complited
				//concat script
				printScript=printScript+printBody01+printBody02;
				if(printScript){
					//save script
					var scriptFileName:String=SourceProperty.getProperty(lab.src_type,SourceProperty.PRN_SCRIPT_FILE);
					var scrFile:File=dstFolder.resolvePath(scriptFileName);
					//printScript=printScript.replace(/\n/g,String.fromCharCode(13, 10));
					try{
						var fs:FileStream = new FileStream();
						fs.open(scrFile, FileMode.WRITE);
						fs.writeUTFBytes(printScript);
						fs.close();
					} catch(err:Error){
						printGrp.state=OrderState.ERR_FILE_SYSTEM;
						dispatchErr('Ошибка записи файла "'+scrFile.nativePath+'"');
						return;
					}
				}
				//finalize
				//rename folder (4 noritsu)
				var newName:File;
				var prefix:String=SourceProperty.getProperty(lab.src_type,SourceProperty.HF_PREFIX);
				if(prefix){
					newName=dstFolder.parent.resolvePath(prefix+dstFolder.name);
					try{
						dstFolder.moveTo(newName,true);
					} catch(err:Error){
						printGrp.state=OrderState.ERR_FILE_SYSTEM;
						dispatchErr('Ошибка переименования папки "'+dstFolder.nativePath+'" в "'+newName.nativePath+'"');
						return;
					}
				}

				//rename folder (4 noritsu nhf)
				var sufix:String=SourceProperty.getProperty(lab.src_type,SourceProperty.HF_SUFIX_READY);
				if(sufix){
					var groupFolderName:String=lab.orderFolderName(printGrp);
					newName=dstFolder.parent.resolvePath(groupFolderName+sufix);
					try{
						dstFolder.moveTo(newName,true);
					} catch(err:Error){
						printGrp.state=OrderState.ERR_FILE_SYSTEM;
						dispatchErr('Ошибка переименования папки "'+dstFolder.nativePath+'" в "'+newName.nativePath+'"');
						return;
					}
				}

				//copy end file (4 fuji)
				var endFileName:String=SourceProperty.getProperty(lab.src_type,SourceProperty.PRN_SCRIPT_END_FILE);
				if(endFileName){
					var endFile:File=File.applicationDirectory;
					endFile=endFile.resolvePath(endFileName);
					if(endFile.exists){
						var copyTo:File=dstFolder.resolvePath(endFile.name);
						try{
							endFile.copyTo(copyTo,true);
						} catch(err:Error){
							printGrp.state=OrderState.ERR_FILE_SYSTEM;
							dispatchErr('Ошибка копирования "'+endFile.nativePath+'" в "'+copyTo.nativePath+'"');
							return;
						}
					}
				}

				
				//set state
				printGrp.state=OrderState.PRN_PRINT;

				dispatchEvent(new Event(Event.COMPLETE));
				return;
			}
			var pf:PrintGroupFile=printGrp.printFiles[currCopyIdx] as PrintGroupFile;
			if(revers && !printGrp.is_pdf && 
				(printGrp.book_type==BookSynonym.BOOK_TYPE_BOOK || 
					printGrp.book_type==BookSynonym.BOOK_TYPE_JOURNAL || 
					printGrp.book_type==BookSynonym.BOOK_TYPE_LEATHER)) pf=printGrp.printFiles[printGrp.printFiles.length-1-currCopyIdx] as PrintGroupFile;
			if(!pf){
				printGrp.state=OrderState.ERR_PRINT_POST;
				dispatchErr('Ошибка размещения. Пустой файл №'+currCopyIdx.toString());
				return;
			}
			currCopyFile=srcFolder.resolvePath(pf.file_name);
			if(!currCopyFile.exists){
				//complite vs error
				printGrp.state=OrderState.ERR_FILE_SYSTEM;
				dispatchErr('Не найден файл "'+currCopyFile.nativePath+'"');
				return;
			}
			var dstFileName:String;
			if(lab.src_type==SourceType.LAB_XEROX || lab.src_type==SourceType.LAB_VIRTUAL){
				dstFileName=StrUtil.getFileName(pf.file_name);
			}else{
				dstFileName=StrUtil.lPad(currCopyIdx.toString())+'.'+currCopyFile.extension;
			}
			
			//fill print context
			if (lab.src_type==SourceType.LAB_FUJI){
				printContext[KEY_IMG_NUM]=(currCopyIdx+1).toString();
			}else{
				printContext[KEY_IMG_NUM]=StrUtil.lPad((currCopyIdx+1).toString(),3);
			}
			printContext[KEY_IMG_FILE]=dstFileName;
			printContext[KEY_IMG_PRT_QTTY]=pf.prt_qty>0?pf.prt_qty.toString():'1';
			
			var caption:String=pf.caption;
			if(caption){
				var re:RegExp=/[^a-z0-9\-_.,]/gi;
				caption=caption.substr(0,CAPTION_MAX_LEN).replace(re,'X');
			}else{
				caption=pf.file_name;
			}
			printContext[KEY_IMG_BACKPRINT_LINE2]=caption;
			
			if(lab.src_type==SourceType.LAB_NORITSU_NHF){
				var img_fmt:String=NORITSU_NHF_IMG_FORMAT[StrUtil.getFileExtension(pf.file_name)];
				if(!img_fmt){
					printGrp.state=OrderState.ERR_PRINT_POST;
					dispatchErr('Не определен формат изображения "'+pf.file_name+'"');
					return;
				}
				printContext[KEY_IMG_FORMAT]=img_fmt;
			}
			
			//dstFileName=SourceProperty.getProperty(lab.type_id,SourceProperty.HF_IMG_FOLDER)+File.separator+dstFileName;
			var dstFileFolder:String=SourceProperty.getProperty(lab.src_type,SourceProperty.HF_IMG_FOLDER);
			if(dstFileFolder) dstFileFolder=dstFileFolder+File.separator;
			dstFileName=dstFileFolder+dstFileName;
			
			var dstFile:File=dstFolder.resolvePath(dstFileName);
			currCopyFile.addEventListener(Event.COMPLETE,copyComplete);
			currCopyFile.addEventListener(IOErrorEvent.IO_ERROR,copyIOFault);
			currCopyFile.addEventListener(SecurityErrorEvent.SECURITY_ERROR,copySecurityFault);
			currCopyFile.copyToAsync(dstFile,true);
			
			//add script section
			var script:String;
			script=fillScript(printBodyTemp01);
			printBody01=printBody01+script;
			script=fillScript(printBodyTemp02);
			printBody02=printBody02+script;
			//printScript=printScript+script;

		}
		
		private function copyComplete(e:Event):void{
			stopListen();
			copyNext();
		}
		
		private function copyIOFault(e:IOErrorEvent):void{
			stopListen();
			printGrp.state=OrderState.ERR_FILE_SYSTEM;
			dispatchErr('Ошибка копирования файла "'+e.text+'"');
		}

		private function copySecurityFault(e:SecurityErrorEvent):void{
			stopListen();
			printGrp.state=OrderState.ERR_FILE_SYSTEM;
			dispatchErr('Ошибка копирования файла "'+e.text+'"');
		}
		
		private function stopListen():void{
			if(currCopyFile){
				currCopyFile.removeEventListener(Event.COMPLETE,copyComplete);
				currCopyFile.removeEventListener(IOErrorEvent.IO_ERROR,copyIOFault);
				currCopyFile.removeEventListener(SecurityErrorEvent.SECURITY_ERROR,copySecurityFault);
			}
		}
		
		private function dispatchErr(msg:String):void{
			hasErr=true;
			errMsg=msg;
			//StateLogDAO.logState(printGrp.state, printGrp.order_id,printGrp.id,'Ошибка размещения на печать: '+msg); 
			dispatchEvent(new Event(Event.COMPLETE));
		}
		
		private function loadFile(name:String):String{
			if(!name) return '';
			var f:File=File.applicationDirectory;
			f=f.resolvePath(name);
			if(!f.exists) return '';
			try{
				var fs:FileStream=new FileStream();
				fs.open(f,FileMode.READ);
				var result:String=fs.readUTFBytes(fs.bytesAvailable);
				fs.close();
			} catch(err:Error){
				printGrp.state=OrderState.ERR_FILE_SYSTEM;
				dispatchErr('Ошибка загрузки файла"'+name+'"');
				return '';
			}
			//result = result.replace(File.lineEnding, '\n');
			return result;
		}
		
		private function fillScript(script:String):String{
			var re:RegExp;
			var result:String=script;
			if(!script) return '';
			for(var key:String in printContext){
				if(key){
					re= new RegExp('~~~'+key+'~~~','gi');
					result=result.replace(re,printContext[key]);
				}
			}
			return result;
		}
	}
}