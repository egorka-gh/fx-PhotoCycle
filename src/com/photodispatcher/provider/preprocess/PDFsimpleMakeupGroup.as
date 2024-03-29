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

			sequences=[];
			var commands:Array=[];
			totalCommands=0;
			//finalCommands=[];
			
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
			//command2.folder=folder;
			command2.folder=wrkFolder.nativePath;
			
			//prepare sheets
			for (i=0; i<files.length; i++){
				it=files[i] as PrintGroupFile;
				if(!it){
					state=STATE_ERR;
					err=OrderState.ERR_PREPROCESS;
					err_msg='Не верный состав книги. Не определен файл №'+(i+1).toString();
					return;
				}
				if(buildMode==MODE_BUILD || (buildMode==MODE_REPRINT && it.reprint)){
					if(altPdf){
						command=createCommand(it,folder,jpgQuality);
					}else{
						command=createCommand(it,folder);
					}
					//save
					//outName= TEMP_FOLDER+File.separator+StrUtil.lPad(it.book_num.toString(),3)+'-'+StrUtil.lPad(it.page_num.toString(),2)+TEMP_FILE_TYPE;
					outName= StrUtil.lPad(it.book_num.toString(),3)+'-'+StrUtil.lPad(it.page_num.toString(),2)+TEMP_FILE_TYPE;
					command.add(TEMP_FOLDER+File.separator+outName);
					commands.push(command);
					//add 2 final(pdf) cmd
					command2.add(outName);
					prints++;
				}
			}
			
			totalCommands+=commands.length;
			sequences.push(commands);
			
			//expand format by tech
			if(printGroup.bookTemplate.tech_bar &&
				(printGroup.book_type==BookSynonym.BOOK_TYPE_BOOK || 
					printGroup.book_type==BookSynonym.BOOK_TYPE_JOURNAL || 
					printGroup.book_type==BookSynonym.BOOK_TYPE_LEATHER)){
				if(printGroup.bookTemplate.tech_add) printGroup.height+=printGroup.bookTemplate.tech_add;
			}
			if(buildMode==MODE_REPRINT) printGroup.prints=prints;
			
			if(altPdf){
				//convert jpg to pdf (one to one)
				command=new IMCommand(IMCommand.IM_CMD_JPG2PDF);
				command.folder=command2.folder;
				//bmpp -l pdf.image -t jpeg  -o dct=on -o bpc=off -o interpolation=off -o resolution=chunk  D:\Buffer\lab\fudji\78985-2\cpy
				//set params
				IMCommandUtil.setJPG2PDFParams(command);
				//set foler vs jpg
				command.add(wrkFolder.nativePath);
				//add to separate seq
				sequences.push([command]);
				totalCommands+=1;

				//change ext to pdf
				var flName:String;
				for (idx = 0; idx < command2.parameters.length; idx++){
					flName=command2.parameters[idx];
					flName=flName.substr(0,flName.length-TEMP_FILE_TYPE.length)+'.pdf';
					command2.parameters[idx]=flName;
				}
			}
			
			//create pdf commands
			//split by limit
			var idx:int;
			var pdfNum:int;
			var pdfName:String;
			var newFile:PrintGroupFile;
			
			//apply alt revers
			var revers:Boolean=printGroup.bookTemplate.getRevers(printGroup);
			printGroup.is_revers=revers;
			printGroup.sheets_per_file=pageLimit;
			
			commands=[];
			for(pdfNum=0;pdfNum<Math.ceil(command2.parameters.length/pageLimit);pdfNum++){
				pdfName=printGroup.pdfFileNamePrefix()+StrUtil.lPad((pdfNum+1).toString(),3)+'.pdf';

				if(altPdf){
					command=new IMCommand(IMCommand.IM_CMD_PDF_TOOL);
					command.folder=command2.folder;
					/*
					//set out file
					////jpeg2pdf.exe -o tst.pdf -p auto -m 0mm -z none -r none -k phcycle  *.jpg
					command.add('-o'); command.add(outPath(pdfName));
					IMCommandUtil.setPDFOutputParams(command);
					*/
				}else{
					command=new IMCommand(IMCommand.IM_CMD_CONVERT);
					command.folder=command2.folder;
				}
				
				for(i=0;i<pageLimit;i++){
					//parm idx
					idx=pdfNum*pageLimit+i;
					if(revers){
						//revers
						idx=command2.parameters.length-1-idx;
					}
					//check if out of command2.parameters.length
					if(idx<0 || idx>=command2.parameters.length) break;
					command.add(command2.parameters[idx]);
				}
				
				//finalize pdf command
				if(altPdf){
					//pdftk *.pdf cat output combined.pdf
					command.add('cat'); 
					command.add('output');
					command.add(outPath(pdfName));
				}else{
					IMCommandUtil.setPDFOutputParams(command,jpgQuality);
					command.add(outPath(pdfName));
				}
				
				commands.push(command);
				//add to printGroup.files
				newFile= new PrintGroupFile();
				newFile.file_name=pdfName;
				newFile.prt_qty=1;
				printGroup.addFile(newFile);
			}
			totalCommands+=commands.length;
			sequences.push(commands);
		}

	}
}