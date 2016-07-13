package com.photodispatcher.provider.preprocess{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.event.IMRunerEvent;
	import com.photodispatcher.model.mysql.entities.BookSynonym;
	import com.photodispatcher.model.mysql.entities.PrintGroup;
	import com.photodispatcher.model.mysql.entities.PrintGroupFile;
	import com.photodispatcher.model.mysql.entities.Source;
	import com.photodispatcher.shell.IMCommand;
	import com.photodispatcher.shell.IMSequenceRuner;
	import com.photodispatcher.util.IMCommandUtil;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	
	[Event(name="progress", type="flash.events.ProgressEvent")]
	[Event(name="complete", type="flash.events.Event")]
	public class QueueMarkTask extends EventDispatcher{
		public static const TEMP_FOLDER:String='pdf_wrk';

		private var startPrintgroup:PrintGroup;
		private var endPrintgroup:PrintGroup
		private var commands:Array;
		private var tempFolders:Array;
		
		public var hasError:Boolean;
		public var error:String;

		public function QueueMarkTask(startPrintgroup:PrintGroup,endPrintgroup:PrintGroup){
			super(null);
			this.startPrintgroup=startPrintgroup;
			this.endPrintgroup=endPrintgroup;
			commands=[];
			tempFolders=[];
		}
		
		public function run():void{
			var altPdf:Boolean=Context.getAttribute("altPDF");
			if(!altPdf){
				dispatchErr('Не настроена альтернативная сборка в PDF');
				return;
			}
			createCommands();
			if(hasError) return;
			if(commands.length==0){
				dispatchEvent(new Event(Event.COMPLETE));
				return;
			}
			//run sequence
			var runer:IMSequenceRuner=new IMSequenceRuner(commands);
			dispatchEvent(new ProgressEvent(ProgressEvent.PROGRESS,false,false,0,commands.length));
			runer.addEventListener(IMRunerEvent.IM_COMPLETED, onCmdComplite);
			runer.addEventListener(ProgressEvent.PROGRESS, onCmdProgress);
			runer.start();
		}
		private function onCmdComplite(e:IMRunerEvent):void{
			var runer:IMSequenceRuner=e.target as IMSequenceRuner;
			runer.removeEventListener(IMRunerEvent.IM_COMPLETED, onCmdComplite);
			runer.removeEventListener(ProgressEvent.PROGRESS, onCmdProgress);
			cleanup();
			if(e.hasError){
				trace('QueueMarkTask. Error: '+e.error+'\n command: '+(e.command?e.command.toString():''));
				dispatchErr('Ошибка подготовки: '+e.error);
			}else{
				dispatchEvent(new Event(Event.COMPLETE));
			}
		}
		private function onCmdProgress(e:ProgressEvent):void{
			dispatchEvent(e.clone());
		}
		
		private function cleanup():void{
			var path:String;
			var wrkDir:File;
			for each(path in tempFolders){
				if(path){
					wrkDir=new File(path);
					try{
						if(wrkDir.exists){
							if(wrkDir.isDirectory){
								wrkDir.deleteDirectory(true);
							}else{
								wrkDir.deleteFile();
							}
						}
					}catch(error:Error){
						trace(error.message);
					}
				}
			}
		}

		private function createCommands():void{
			if(!startPrintgroup && !endPrintgroup) return;
			createPgCommands(startPrintgroup,true);
			createPgCommands(endPrintgroup,false);
		}
		
		private function createPgCommands(printGroup:PrintGroup, isStart:Boolean):void{
			if(!printGroup) return;
			var idx:int;
			var pgf:PrintGroupFile;
			var wrkPath:String;
			var tmpPath:String;
			var wrkDir:File;
			var fileName:String;
			var command:IMCommand;

			if(printGroup.book_type==0) return;
			
			if(printGroup.prn_queue==0){
				dispatchErr("Не указана партия "+printGroup.id);
				return;
			}
			if(!printGroup.files || printGroup.files.length==0){
				dispatchErr("Пустая группа печати "+printGroup.id);
				return;
			}
			idx=0;
			if(isStart){
				if(!printGroup.is_pdf && printGroup.is_revers){
					idx=printGroup.files.length-1;
				}
			}else{
				if(!printGroup.is_pdf && !printGroup.is_revers){
					idx=printGroup.files.length-1;
				}
				if(printGroup.is_pdf){
					idx=printGroup.files.length-1;
				}
			}
			pgf=printGroup.files[idx] as PrintGroupFile;
			if(pgf) fileName=pgf.file_name;
			if(!pgf || !fileName){
				dispatchErr("Не определен файл "+idx.toString()+' '+printGroup.id);
				return;
			}
			
			var source:Source=Context.getSource(PrintGroup.sourceIdFromId(printGroup.id));
			if(!source){
				dispatchErr("Не определен источник для "+printGroup.id);
				return;
			}
			wrkPath=source.getPrtFolder()+File.separator+printGroup.order_folder+File.separator+printGroup.path;//+File.separator+filePath;
			wrkDir= new File(wrkPath);
			if(!wrkDir.exists || !wrkDir.isDirectory){
				dispatchErr("Не доступна папка "+wrkPath+' '+printGroup.id);
				return;
			}
			printGroup.bookTemplate= BookSynonym.getTemplateByPg(printGroup);
			if(!printGroup.bookTemplate){
				//dispatchErr("Не определен шаблон для "+printGroup.alias+' '+printGroup.id);
				return;
			}
			
			if(printGroup.bookTemplate.queue_size<=0){
				//queue mark off
				return;
			}
			if(printGroup.is_pdf){
				//create temp folder
				wrkDir=wrkDir.resolvePath(TEMP_FOLDER);
				try{
					if(wrkDir.exists){
						if(wrkDir.isDirectory){
							wrkDir.deleteDirectory(true);
						}else{
							wrkDir.deleteFile();
						}
					}
					wrkDir.createDirectory();
				}catch(error:Error){
					dispatchErr("Ошибка файлов "+error.message);
					return;
				}
				tempFolders.push(wrkDir.nativePath);
				//extract pdf page
				command=new IMCommand(IMCommand.IM_CMD_PDF_TOOL);
				command.folder=wrkPath;
				//pdftk in.pdf cat 1-12 14-end output out1.pdf
				command.add(fileName);
				command.add('cat');
				if(isStart){
					command.add('1');
				}else{
					command.add('end');
				}
				command.add('output');
				command.add(wrkDir.nativePath+File.separator+'page.pdf');
				commands.push(command);
				
				//extract jpg
				command=new IMCommand(IMCommand.IM_CMD_PDF2JPG);
				command.folder=wrkPath;
				//pdfimages.exe -f 1 -l 1  -j 1.pdf img
				command.add('-f'); command.add('1'); //from page
				command.add('-l'); command.add('1'); //to page
				command.add('-j'); //keep jpg
				command.add(wrkDir.nativePath+File.separator+'page.pdf'); //src pdf
				command.add(wrkDir.nativePath+File.separator+'img'); //output prefix (img-0000.jpg)
				commands.push(command);
			}
			
			//draw queue mark
			command=new IMCommand(IMCommand.IM_CMD_CONVERT);
			if(!printGroup.is_pdf){
				command.folder=wrkPath;
				command.add(fileName);
			}else{
				command.folder=wrkDir.nativePath;
				command.add('img-0000.jpg');
			}
			IMCommandUtil.annotateImageV(command,printGroup.bookTemplate.queue_size, 'Партия:'+printGroup.prn_queue.toString(),printGroup.bookTemplate.queue_offset);
			IMCommandUtil.setOutputParams(command, '100');
			if(!printGroup.is_pdf){
				command.add(fileName);
			}else{
				command.add('img-0000.jpg');
			}
			commands.push(command);

			//pack to pdf
			if(printGroup.is_pdf){
				//pack to pdf page
				command=new IMCommand(IMCommand.IM_CMD_JPG2PDF);
				command.folder=wrkDir.nativePath;
				//set params
				IMCommandUtil.setJPG2PDFParams(command);
				//set jpg path
				command.add(wrkDir.nativePath+File.separator+'img-0000.jpg');
				commands.push(command);
				
				//replace page
				//remove old page
				command=new IMCommand(IMCommand.IM_CMD_PDF_TOOL);
				command.folder=wrkPath;
				command.add(wrkPath+File.separator+pgf.file_name);
				command.add('cat');
				if(isStart){
					command.add('2-end');
				}else{
					//4 last page
					//pdftk 2.pdf cat 1-r2 output 1.pdf
					command.add('1-r2');
				}
				command.add('output');
				command.add(wrkDir.nativePath+File.separator+'cat.pdf');
				commands.push(command);
				
				//join
				command=new IMCommand(IMCommand.IM_CMD_PDF_TOOL);
				command.folder=wrkDir.nativePath;
				if(isStart){
					//add first
					command.add('img-0000.pdf');//new page
					command.add('cat.pdf');//cat pdf
				}else{
					//add last
					command.add('cat.pdf');//cat pdf
					command.add('img-0000.pdf');//new page
				}
				command.add('cat');
				command.add('output');
				command.add(wrkPath+File.separator+pgf.file_name); //replace old
				commands.push(command);
			}
		}
		
		
		private function dispatchErr(errMsg:String):void{
			hasError=true;
			error=errMsg;
			dispatchEvent(new Event(Event.COMPLETE));
		}

	}
}