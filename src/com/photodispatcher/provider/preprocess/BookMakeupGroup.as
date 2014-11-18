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
	import flash.geom.Rectangle;

	public class BookMakeupGroup{
		public static const TEXT_LEFT_OFFSET_PIX:int=500;
		public static const TEXT_TOP_OFFSET_PIX:int=0;
		public static const TEXT_OFFSET:String='+'+TEXT_LEFT_OFFSET_PIX.toString()+'+'+TEXT_TOP_OFFSET_PIX.toString();
		//public static const TEXT_UNDERCOLOR:String='#ffffff80';
		public static const TEXT_UNDERCOLOR:String='white';
		
		public static const STATE_WAITE:int=0;
		public static const STATE_STARTED:int=1;
		public static const STATE_COMPLITE:int=2;
		public static const STATE_ERR:int=3;

		public var printGroup:PrintGroup;
		public var order_id:String;
		public var folder:String;
		public var prtFolder:String;
		
		//public var template:PdfTemplate;
		//public var command:IMCommand;
		public var commands:Array;
		public var finalCommands:Array;
		public var err:int;
		public var err_msg:String;

		public var state:int=STATE_WAITE;
		
		public function BookMakeupGroup(printGroup:PrintGroup, order_id:String, folder:String, prtFolder:String){
			this.printGroup=printGroup;
			this.order_id=order_id;
			this.folder=folder+File.separator+printGroup.path;
			this.prtFolder=prtFolder+File.separator+printGroup.path;
			var threads:int=Context.getAttribute('imThreads');
			if(!threads || threads<1){
				state=STATE_ERR;
				err=OrderState.ERR_PREPROCESS;
				err_msg='Не настроен ImageMagick';
			}
			//createCommands();
		}

		public function createCommands():void{
			commands=[];
			finalCommands=[];

			if(state==STATE_ERR) return;
			if (printGroup.is_pdf) return;
			if (!printGroup.bookTemplate 
				|| !printGroup.bookTemplate.sheet_width || !printGroup.bookTemplate.sheet_len){
				return;
			}

			var files:Array;
			var i:int;
			var it:PrintGroupFile;
			var newFile:PrintGroupFile;
			var command:IMCommand;
			var outName:String;
			
			files=printGroup.bookFiles;
			if(!files || files.length==0){
				state=STATE_ERR;
				err=OrderState.ERR_PREPROCESS;
				err_msg='Пустая группа печати';
				return;
			}

			printGroup.resetFiles();
			trace('BookMakeupGroup:'+printGroup.id+
				'; booktype-'+printGroup.book_type.toString()+
				'; part-'+printGroup.book_part.toString()+
				'; heigh-'+printGroup.height.toString()+
				'; sheet_len-'+printGroup.bookTemplate.sheet_len.toString());
			//prepare sheets
			for (i=0; i<files.length; i++){
				it=files[i] as PrintGroupFile;
				if(!it){
					state=STATE_ERR;
					err=OrderState.ERR_PREPROCESS;
					err_msg='Не верный состав книги. Не определен файл №'+(i+1).toString();
					return;
				}
				command=createCommand(it,folder);
				//save
				outName= PrintGroup.SUBFOLDER_PRINT+File.separator+StrUtil.lPad(it.book_num.toString(),3)+'-'+StrUtil.lPad(it.page_num.toString(),2)+'.jpg';
				newFile=it.clone();
				newFile.file_name=outName;
				printGroup.addFile(newFile);
				//if(folder!=prtFolder) outName=prtFolder+File.separator+outName;
				command.add(outPath(outName));
				commands.push(command);
			}
			
			//expand format by tech
			if(printGroup.bookTemplate.tech_bar &&
				(printGroup.book_type==BookSynonym.BOOK_TYPE_BOOK || 
					printGroup.book_type==BookSynonym.BOOK_TYPE_JOURNAL || 
					printGroup.book_type==BookSynonym.BOOK_TYPE_LEATHER)){
				if(printGroup.bookTemplate.tech_add) printGroup.height+=printGroup.bookTemplate.tech_add;
			}
		}
		
		protected function outPath(path:String):String{
			var result:String=path;
			if(folder!=prtFolder) result=prtFolder+File.separator+result;
			return result;
		}
		
		public function get hasCommands():Boolean{
			return (commands && commands.length>0);// || (finalCommands && finalCommands.length>0); 
		}

		protected function createCommand(file:PrintGroupFile, folder:String):IMCommand{
			
			var buttPix:int=UnitUtil.mm2Pixels300(printGroup.butt);
			var width:int=printGroup.bookTemplate.sheet_width;
			var len:int=printGroup.bookTemplate.sheet_len;
			if(printGroup.book_part==BookSynonym.BOOK_PART_COVER) len=UnitUtil.mm2Pixels300(printGroup.height);
			var command:IMCommand=new IMCommand(IMCommand.IM_CMD_CONVERT);
			command.folder=folder;

			trace('BookMakeupGroup.createCommand:'+printGroup.id+
				'; booktype-'+printGroup.book_type.toString()+
				'; bookpart-'+printGroup.book_part.toString()+
				'; heigh-'+printGroup.height.toString()+
				'; sheet_len-'+len.toString());

			//crop
			var sheetCrop:String=len.toString()+'x'+width.toString()+'+0+0!';
			//var line:String;
			command.add('-gravity'); command.add('Center');
			command.add('-background'); command.add('white');
			command.add(file.file_name);
			command.add('-crop'); command.add(sheetCrop);
			command.add('-flatten');
			
			//annotate 
			annotateCommand(command,file);
			
			//draw notching
			if(printGroup.bookTemplate.notching>0){
				var notching:int=printGroup.bookTemplate.notching;
				if(printGroup.book_part==BookSynonym.BOOK_PART_COVER){
					if(buttPix){
						IMCommandUtil.drawNotching(command,notching,len,width,buttPix);
					}
				}else if(printGroup.book_part==BookSynonym.BOOK_PART_BLOCK){
					IMCommandUtil.drawNotching(command,notching,len,width,0);
				}
			}
			
			//draw farme
			if(printGroup.bookTemplate.stroke>0){
				//-fill none -stroke black -strokewidth 9 -draw "rectangle 0,0 500,500"
				var stroke:int=printGroup.bookTemplate.stroke;	
				var offs:int=stroke/2;
				var rect:Rectangle= new Rectangle(offs,offs,len-offs,width-offs);
				command.add('-fill'); command.add('none');
				command.add('-stroke'); command.add('black');
				command.add('-strokewidth'); command.add(stroke.toString());
				var draw:String='rectangle '+rect.x.toString()+','+rect.y.toString()+' '+rect.width.toString()+','+rect.height.toString();
				command.add('-draw'); command.add(draw);
			}
			
			//draw cover barcode
			var barcode:String
			if(printGroup.bookTemplate.bar_size>0 && printGroup.book_part==BookSynonym.BOOK_PART_COVER){
				//barcode=printGroup.bookBarcodeText(file);
				barcode=printGroup.bookBarcode(file);
				if(barcode) IMCommandUtil.drawBarcode(folder, command,printGroup.bookTemplate.bar_size, barcode, printGroup.bookBarcodeText(file),printGroup.bookTemplate.bar_offset,0,'southwest',3,0,10);
			}

			//draw body caption
			if(printGroup.bookTemplate.bar_size>0 && printGroup.book_part==BookSynonym.BOOK_PART_BLOCK && file.page_num==printGroup.pageNumber){
				barcode=printGroup.bookBarcodeText(file);
				if(barcode) IMCommandUtil.annotateTransparent(command,printGroup.bookTemplate.bar_size, barcode, printGroup.bookTemplate.bar_offset,-90);
			}

			//draw tech barcode
			var barSize:int=printGroup.bookTemplate.tech_bar;
			if(barSize &&
				(printGroup.book_type==BookSynonym.BOOK_TYPE_BOOK || 
					printGroup.book_type==BookSynonym.BOOK_TYPE_JOURNAL || 
					printGroup.book_type==BookSynonym.BOOK_TYPE_LEATHER) &&
				(printGroup.bookTemplate.is_tech_top || printGroup.bookTemplate.is_tech_center || printGroup.bookTemplate.is_tech_bot)){
				//var barStep:int=printGroup.bookTemplate.tech_bar_step;
				var barColor:int=parseInt(printGroup.bookTemplate.tech_bar_color,16);
				
				IMCommandUtil.expandImageH(command,printGroup.bookTemplate.tech_add);
				
				//mm to pix
				barSize=UnitUtil.mm2Pixels300(barSize);
				barcode=printGroup.techBarcodeByFile(file);
				//var txt:String=printGroup.techBarcodeText(file);
				if(barcode){
					var barOffset:String=printGroup.bookTemplate.tech_bar_offset;
					if(!barOffset) barOffset='+0+0';
					var gravity:String='east';
					if(printGroup.bookTemplate.is_tech_center){
						IMCommandUtil.drawBarcode(folder,command,barSize,barcode,'',barOffset,-90,gravity,printGroup.bookTemplate.tech_bar_step,barColor);
					}
					if(printGroup.bookTemplate.is_tech_top){
						barOffset=printGroup.bookTemplate.tech_bar_toffset;
						if(!barOffset) barOffset='+0+0';
						gravity='NorthEast';
						IMCommandUtil.drawBarcode(folder,command,barSize,barcode,'',barOffset,-90,gravity,printGroup.bookTemplate.tech_bar_step,barColor);
					}
					if(printGroup.bookTemplate.is_tech_bot){
						barOffset=printGroup.bookTemplate.tech_bar_boffset;
						if(!barOffset) barOffset='+0+0';
						gravity='SouthEast';
						IMCommandUtil.drawBarcode(folder,command,barSize,barcode,'',barOffset,-90,gravity,printGroup.bookTemplate.tech_bar_step,barColor);
					}
				}
			}
			
			if(printGroup.bookTemplate.fontv_size){
				IMCommandUtil.annotateImageV(command,printGroup.bookTemplate.fontv_size, printGroup.annotateText(file),printGroup.bookTemplate.fontv_offset,TEXT_UNDERCOLOR);  	
			}
			
			//complete
			/*
			command.add('-density'); command.add('300x300');
			command.add('-quality'); command.add('100');
			*/
			IMCommandUtil.setOutputParams(command);
			return command;
		}

		private function annotateCommand(command:IMCommand,file:PrintGroupFile):void{
			if(!command || !file) return;
			var offset:String=printGroup.bookTemplate.font_offset;
			if(!offset) offset=TEXT_OFFSET;
			IMCommandUtil.annotateImage(command,printGroup.bookTemplate.font_size,TEXT_UNDERCOLOR,printGroup.annotateText(file),offset,true);
		}

	}
}