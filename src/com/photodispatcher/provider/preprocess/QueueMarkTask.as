package com.photodispatcher.provider.preprocess{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.event.IMRunerEvent;
	import com.photodispatcher.model.mysql.AsyncLatch;
	import com.photodispatcher.model.mysql.DbLatch;
	import com.photodispatcher.model.mysql.entities.BookSynonym;
	import com.photodispatcher.model.mysql.entities.OrderState;
	import com.photodispatcher.model.mysql.entities.PrintGroup;
	import com.photodispatcher.model.mysql.entities.PrintGroupFile;
	import com.photodispatcher.model.mysql.entities.PrnQueue;
	import com.photodispatcher.model.mysql.entities.PrnQueueLink;
	import com.photodispatcher.model.mysql.entities.Source;
	import com.photodispatcher.model.mysql.entities.StateLog;
	import com.photodispatcher.model.mysql.services.PrintGroupService;
	import com.photodispatcher.shell.IMCommand;
	import com.photodispatcher.shell.IMMultiSequenceRuner;
	import com.photodispatcher.shell.IMSequenceRuner;
	import com.photodispatcher.util.IMCommandUtil;
	import com.photodispatcher.util.StrUtil;
	import com.photodispatcher.util.UnitUtil;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	import flash.text.ReturnKeyLabel;
	
	import org.granite.tide.Tide;
	
	[Event(name="progress", type="flash.events.ProgressEvent")]
	[Event(name="complete", type="flash.events.Event")]
	public class QueueMarkTask extends EventDispatcher{
		public static const TEMP_FOLDER:String='pdf_wrk';
		public static const ORG_FOLDER:String='org';
		public static const EMPTY_PAGE:String='000';

		private var prnQueue:PrnQueue;
		private var queueLink:PrnQueueLink;
		private var pngCommands:Array;
		private var pageCommands:Array;
		private var pdfCommands:Array;
		private var maskCommands:Array;
		private var tempFolders:Array;
		
		public var hasError:Boolean;
		public var error:String;

		public function QueueMarkTask(prnQueue:PrnQueue, queueLink:PrnQueueLink=null){
			super(null);
			this.prnQueue=prnQueue;
			this.queueLink=queueLink;
		}
		
		//private var gLatch:AsyncLatch;
		public function run():void{
			pngCommands=[];
			pageCommands=[];
			pdfCommands=[];
			maskCommands=[];
			tempFolders=[];
			var altPdf:Boolean=Context.getAttribute("altPDF");
			if(!altPdf){
				dispatchErr('Не настроена альтернативная сборка в PDF');
				return;
			}
			if (!prnQueue || !prnQueue.printGroups || prnQueue.printGroups.length==0){
				dispatchErr('Пустая очередь');
				return;
			}
			
			//load printgroup files and build commands
			/*
			gLatch= new AsyncLatch();
			gLatch.addEventListener(Event.COMPLETE,onCommandsCreated);
			var svc:PrintGroupService = Tide.getInstance().getContext().byType(PrintGroupService,true) as PrintGroupService;
			*/
			var pg:PrintGroup;
			for each(pg in prnQueue.printGroups){
				if (pg && pg.book_type != 0 ){
					/*
					var latch:DbLatch=new DbLatch();
					latch.callContext=pg;
					//priority 1000 - to run before gLatch 
					latch.addEventListener(Event.COMPLETE,onLoadFiles,false,1000);
					latch.addLatch(svc.loadFiles(pg.id));
					gLatch.join(latch);
					*/
					processPg(pg);
				}
			}
			/*
			gLatch.start();
			gLatch.release();
			*/
			if(hasError) return;
			if (pngCommands.length==0) return;
			if (pg) StateLog.logByPGroup(OrderState.PRN_AUTOPRINTLOG,pg.id,'Старт подготовки');
			//run sequence
			var sequences:Array=[pngCommands,pageCommands,pdfCommands,maskCommands];
			var sequencesRuner:IMMultiSequenceRuner= new IMMultiSequenceRuner();
			sequencesRuner.addEventListener(ProgressEvent.PROGRESS, onCmdProgress);
			sequencesRuner.addEventListener(IMRunerEvent.IM_COMPLETED, onCmdComplite);
			//TODO use maxThreads?
			var maxThreads:int=Context.getAttribute('imThreads');
			if (maxThreads<=0) maxThreads=1;
			sequencesRuner.start(sequences, maxThreads,false);
			
			/*
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
			*/
			
		}

		/*
		private function onLoadFiles(evt:Event):void{
			var latch:DbLatch= evt.target as DbLatch;
			if(latch ){
				latch.removeEventListener(Event.COMPLETE,onLoadFiles);
				if (latch.complite){
					var pg:PrintGroup = latch.callContext as PrintGroup;
					if (!pg || !latch.lastDataArr || latch.lastDataArr.length==0) return;
					pg.files= latch.lastDataAC;
					processPg(pg);
				}				
			}
		}
		*/
		
		private var wrkDir:File;
		private var orgDir:File;
		private function processPg(pg:PrintGroup):void{
			var source:Source=Context.getSource(PrintGroup.sourceIdFromId(pg.id));
			if(!source){
				//gLatch.releaseError("Не определен источник для "+pg.id);
				dispatchErr("Не определен источник для "+pg.id);
				return;
			}
			pg.bookTemplate= BookSynonym.getTemplateByPg(pg);
			if(!pg.bookTemplate){
				//gLatch.releaseError("Не определен шаблон для "+pg.alias+' '+pg.id);
				dispatchErr("Не определен шаблон для "+pg.alias+' '+pg.id);
				return;
			}
			if(pg.bookTemplate.queue_size<=0 && pg.bookTemplate.queue_book_size <=0 ){
				//queue mark off
				return;
			}
			wrkDir= new File(source.getPrtFolder()).resolvePath(pg.order_folder).resolvePath(pg.path).resolvePath(PrintGroup.SUBFOLDER_PRINT);
			if(!wrkDir.exists || !wrkDir.isDirectory){
				//gLatch.releaseError("Не доступна папка "+wrkPath+' '+pg.id);
				dispatchErr("Не доступна папка "+wrkDir.nativePath+' '+pg.id);
				return;
			}
			//create backup & move original files
			orgDir=wrkDir.resolvePath(ORG_FOLDER);
			try{
				if(!orgDir.exists){
					orgDir.createDirectory();
					/*
					//move files
					var list:Array= wrkDir.getDirectoryListing();
					for each (var f:File in list){
						if(!f.isDirectory) f.copyTo(orgDir.resolvePath(f.name));
					}
					*/
				}
				var list:Array= wrkDir.getDirectoryListing();
				for each (var f:File in list){
					var fc:File=orgDir.resolvePath(f.name);
					if(!f.isDirectory && !fc.exists) f.copyTo(fc);
				}
			}catch(error:Error){
				//gLatch.releaseError("Ошибка файлов "+error.message);
				dispatchErr("Ошибка файлов "+error.message);
				return;
			}
			
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
				//gLatch.releaseError("Ошибка файлов "+error.message);
				dispatchErr("Ошибка файлов "+error.message);
				return;
			}
			try{

				if (pg.is_pdf){
					createPdfCommands(pg);	
				}else{
					createCommands(pg);
				}
			}catch(error:Error){
				//gLatch.releaseError("Ошибка файлов "+error.message);
				dispatchErr("Ошибка "+error.message);
				return;
			}
			
		}
		
		private function createCommands(printGroup:PrintGroup):void{
			var fileName:String;
			var txtPart:String;
			if(printGroup.bookTemplate.queue_size>0){
				if(queueLink){
					txtPart=queueLink.prn_queue.toString()+'-'+queueLink.prn_queue_link.toString();
				}else{
					txtPart=printGroup.prn_queue.toString();
				}
				StateLog.logByPGroup(OrderState.PRN_AUTOPRINTLOG,printGroup.id,'Маркировка партии '+ txtPart);
			}
			if( printGroup.bookTemplate.queue_book_size >0 ){
				StateLog.logByPGroup(OrderState.PRN_AUTOPRINTLOG,printGroup.id,'Маркировка книг партии');
			}
			for (var i:int=1; i<=printGroup.book_num;i++){
				if(printGroup.book_part==BookSynonym.BOOK_PART_COVER){
					fileName=StrUtil.lPad(i.toString(),3)+'_00.jpg';	
				}else{
					fileName=StrUtil.lPad(i.toString(),3)+'_'+StrUtil.lPad(printGroup.sheet_num.toString(),2)+'.jpg';	
				}
				var command:IMCommand=new IMCommand(IMCommand.IM_CMD_CONVERT);
				//use original folder (\print)
				command.folder = wrkDir.parent.nativePath;
				command.add(fileName);				
				if(printGroup.bookTemplate.queue_size>0){
					IMCommandUtil.annotateImageV(command,printGroup.bookTemplate.queue_size, 'Партия:'+txtPart,printGroup.bookTemplate.queue_offset);				
				}
				
				var txt:String;
				if( printGroup.bookTemplate.queue_book_size >0 ){
					txt= (printGroup.books_offset+i).toString();
					IMCommandUtil.annotateImageV(command,printGroup.bookTemplate.queue_size, 'Книга:'+txt,printGroup.bookTemplate.queue_book_offset);						
				}
				IMCommandUtil.setOutputParams(command, '100');
				command.add(fileName);
				pngCommands.push(command);
			}
		}
		
		private function createPdfCommands(printGroup:PrintGroup):void{
			//detect size
			var width:int=printGroup.bookTemplate.sheet_width;
			//expand verticaly
			if(printGroup.bookTemplate.tech_stair_add){
				width = width+printGroup.bookTemplate.tech_stair_add;
			}
			var len:int=printGroup.bookTemplate.sheet_len;
			if(printGroup.book_part==BookSynonym.BOOK_PART_COVER) len=UnitUtil.mm2Pixels300(printGroup.height);

			//add for tech barcode
			if(printGroup.bookTemplate.tech_bar &&
				(printGroup.book_type==BookSynonym.BOOK_TYPE_BOOK || 
					printGroup.book_type==BookSynonym.BOOK_TYPE_JOURNAL || 
					printGroup.book_type==BookSynonym.BOOK_TYPE_LEATHER) &&
				(printGroup.bookTemplate.is_tech_top || printGroup.bookTemplate.is_tech_center || printGroup.bookTemplate.is_tech_bot)){
				len=len+printGroup.bookTemplate.tech_add;
			}
			
			var command:IMCommand;
			//create empty page
			if (printGroup.book_part != BookSynonym.BOOK_PART_COVER){
				command=new IMCommand(IMCommand.IM_CMD_CONVERT);
				command.folder = wrkDir.nativePath;
				command.add('-size'); command.add(len.toString()+'x'+width.toString());
				command.add('xc:none');
				IMCommandUtil.setOutputParams(command, '100');
				command.add(EMPTY_PAGE+'.png');
				pngCommands.push(command);
				
			}
			
			var pdfPages:Array=[];
			var txtPart:String;
			if(printGroup.bookTemplate.queue_size>0){
				if(queueLink){
					txtPart=queueLink.prn_queue.toString()+'-'+queueLink.prn_queue_link.toString();
				}else{
					txtPart=printGroup.prn_queue.toString();
				}
				StateLog.logByPGroup(OrderState.PRN_AUTOPRINTLOG,printGroup.id,'Маркировка партии '+ txtPart);
			}
			if( printGroup.bookTemplate.queue_book_size >0 ){
				StateLog.logByPGroup(OrderState.PRN_AUTOPRINTLOG,printGroup.id,'Маркировка книг партии');
			}
			for (var i:int=1; i<=printGroup.book_num;i++){
				//for block & blockcover mark last page only
				//add empty pages
				if (printGroup.book_part != BookSynonym.BOOK_PART_COVER){
					for (var j:int=0; j<printGroup.sheet_num-1;j++){
						pdfPages.push(EMPTY_PAGE+'.pdf');			
					}
				}
				//create sheet with labels
				command=new IMCommand(IMCommand.IM_CMD_CONVERT);
				command.folder = wrkDir.nativePath;
				command.add('-size'); command.add(len.toString()+'x'+width.toString());
				command.add('xc:none');
				
				if(printGroup.bookTemplate.queue_size>0){
					IMCommandUtil.annotateImageV(command,printGroup.bookTemplate.queue_size, 'Партия:'+txtPart,printGroup.bookTemplate.queue_offset);				
				}
				
				var txt:String;
				if( printGroup.bookTemplate.queue_book_size >0 ){
					txt= (printGroup.books_offset+i).toString();
					StateLog.logByPGroup(OrderState.PRN_AUTOPRINTLOG,printGroup.id,'Маркировка книги партии '+ txt);
					IMCommandUtil.annotateImageV(command,printGroup.bookTemplate.queue_size, 'Книга:'+txt,printGroup.bookTemplate.queue_book_offset);						
				}
				
				IMCommandUtil.setOutputParams(command, '100');
				//result file name
				var resultName:String = StrUtil.lPad(i.toString(),3);
				pdfPages.push(resultName+'.pdf');
				command.add(resultName+'.png');
				pngCommands.push(command);
			}
			//convert pngs to pdf pages
			command=new IMCommand(IMCommand.IM_CMD_JPG2PDF);
			command.folder=wrkDir.nativePath;
			//set params
			IMCommandUtil.setPNG2PDFParams(command);
			//set folder vs png
			command.add(wrkDir.nativePath);
			pageCommands.push(command);
			
			//collect pages to pdf & apply mask to original pdfs
			var pageLimit:int=printGroup.sheets_per_file;
			for(var pdfNum:int=0;pdfNum<Math.ceil(pdfPages.length/pageLimit);pdfNum++){
				//collect pages to pdf
				var pdfName:String=printGroup.pdfFileNamePrefix(false)+StrUtil.lPad((pdfNum+1).toString(),3)+'.pdf';
				command=new IMCommand(IMCommand.IM_CMD_PDF_TOOL);
				command.folder=wrkDir.nativePath;
				for(i=0;i<pageLimit;i++){
					var idx:int=pdfNum*pageLimit+i;
					if(printGroup.is_revers){
						//revers
						idx=pdfPages.length-1-idx;
					}
					//check if out of command2.parameters.length
					if(idx<0 || idx>=pdfPages.length) break;
					command.add(pdfPages[idx]);
				}
				//finalize pdf command
					//pdftk *.pdf cat output combined.pdf
				command.add('cat'); 
				command.add('output');
				command.add(pdfName);
				pdfCommands.push(command);
				
				//apply mask to original pdfs
				//pdftk page.pdf stamp stamp.pdf output final.pdf
				command=new IMCommand(IMCommand.IM_CMD_PDF_TOOL);
				command.folder=wrkDir.nativePath;
				//add original file
				//TODO check if original exists
				command.add(orgDir.resolvePath(pdfName).nativePath);
				command.add('multistamp');
				//add mask
				command.add(pdfName);
				command.add('output');
				command.add(wrkDir.parent.resolvePath(pdfName).nativePath);
				maskCommands.push(command);
			}
		}

		
		private function onCmdComplite(e:IMRunerEvent):void{
			//var runer:IMSequenceRuner=e.target as IMSequenceRuner;
			var runer:IMMultiSequenceRuner=e.target as IMMultiSequenceRuner;
			runer.removeEventListener(IMRunerEvent.IM_COMPLETED, onCmdComplite);
			runer.removeEventListener(ProgressEvent.PROGRESS, onCmdProgress);
			cleanup();
			var pg:PrintGroup = prnQueue.printGroups.getItemAt(prnQueue.printGroups.length-1) as PrintGroup;
			if (pg) StateLog.logByPGroup(OrderState.PRN_AUTOPRINTLOG,pg.id,'Конец подготовки');
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
		
		private function dispatchErr(errMsg:String):void{
			hasError=true;
			error=errMsg;
			var pg:PrintGroup = prnQueue.printGroups.getItemAt(prnQueue.printGroups.length-1) as PrintGroup;
			if (pg) StateLog.logByPGroup(OrderState.PRN_AUTOPRINTLOG,pg.id,'Ошибка: '+errMsg);
			dispatchEvent(new Event(Event.COMPLETE));
		}

	}
}