package com.photodispatcher.provider.preprocess{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.model.BookSynonym;
	import com.photodispatcher.model.mysql.entities.OrderState;
	import com.photodispatcher.model.PrintGroup;
	import com.photodispatcher.model.PrintGroupFile;
	import com.photodispatcher.shell.IMCommand;
	import com.photodispatcher.util.StrUtil;
	
	import flash.filesystem.File;
	
	public class PDFsimpleMakeupGroup extends BookMakeupGroup{
		
		public static const TEMP_FOLDER:String='wrk';

		public function PDFsimpleMakeupGroup(printGroup:PrintGroup, order_id:String, folder:String, prtFolder:String){
			super(printGroup, order_id, folder, prtFolder);
		}
		
		override public function createCommands():void{
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
			var newFile:PrintGroupFile;
			var command:IMCommand;
			var command2:IMCommand;
			var outName:String;
			var pageLimit:int=Context.getAttribute('pdfPageLimit');
			if(!pageLimit) pageLimit=100;
			var pdfPageNum:int=0;
			var pdfName:String;

			
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
				if(pdfPageNum==pageLimit){
					//finalyze pdf cmd
					pdfName=printGroup.pdfFileNamePrefix+StrUtil.lPad(i.toString(),3)+'.pdf';
					command2.add('-compress'); command2.add('jpeg');
					command2.add(outPath(pdfName));
					finalCommands.push(command2);
					//add to printGroup.files
					newFile= new PrintGroupFile();
					newFile.file_name=pdfName;
					newFile.prt_qty=1;
					printGroup.addFile(newFile);
					//reset
					pdfPageNum=0;
					command2=new IMCommand(IMCommand.IM_CMD_CONVERT);
					command2.folder=folder;
				}
				it=files[i] as PrintGroupFile;
				if(!it){
					state=STATE_ERR;
					err=OrderState.ERR_PREPROCESS;
					err_msg='Не верный состав книги. Не определен файл №'+(i+1).toString();
					return;
				}
				command=createCommand(it,folder);
				//save
				outName= TEMP_FOLDER+File.separator+StrUtil.lPad(it.book_num.toString(),3)+'-'+StrUtil.lPad(it.page_num.toString(),2)+'.jpg';
				command.add(outName);
				commands.push(command);
				//add 2 final(pdf) cmd
				command2.add(outName);
				pdfPageNum++;
			}
			//finalyze pdf cmd
			pdfName=printGroup.pdfFileNamePrefix+StrUtil.lPad(i.toString(),3)+'.pdf';
			command2.add('-compress'); command2.add('jpeg');
			command2.add(outPath(pdfName));
			finalCommands.push(command2);
			//add to printGroup.files
			newFile= new PrintGroupFile();
			newFile.file_name=pdfName;
			newFile.prt_qty=1;
			printGroup.addFile(newFile);
			
			//expand format by tech
			if(printGroup.bookTemplate.tech_bar &&
				(printGroup.book_type==BookSynonym.BOOK_TYPE_BOOK || 
					printGroup.book_type==BookSynonym.BOOK_TYPE_JOURNAL || 
					printGroup.book_type==BookSynonym.BOOK_TYPE_LEATHER)){
				if(printGroup.bookTemplate.tech_add) printGroup.height+=printGroup.bookTemplate.tech_add;
			}
		}

	}
}