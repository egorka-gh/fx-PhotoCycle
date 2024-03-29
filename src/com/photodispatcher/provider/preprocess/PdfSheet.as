package com.photodispatcher.provider.preprocess{
	import com.photodispatcher.model.mysql.entities.PrintGroup;
	import com.photodispatcher.model.mysql.entities.PrintGroupFile;
	import com.photodispatcher.shell.IMCommand;
	import com.photodispatcher.util.IMCommandUtil;
	
	import flash.geom.Point;

	public class PdfSheet{
		public static const TEXT_TOP_OFFSET_PIX:int=2;

		public var leftPage:PrintGroupFile;
		public var rightPage:PrintGroupFile;
		
		public function swapPages():void{
			var p:PrintGroupFile=rightPage;
			rightPage=leftPage;
			leftPage=p;
		}
		
		private var _reprint:Boolean;
		public function get reprint():Boolean{
			return _reprint || (leftPage && leftPage.reprint) || (rightPage && rightPage.reprint);
		}
		public function set reprint(val:Boolean):void{
			_reprint=val;
		}
		
		public function getCommand(pageSize:Point,sheetSize:Point, printGroup:PrintGroup):IMCommand{
			var command:IMCommand=new IMCommand(IMCommand.IM_CMD_CONVERT);
			var width:String=sheetSize.x.toString();
			var height:String=sheetSize.y.toString();
			if(!leftPage && !rightPage){
				//empty sheet
				//command.add('-size'); command.add(sheetSize.x.toString()+'x'+sheetSize.y.toString());
				command.add('-size'); command.add(width+'x'+height);
				command.add('xc:white');
			}else{
				//var sheetCrop:String=sheetSize.x.toString()+'x'+sheetSize.y.toString()+'+0+0!';
				var sheetCrop:String=width+'x'+height+'+0+0!';
				/*
				command.add('-gravity'); command.add('Center');
				command.add('-background'); command.add('white');
				*/
				//left
				command.add('(');
				addPage(command, leftPage, pageSize, printGroup);
				command.add(')');
				/*
				command.add('-flatten');
				annotateCommand(printGroup,command,leftPage);
				*/
				//right
				command.add('(');
				addPage(command, rightPage, pageSize, printGroup,true);
				command.add(')');
				
				command.add('+append');
				command.add('-flatten');
				//annotateCommand(printGroup,command,rightPage,pageSize.x);
				
				//apply sheet crop
				command.add('-gravity'); command.add('center');
				command.add('-background'); command.add('white');
				command.add('-crop'); command.add(sheetCrop);
				command.add('-flatten');
			}
			//draw notching
			IMCommandUtil.drawNotching(command,printGroup.bookTemplate.notching,sheetSize.x,sheetSize.y,0);
			return command;
		}
		
		private function addPage(command:IMCommand, page:PrintGroupFile, pageSize:Point, printGroup:PrintGroup, isRightPage:Boolean=false):void{
			var width:String=pageSize.x.toString();
			var height:String=pageSize.y.toString();
			
			var offset:int=printGroup.bookTemplate.page_hoffset*-1;
			var offsetSign:String=offset>=0?'+':'-';
			if (isRightPage) offsetSign=offset>=0?'-':'+';
			if (printGroup.is_horizontal){
				width=pageSize.y.toString();
				height=pageSize.x.toString();
				offset=offset*-1;
				offsetSign=offset>=0?'+':'-';
			}
			offset=Math.abs(offset);

			if(!page){
				//empty sheet
				//command.add('-size'); command.add(pageSize.x.toString()+'x'+pageSize.y.toString());
				command.add('-size'); command.add(width+'x'+height);
				command.add('xc:white');
			}else{
				//( -gravity center -background "white" 001-01.jpg -crop "3650x2563+0+0!" -flatten -gravity NorthWest -pointsize "33" -undercolor "white" -annotate "+522+22"  "16938-1 01/01-01/26" -rotate "90" )
				//var pageCrop:String=pageSize.x.toString()+'x'+pageSize.y.toString()+'+0+0!';
				var pageCrop:String=width+'x'+height;//+'+0+0!';
				if (printGroup.is_horizontal){
					pageCrop=pageCrop+'+0'+offsetSign+offset.toString()+'!';
				}else{
					pageCrop=pageCrop+offsetSign+offset.toString()+'+0!';
				}

				command.add('-gravity'); command.add('center');
				command.add('-background'); command.add('white');
				command.add(page.file_name);
				command.add('-crop'); command.add(pageCrop);
				command.add('-flatten');
				//annotate
				annotateCommand(printGroup,command,page);
				//draw body caption
				if(printGroup.bookTemplate.bar_size>0 && page.page_num==printGroup.pageNumber){
					var barcode:String=printGroup.bookBarcodeText(page);
					if(barcode) IMCommandUtil.annotateTransparent(command,printGroup.bookTemplate.bar_size, barcode, printGroup.bookTemplate.bar_offset,-90);
				}

			}
			//-rotate 90
			if (printGroup && printGroup.is_horizontal){
				command.add('-rotate');
				if(isRightPage){
					command.add('-90');
				}else{
					command.add('90');
				}
			}

		}

		private function annotateCommand(printGroup:PrintGroup,command:IMCommand,file:PrintGroupFile):void{
			if(!printGroup || !printGroup.bookTemplate || !printGroup.bookTemplate.font_size || !command || !file) return;
			//calc points 4 density 300
			var points:int=printGroup.bookTemplate.font_size*300/72;
			//-gravity NorthWest -pointsize 33 -undercolor "#ffffff80" -annotate "+23+23" " 123456_1 1/10 "
			command.add('-gravity'); command.add('NorthWest');
			command.add('-pointsize'); command.add(points.toString());
			command.add('-strokewidth'); command.add('0');
			command.add('-undercolor'); command.add(PDFmakeupGroup.TEXT_UNDERCOLOR);
			command.add('-fill'); command.add('black');
			var strOff:String=printGroup.bookTemplate.font_offset;
			if(!strOff) strOff ='+'+(PDFmakeupGroup.TEXT_LEFT_OFFSET_PIX).toString()+'+'+TEXT_TOP_OFFSET_PIX.toString();
			command.add('-annotate'); command.add(strOff); command.add(printGroup.annotateText(file));
			//command.add('-gravity'); command.add('Center');
		}

	}
}