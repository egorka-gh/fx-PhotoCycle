package com.photodispatcher.provider.preprocess{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.model.mysql.entities.BookSynonym;
	import com.photodispatcher.model.mysql.entities.OrderState;
	import com.photodispatcher.model.mysql.entities.PrintGroup;
	import com.photodispatcher.model.mysql.entities.PrintGroupFile;
	import com.photodispatcher.shell.IMCommand;
	import com.photodispatcher.util.IMCommandUtil;
	import com.photodispatcher.util.StrUtil;
	
	import flash.filesystem.File;
	
	public class PDFsimpleMakeupGroup extends BookMakeupGroup{
		
		public static const TEMP_FOLDER:String='pdf_wrk';
		protected static const TEMP_FILE_TYPE:String='.jpg';//bug - broken jpg - use png or some else
		//protected static const TEMP_FILE_TYPE:String='.png';

		public function PDFsimpleMakeupGroup(printGroup:PrintGroup, order_id:String, folder:String, prtFolder:String){
			super(printGroup, order_id, folder, prtFolder);
		}
		
		override public function createCommands():void{
			//if(Context.getAttribute("pdfJpgQuality")) jpgQuality=Context.getAttribute("pdfJpgQuality");
			if(Context.config && Context.config.pdf_quality>60) jpgQuality=Context.config.pdf_quality.toString();
			
			var altPdf:Boolean=Context.getAttribute("altPDF");

			commands=[];
			finalCommands=[];
			
			if(state==STATE_ERR) return;
			if (!printGroup.bookTemplate 
				|| !printGroup.bookTemplate.sheet_width || !printGroup.bookTemplate.sheet_len){
				return;
			}
			if (!printGroup.is_pdf && !printGroup.bookTemplate.is_sheet_ready) return;
			
			var files:Array;
			var i:int;
			var it:PrintGroupFile;
			var command:IMCommand;
			var command2:IMCommand;
			var outName:String;
			var pageLimit:int=Context.getAttribute('pdfPageLimit');
			if(!pageLimit) pageLimit=30;
			//var pdfPageNum:int=0;
			//var pdfName:String;
			var prints:int=0;

			
			files=printGroup.bookFiles;
			if(!files || files.length==0){
				state=STATE_ERR;
				err=OrderState.ERR_PREPROCESS;
				err_msg='Пустая группа печати';
				return;
			}

			//create wrk folder
			var wrkFolder:File=new File(folder);
			if(!wrkFolder || !wrkFolder.exists){
				state=STATE_ERR;
				err=OrderState.ERR_PREPROCESS;
				err_msg='Не найдена папка '+folder;
				return;
			}
			wrkFolder=wrkFolder.resolvePath(TEMP_FOLDER);
			try{
				if(wrkFolder.exists){
					if(wrkFolder.isDirectory){
						wrkFolder.deleteDirectory(true);
					}else{
						wrkFolder.deleteFile();
					}
				}
				wrkFolder.createDirectory();
			}catch(error:Error){
				state=STATE_ERR;
				err=OrderState.ERR_PREPROCESS;
				err_msg=error.message;
				return;
			}

			printGroup.resetFiles();
			//pack to pdf command
			command2=new IMCommand(IMCommand.IM_CMD_CONVERT);
			command2.folder=folder;
			//prepare sheets
			for (i=0; i<files.length; i++){
				it=files[i] as PrintGroupFile;
				if(!it){
					state=STATE_ERR;
					err=OrderState.ERR_PREPROCESS;
					err_msg='Не верный состав книги. Не определен файл №'+(i+1).toString();
					return;
				}
				if(!reprintMode || it.reprint){
					if(altPdf){
						command=createCommand(it,folder,jpgQuality);
					}else{
						command=createCommand(it,folder);
					}
					//save
					outName= TEMP_FOLDER+File.separator+StrUtil.lPad(it.book_num.toString(),3)+'-'+StrUtil.lPad(it.page_num.toString(),2)+TEMP_FILE_TYPE;
					command.add(outName);
					commands.push(command);
					//add 2 final(pdf) cmd
					command2.add(outName);
					prints++;
				}
			}
			
			//expand format by tech
			if(printGroup.bookTemplate.tech_bar &&
				(printGroup.book_type==BookSynonym.BOOK_TYPE_BOOK || 
					printGroup.book_type==BookSynonym.BOOK_TYPE_JOURNAL || 
					printGroup.book_type==BookSynonym.BOOK_TYPE_LEATHER)){
				if(printGroup.bookTemplate.tech_add) printGroup.height+=printGroup.bookTemplate.tech_add;
			}
			if(reprintMode) printGroup.prints=prints;
			
			//create pdf commands
			//split by limit
			var idx:int;
			var pdfNum:int;
			var pdfName:String;
			var newFile:PrintGroupFile;
			
			//apply alt revers
			printGroup.bookTemplate.applyAltRevers(printGroup);
			
			for(pdfNum=0;pdfNum<Math.ceil(command2.parameters.length/pageLimit);pdfNum++){
				pdfName=printGroup.pdfFileNamePrefix+StrUtil.lPad((pdfNum+1).toString(),3)+'.pdf';

				if(altPdf){
					command=new IMCommand(IMCommand.IM_CMD_ALTPDF);
					command.folder=folder;
					// hide log output
					command.redirectOut='>log.txt';
					//set out file
					////jpeg2pdf.exe -o tst.pdf -p auto -m 0mm -z none -r none -k phcycle  *.jpg
					command.add('-o'); command.add(outPath(pdfName));
					IMCommandUtil.setPDFOutputParams(command);
				}else{
					command=new IMCommand(IMCommand.IM_CMD_CONVERT);
					command.folder=folder;
				}
				
				for(i=0;i<pageLimit;i++){
					//parm idx
					idx=pdfNum*pageLimit+i;
					if(printGroup.bookTemplate.revers){
						//revers
						idx=command2.parameters.length-1-idx;
					}
					//check if out of command2.parameters.length
					if(idx<0 || idx>=command2.parameters.length) break;
					command.add(command2.parameters[idx]);
				}
				
				//finalize pdf command
				if(!altPdf){
					IMCommandUtil.setPDFOutputParams(command,jpgQuality);
					command.add(outPath(pdfName));
				}
				
				finalCommands.push(command);
				//add to printGroup.files
				newFile= new PrintGroupFile();
				newFile.file_name=pdfName;
				newFile.prt_qty=1;
				printGroup.addFile(newFile);
			}

		}

	}
}