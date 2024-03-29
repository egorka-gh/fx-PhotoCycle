package com.photodispatcher.provider.preprocess{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.model.mysql.entities.BookSynonym;
	import com.photodispatcher.model.mysql.entities.OrderState;
	import com.photodispatcher.model.mysql.entities.PrintGroup;
	import com.photodispatcher.model.mysql.entities.PrintGroupFile;
	import com.photodispatcher.shell.IMCommand;
	import com.photodispatcher.util.IMCommandUtil;
	import com.photodispatcher.util.StrUtil;
	import com.photodispatcher.util.UnitUtil;
	
	import flash.filesystem.File;
	import flash.geom.Point;

	public class PDFmakeupGroup extends BookMakeupGroup{
		public static const TEXT_LEFT_OFFSET_PIX:int=522;
		public static const TEXT_TOP_OFFSET_PIX:int=2;
		public static const TEXT_OFFSET:String='+'+TEXT_LEFT_OFFSET_PIX.toString()+'+'+TEXT_TOP_OFFSET_PIX.toString();
		public static const TEXT_UNDERCOLOR:String='white';

		public static const TEMP_FOLDER:String='pdf_wrk';
		protected static const FILENAME_SHEET:String='sheet';
		protected static const FILENAME_COVER:String='cover';
		protected static const FILENAME_COVER_BACK:String='cover_back';
		
		//protected static const FILENAME_SHEET:String=TEMP_FOLDER+File.separator+'sheet';
		//protected static const FILENAME_COVER:String=TEMP_FOLDER+File.separator+'cover';
		//protected static const FILENAME_COVER_BACK:String=TEMP_FOLDER+File.separator+'cover_back';
		
		protected static const FONT_COVER_BACK:int=6;
		protected static const TEMP_FILE_TYPE:String='.jpg';//IM bug - broken jpg - use png or some else

		public function PDFmakeupGroup(printGroup:PrintGroup, order_id:String, folder:String, prtFolder:String){
			super(printGroup, order_id, folder, prtFolder);
		}
		
		private var altPdf:Boolean;
		
		override public function createCommands():void{
			if(Context.config && Context.config.pdf_quality>60) jpgQuality=Context.config.pdf_quality.toString();
			altPdf=Context.getAttribute("altPDF");
			
			sequences=[];
			totalCommands=0;
			var commands:Array=[];
			//finalCommands=[];
			
			if(state==STATE_ERR) return;
			if (!printGroup.bookTemplate) return; 
			if (!printGroup.is_pdf || printGroup.bookTemplate.is_sheet_ready) return;
			if (!printGroup.bookTemplate.sheet_width || !printGroup.bookTemplate.sheet_len
				|| ((!printGroup.bookTemplate.page_width || !printGroup.bookTemplate.page_len) 
					&& (printGroup.book_part==BookSynonym.BOOK_PART_BLOCK || printGroup.book_type==BookSynonym.BOOK_TYPE_JOURNAL))){
				state=STATE_ERR;
				err=OrderState.ERR_PREPROCESS;
				err_msg='Не верные параметры PDF';
				return;
			}

			var files:Array;
			var books:Array;
			var i:int;
			var j:int;
			var it:PrintGroupFile;
			var command:IMCommand;
			var command2:IMCommand;
			var outName:String;
			var pageSize:Point;
			var sheetSize:Point;
			var pageLimit:int=Context.getAttribute('pdfPageLimit');
			if(!pageLimit) pageLimit=30;
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
			var sh:PdfSheet;
			command2=new IMCommand(IMCommand.IM_CMD_CONVERT);
			//command2.folder=folder;
			command2.folder=wrkFolder.nativePath;

			if(printGroup.book_part==BookSynonym.BOOK_PART_COVER){
				//create covers pdf
				if(printGroup.book_type==BookSynonym.BOOK_TYPE_JOURNAL){
					for (i=0; i<(files.length/3); i++){
						//cover
						it=files[i*3] as PrintGroupFile;
						if(!it){
							state=STATE_ERR;
							err=OrderState.ERR_PREPROCESS;
							err_msg='Не определен файл обложки книга №'+(i+1).toString();
							return;
						}
						//back
						sh=new PdfSheet();
						sh.leftPage=files[1+i*3];
						sh.rightPage=files[2+i*3];
						if(buildMode==MODE_BUILD || (buildMode==MODE_REPRINT && (it.reprint || sh.reprint))){
							//crop & annotate cover
							command=createCoverCommand(it,folder);
							//save
							outName=FILENAME_COVER+(i+1).toString()+TEMP_FILE_TYPE;
							command.add(TEMP_FOLDER+File.separator+outName);
							commands.push(command);
							//add 2 final cmd
							command2.add(outName);
							
							//create back (1st sheet)
							pageSize= new Point(printGroup.bookTemplate.page_len,printGroup.bookTemplate.page_width);
							sheetSize= new Point(UnitUtil.mm2Pixels300(printGroup.height),printGroup.bookTemplate.sheet_width);
							command=sh.getCommand(pageSize,sheetSize,printGroup); 
							command.folder=folder;
							//expand (left side)
							IMCommandUtil.expandImageH(command,printGroup.bookTemplate.tech_add,'West');
							//save file
							IMCommandUtil.setOutputParams(command, altPdf?jpgQuality:'100');
							outName=FILENAME_COVER_BACK+(i+1).toString()+TEMP_FILE_TYPE;
							command.add(TEMP_FOLDER+File.separator+outName);
							commands.push(command);
							//add 2 pdf cmd
							command2.add(outName);
							//2 pages added
							//pdfPageNum=pdfPageNum+2;
							prints+=2;
						}
					}
				}else if(printGroup.book_type==BookSynonym.BOOK_TYPE_BOOK){
					var backName:String;
					//crop & annotate covers
					for (i=0; i<files.length; i++){
						it=files[i] as PrintGroupFile;
						if(!it){
							state=STATE_ERR;
							err=OrderState.ERR_PREPROCESS;
							err_msg='Не определен файл обложки книга №'+(i+1).toString();
							return;
						}
						if(buildMode==MODE_BUILD || (buildMode==MODE_REPRINT && it.reprint)){
							command=createCoverCommand(it,folder);
							//save
							outName=FILENAME_COVER+(i+1).toString()+TEMP_FILE_TYPE;
							command.add(TEMP_FOLDER+File.separator+outName);
							commands.push(command);
							//add 2 final cmd
							command2.add(outName);
							//pdfPageNum++;
							prints++;
						}
					}
				}
				//expand format by tech
				if(printGroup.bookTemplate.tech_bar &&
					(printGroup.book_type==BookSynonym.BOOK_TYPE_BOOK || 
						printGroup.book_type==BookSynonym.BOOK_TYPE_JOURNAL || 
						printGroup.book_type==BookSynonym.BOOK_TYPE_LEATHER)){
					if(printGroup.bookTemplate.tech_add) printGroup.height+=printGroup.bookTemplate.tech_add;
				}
			}else if(printGroup.book_part==BookSynonym.BOOK_PART_BLOCK){
				//create sheets pdf
				//check if pageNum is even
				if((files.length % 2)!=0){
					state=STATE_ERR;
					err=OrderState.ERR_PREPROCESS;
					err_msg='Не четное количество страниц '+files.length.toString();
					return;
				}
				
				//create sheets & apply order 
				var sheets:Array=createSheets(files);
				//create commands
				
				// height-format width, width- format length
				pageSize= new Point(printGroup.bookTemplate.page_len,printGroup.bookTemplate.page_width);
				sheetSize= new Point(printGroup.bookTemplate.sheet_len,printGroup.bookTemplate.sheet_width);
				for (i=0;i<sheets.length;i++){
					//process sheet
					sh=sheets[i] as PdfSheet;
					if(buildMode==MODE_BUILD || (buildMode==MODE_REPRINT && sh.reprint)){
						command=sh.getCommand(pageSize,sheetSize,printGroup);
						//draw stair
						drawSheetStair(command,sh,sheetSize, i);
						//draw tech barcode
						drawSheetTechBar(command, i);
						//draw mark
						IMCommandUtil.drawMark(command,printGroup.bookTemplate.mark_size,printGroup.bookTemplate.mark_offset);

						command.folder=folder;
						//save file
						IMCommandUtil.setOutputParams(command, altPdf?jpgQuality:'100');
						outName=FILENAME_SHEET+(i+1).toString()+TEMP_FILE_TYPE;
						command.add(TEMP_FOLDER+File.separator+outName);
						commands.push(command);
						//add 2 pdf cmd
						command2.add(outName);
						//page added
						//pdfPageNum++;
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
			}
			
			totalCommands+=commands.length;
			sequences.push(commands);
			
			//finalize
			if(buildMode==MODE_REPRINT) printGroup.prints=prints;
			
			var idx:int;

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

		private function createSheets(files:Array):Array{
			if(!files || files.length==0) return [];
			var result:Array=[];
			var len:int;
			var i:int=0;
			var j:int=0;
			var sh:PdfSheet;
			//create sheets 
			if(printGroup.book_type==BookSynonym.BOOK_TYPE_BOOK || printGroup.book_type==BookSynonym.BOOK_TYPE_LEATHER){
				len=files.length/2;
				if(printGroup.is_duplex){
					//full set order 4 cutting 
					for (i=0; i<len;i++){
						sh=new PdfSheet();
						sh.leftPage=files[i];
						sh.rightPage=files[files.length-1-i];
						result.push(sh);
					}
				}else{
					//no cutting
					for (i=0; i<len;i++){
						sh=new PdfSheet();
						sh.leftPage=files[i*2];
						sh.rightPage=files[i*2+1];
						result.push(sh);
					}
				}
			}else if(printGroup.book_type==BookSynonym.BOOK_TYPE_JOURNAL){
				//order inside book (no cutting)
				var subSet:Array;
				len=files.length/printGroup.book_num;
				for (i=0;i<printGroup.book_num;i++){
					subSet=files.slice(i*len,(i+1)*len);
					if(!subSet || subSet.length!=len){
						state=STATE_ERR;
						err=OrderState.ERR_PREPROCESS;
						err_msg='Не верное количество страниц ожидалось '+len.toString();
						return [];
					}
					for (j=0; j<len/2;j++){
						sh=new PdfSheet();
						sh.leftPage=subSet[j];
						sh.rightPage=subSet[subSet.length-1-j];
						result.push(sh);
					}
				}
			}
			
			if(printGroup.is_duplex || printGroup.book_type==BookSynonym.BOOK_TYPE_JOURNAL){ //JOURNAL ???
				//swap pages on even sheets (back)
				i=0;
				while(i<result.length){
					sh=result[i] as PdfSheet;
					sh.swapPages();
					//mark reprint 4 duplex
					if(buildMode==MODE_REPRINT && printGroup.is_duplex){
						//херпойми
						(result[i+1] as PdfSheet).reprint=sh.reprint;
						sh.reprint=(result[i+1] as PdfSheet).reprint;
					}
					i+=2;
				}
			}
			return result; 
		}

		private function drawSheetStair(command:IMCommand, sheet:PdfSheet, sheetSize:Point, sheetIndex:int):void{
			//expand verticaly
			if(printGroup.bookTemplate.tech_stair_add){
				if(printGroup.bookTemplate.is_tech_stair_top){
					IMCommandUtil.expandImageV(command,printGroup.bookTemplate.tech_stair_add);
				}
				if(printGroup.bookTemplate.is_tech_stair_bot){
					IMCommandUtil.expandImageV(command,printGroup.bookTemplate.tech_stair_add,'South');
				}
			}

			//draw stair
			if(!printGroup.bookTemplate.tech_stair_add || !printGroup.bookTemplate.tech_stair_step || 
				(!printGroup.bookTemplate.is_tech_stair_bot && !printGroup.bookTemplate.is_tech_stair_top)) return;
			if(!sheet || (!sheet.leftPage && !sheet.rightPage)) return;
			
			//var fieldMM:int=printGroup.bookTemplate.tech_stair_add;
			var field:int=UnitUtil.mm2Pixels300(printGroup.bookTemplate.tech_stair_add);
			var step:int=UnitUtil.mm2Pixels300(printGroup.bookTemplate.tech_stair_step);
			var stepsPerPage:int=Math.floor((sheetSize.x/2)/step);
			if(stepsPerPage==0) return;
			var isFront:Boolean=!printGroup.is_duplex || (sheetIndex % 2)==0;

			var lOffset:int=-1;
			if(sheet.leftPage){
				lOffset=((sheet.leftPage.book_num-1) % stepsPerPage)*step;
				if(!isFront) lOffset=(sheetSize.x/2)-lOffset-step;
			}
			var rOffset:int=-1;
			if(sheet.rightPage){
				rOffset=((sheet.rightPage.book_num-1) % stepsPerPage)*step;
				if(isFront){
					rOffset+=(sheetSize.x/2);
				}else{
					rOffset=sheetSize.x-rOffset-step;
				}
			}
			var yOffset:int=sheetSize.y;

			command.add('-stroke'); command.add('none');
			command.add('-strokewidth'); command.add('0');
			command.add('-fill'); command.add('black');
			if(printGroup.bookTemplate.is_tech_stair_top){
				yOffset+=field;
				//IMCommandUtil.expandImageV(command,fieldMM);
				if(lOffset!=-1) IMCommandUtil.drawRectangle(command,lOffset,0,step,field);
				if(rOffset!=-1) IMCommandUtil.drawRectangle(command,rOffset,0,step,field);
			}
			if(printGroup.bookTemplate.is_tech_stair_bot){
				//IMCommandUtil.expandImageV(command,fieldMM,'South');
				if(lOffset!=-1) IMCommandUtil.drawRectangle(command,lOffset,yOffset,step,field);
				if(rOffset!=-1) IMCommandUtil.drawRectangle(command,rOffset,yOffset,step,field);
			}
		}

		private function drawSheetTechBar(command:IMCommand, sheetIndex:int):void{
			if(!printGroup.bookTemplate.tech_bar) return;

			var barSize:int=UnitUtil.mm2Pixels300(printGroup.bookTemplate.tech_bar);
			var sheet:int;
			var book:int;
			var barcode:String;
			var drawBar:Boolean;
			
			if(printGroup.is_duplex){
				//draw on even sheetIndex
				drawBar=(sheetIndex % 2)==0;
				//calc sheet/book
				if(drawBar){
					sheet=Math.floor(sheetIndex/2)+1;
					book=Math.ceil(sheet/printGroup.sheet_num);
					sheet=sheet-printGroup.sheet_num*(book-1);
					barcode=printGroup.techBarcode(book, printGroup.book_num, sheet, printGroup.sheet_num);
				}
			}else{
				//draw on all sheets
				drawBar=true;
				sheet=sheetIndex+1;
				book=Math.ceil(sheet/printGroup.sheet_num);
				sheet=sheet-printGroup.sheet_num*(book-1);
				barcode=printGroup.techBarcode(book,printGroup.book_num,sheet,printGroup.sheet_num);
			}
			
			var barOffset:String;
			var gravity:String;
			//draw 
			if(drawBar){
				//draw tech barcode
				if(printGroup.bookTemplate.is_tech_top || printGroup.bookTemplate.is_tech_center || printGroup.bookTemplate.is_tech_bot){
					//expand
					IMCommandUtil.expandImageH(command,printGroup.bookTemplate.tech_add);
					if(barcode){
						//create bar and write to mpr
						var barCommand:IMCommand=new IMCommand();
						IMCommandUtil.createBarcode(folder,barCommand,barSize,barcode,'',-90, printGroup.bookTemplate.tech_bar_step,parseInt(printGroup.bookTemplate.tech_bar_color,16));
						IMCommandUtil.addLabeledMPR(barCommand,command,'techBar');

						barOffset=printGroup.bookTemplate.tech_bar_offset;
						if(!barOffset) barOffset='+0+0';
						gravity='east';
						if(printGroup.bookTemplate.is_tech_center){
							//IMCommandUtil.drawBarcode(folder,command,barSize,barcode,'',barOffset,-90,gravity,printGroup.bookTemplate.tech_bar_step,parseInt(printGroup.bookTemplate.tech_bar_color,16));
							IMCommandUtil.readLabeledMPR(command,'techBar');
							IMCommandUtil.composite(command,barOffset,gravity);
						}
						if(printGroup.bookTemplate.is_tech_top){
							barOffset=printGroup.bookTemplate.tech_bar_toffset;
							if(!barOffset) barOffset='+0+0';
							gravity='NorthEast';
							//IMCommandUtil.drawBarcode(folder,command,barSize,barcode,'',barOffset,-90,gravity,printGroup.bookTemplate.tech_bar_step,parseInt(printGroup.bookTemplate.tech_bar_color,16));
							IMCommandUtil.readLabeledMPR(command,'techBar');
							IMCommandUtil.composite(command,barOffset,gravity);
						}
						if(printGroup.bookTemplate.is_tech_bot){
							barOffset=printGroup.bookTemplate.tech_bar_boffset;
							if(!barOffset) barOffset='+0+0';
							gravity='SouthEast';
							//IMCommandUtil.drawBarcode(folder,command,barSize,barcode,'',barOffset,-90,gravity,printGroup.bookTemplate.tech_bar_step,parseInt(printGroup.bookTemplate.tech_bar_color,16));
							IMCommandUtil.readLabeledMPR(command,'techBar');
							IMCommandUtil.composite(command,barOffset,gravity);
						}
					}
				}
			}else{
				//expand (left side) for duplex
				IMCommandUtil.expandImageH(command,printGroup.bookTemplate.tech_add,'West');
			}
	
		}
		
		private function createCoverBack(fileName:String,file:PrintGroupFile, folder:String):IMCommand{
			//create empty white sheet vs butt lines
			var buttPix:int=UnitUtil.mm2Pixels300(printGroup.butt);
			var width:int=printGroup.bookTemplate.sheet_width;
			var len:int=UnitUtil.mm2Pixels300(printGroup.height);//printGroup.bookTemplate.sheet_len;
			var command:IMCommand=new IMCommand(IMCommand.IM_CMD_CONVERT);
			//empty sheet
			command.add('-size'); command.add(len.toString()+'x'+width.toString());
			command.add('xc:white');
			//annotate
			var txt:String=printGroup.annotateText(file);
			if(txt && printGroup.staffActivityCaption) txt=txt+' '+printGroup.staffActivityCaption;
			IMCommandUtil.annotateImage(command,FONT_COVER_BACK,TEXT_UNDERCOLOR,txt,TEXT_OFFSET);
			if(buttPix){
				//-fill black  -draw "line 2775,907 2775,2907 line 1775,1907 3775,1907"
				var xl:int=(len-buttPix)/2;
				var xr:int=xl+buttPix;
				command.add('-fill'); command.add('black');
				command.add('-draw');
				command.add('line '+xl.toString()+',0 '+xl.toString()+','+width.toString()+' line '+xr.toString()+',0 '+xr.toString()+','+width.toString());
			}

			//draw tech barcode
			if(printGroup.bookTemplate.tech_bar && 
				(printGroup.bookTemplate.is_tech_top || printGroup.bookTemplate.is_tech_center || printGroup.bookTemplate.is_tech_bot)){
				IMCommandUtil.expandImageH(command,printGroup.bookTemplate.tech_add,'West');
				//mm to pix
				var barSize:int=UnitUtil.mm2Pixels300(printGroup.bookTemplate.tech_bar);
				var barcode:String=printGroup.techBarcodeByFile(file);
				if(barcode){
					//create bar and write to mpr
					var barCommand:IMCommand=new IMCommand();
					IMCommandUtil.createBarcode(folder,barCommand,barSize,barcode,'',-90, printGroup.bookTemplate.tech_bar_step,parseInt(printGroup.bookTemplate.tech_bar_color,16));
					IMCommandUtil.addLabeledMPR(barCommand,command,'techBar');

					var barOffset:String=printGroup.bookTemplate.tech_bar_offset;
					if(!barOffset) barOffset='+0+0';
					var gravity:String='West';
					if(printGroup.bookTemplate.is_tech_center){
						//IMCommandUtil.drawBarcode(folder,command,barSize,barcode,'',barOffset,-90,gravity,printGroup.bookTemplate.tech_bar_step,parseInt(printGroup.bookTemplate.tech_bar_color,16));
						IMCommandUtil.readLabeledMPR(command,'techBar');
						IMCommandUtil.composite(command,barOffset,gravity);
					}
					if(printGroup.bookTemplate.is_tech_top){
						barOffset=printGroup.bookTemplate.tech_bar_toffset;
						if(!barOffset) barOffset='+0+0';
						gravity='NorthWest';
						//IMCommandUtil.drawBarcode(folder,command,barSize,barcode,'',barOffset,-90,gravity,printGroup.bookTemplate.tech_bar_step,parseInt(printGroup.bookTemplate.tech_bar_color,16));
						IMCommandUtil.readLabeledMPR(command,'techBar');
						IMCommandUtil.composite(command,barOffset,gravity);
					}
					if(printGroup.bookTemplate.is_tech_bot){
						barOffset=printGroup.bookTemplate.tech_bar_boffset;
						if(!barOffset) barOffset='+0+0';
						gravity='SouthWest';
						//IMCommandUtil.drawBarcode(folder,command,barSize,barcode,'',barOffset,-90,gravity,printGroup.bookTemplate.tech_bar_step,parseInt(printGroup.bookTemplate.tech_bar_color,16));
						IMCommandUtil.readLabeledMPR(command,'techBar');
						IMCommandUtil.composite(command,barOffset,gravity);
					}
				}
			}
			IMCommandUtil.setOutputParams(command, altPdf?jpgQuality:'100');
			command.add(fileName);
			return command;
		}

		private function createCoverCommand(file:PrintGroupFile, folder:String):IMCommand{
			var buttPix:int=UnitUtil.mm2Pixels300(printGroup.butt);
			var width:int=printGroup.bookTemplate.sheet_width;
			var len:int=UnitUtil.mm2Pixels300(printGroup.height);//printGroup.bookTemplate.sheet_len;
			var command:IMCommand=new IMCommand(IMCommand.IM_CMD_CONVERT);
			command.folder=folder;
			var sheetCrop:String=len.toString()+'x'+width.toString()+'+0+0!';
			//crop
			command.add('-gravity'); command.add('Center');
			command.add('-background'); command.add('white');
			command.add(file.file_name);
			command.add('-crop'); command.add(sheetCrop);
			command.add('-flatten');
			annotateCommand(command,file);
			if(printGroup.bookTemplate.notching>0 && buttPix){
				IMCommandUtil.drawNotching(command,printGroup.bookTemplate.notching,len,width,buttPix);
			}

			var barcode:String;
			//draw barcode
			if(printGroup.bookTemplate.bar_size>0){
				//var barcode:String=printGroup.bookBarcodeText(file);
				barcode=printGroup.bookBarcode(file);
				if(barcode) IMCommandUtil.drawBarcode(folder,command,printGroup.bookTemplate.bar_size,barcode, printGroup.bookBarcodeText(file),printGroup.bookTemplate.bar_offset,0,'southwest',3,0,10);
			}
			//draw tech barcode
			if(printGroup.bookTemplate.tech_bar && 
				(printGroup.bookTemplate.is_tech_top || printGroup.bookTemplate.is_tech_center || printGroup.bookTemplate.is_tech_bot)){
				//mm to pix
				IMCommandUtil.expandImageH(command,printGroup.bookTemplate.tech_add);
				var barSize:int=UnitUtil.mm2Pixels300(printGroup.bookTemplate.tech_bar);
				barcode=printGroup.techBarcodeByFile(file);
				if(barcode){
					//create bar and write to mpr
					var barCommand:IMCommand=new IMCommand();
					IMCommandUtil.createBarcode(folder,barCommand,barSize,barcode,'',-90, printGroup.bookTemplate.tech_bar_step,parseInt(printGroup.bookTemplate.tech_bar_color,16));
					IMCommandUtil.addLabeledMPR(barCommand,command,'techBar');
					
					var barOffset:String=printGroup.bookTemplate.tech_bar_offset;
					if(!barOffset) barOffset='+0+0';
					var gravity:String='east';
					if(printGroup.bookTemplate.is_tech_center){
						//IMCommandUtil.drawBarcode(folder,command,barSize,barcode,'',barOffset,-90,gravity,printGroup.bookTemplate.tech_bar_step,parseInt(printGroup.bookTemplate.tech_bar_color,16));
						IMCommandUtil.readLabeledMPR(command,'techBar');
						IMCommandUtil.composite(command,barOffset,gravity);
					}
					if(printGroup.bookTemplate.is_tech_top){
						barOffset=printGroup.bookTemplate.tech_bar_toffset;
						if(!barOffset) barOffset='+0+0';
						gravity='NorthEast';
						//IMCommandUtil.drawBarcode(folder,command,barSize,barcode,'',barOffset,-90,gravity,printGroup.bookTemplate.tech_bar_step,parseInt(printGroup.bookTemplate.tech_bar_color,16));
						IMCommandUtil.readLabeledMPR(command,'techBar');
						IMCommandUtil.composite(command,barOffset,gravity);
					}
					if(printGroup.bookTemplate.is_tech_bot){
						barOffset=printGroup.bookTemplate.tech_bar_boffset;
						if(!barOffset) barOffset='+0+0';
						gravity='SouthEast';
						//IMCommandUtil.drawBarcode(folder,command,barSize,barcode,'',barOffset,-90,gravity,printGroup.bookTemplate.tech_bar_step,parseInt(printGroup.bookTemplate.tech_bar_color,16));
						IMCommandUtil.readLabeledMPR(command,'techBar');
						IMCommandUtil.composite(command,barOffset,gravity);
					}
				}
			}
			
			//vertical annotate
			IMCommandUtil.annotateImageV(command,printGroup.bookTemplate.fontv_size, printGroup.annotateText(file),printGroup.bookTemplate.fontv_offset,TEXT_UNDERCOLOR);  	
			IMCommandUtil.annotateImageV(command,printGroup.bookTemplate.reprint_size, printGroup.staffActivityCaption,printGroup.bookTemplate.reprint_offset,TEXT_UNDERCOLOR);  	

			//draw mark
			IMCommandUtil.drawMark(command,printGroup.bookTemplate.mark_size,printGroup.bookTemplate.mark_offset);

			IMCommandUtil.setOutputParams(command, altPdf?jpgQuality:'100');
			return command;
		}

		private function annotateCommand(command:IMCommand,file:PrintGroupFile):void{
			if(!command || !file) return;
			var strOff:String=printGroup.bookTemplate.font_offset;
			if(!strOff) strOff=TEXT_OFFSET;
			var txt:String=printGroup.annotateText(file);
			if(txt && printGroup.staffActivityCaption) txt=txt+' '+printGroup.staffActivityCaption;
			IMCommandUtil.annotateImage(command,printGroup.bookTemplate.font_size,TEXT_UNDERCOLOR,txt, strOff);
		}

	}
}