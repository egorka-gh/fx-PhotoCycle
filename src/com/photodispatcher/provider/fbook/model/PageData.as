package com.photodispatcher.provider.fbook.model{
	import com.akmeful.card.data.CardProject;
	import com.akmeful.fotakrama.data.ProjectBookPage;
	import com.akmeful.fotocalendar.data.FotocalendarProject;
	import com.akmeful.fotocup.data.FotocupProject;
	import com.akmeful.fotokniga.book.data.BookCoverPrintType;
	import com.akmeful.fotokniga.book.data.BookPage;
	import com.akmeful.fotokniga.book.layout.BookLayout;
	import com.akmeful.magnet.data.MagnetProject;
	import com.photodispatcher.provider.fbook.FBookProject;
	import com.photodispatcher.provider.fbook.makeup.IMMsl;
	import com.photodispatcher.provider.fbook.makeup.IMScript;
	import com.photodispatcher.shell.IMCommand;
	import com.photodispatcher.util.StrUtil;
	
	import flash.filesystem.File;
	import flash.geom.Point;
	import flash.geom.Rectangle;

	public class PageData{
		public static const OUT_FILE_DEPTH:String='8';
		public static const OUT_FILE_DENSITY:String='300';
		public static const OUT_FILE_QUALITY:String='99%';

		public static const SCRIPT_FILE_PREFIX:String='page';
		public static const SCRIPT_FILE_EXT:String='.msl';
		public static const OUT_FILE_PREFIX:String='000-';//dummy book num
		public static const OUT_FILE_SLICE_SUFIX:String='_sl';
		public static const OUT_FILE_EXT:String='.jpg';
		public static const WRK_FILE_PREFIX:String='page';
		public static const WRK_FILE_EXT:String='.png';
		public static const OUT_FILE_DEBUG_EXT:String='.png';
		public static const OUT_FILE_FRAME_SUFIX:String='fr';
		public static const OUT_FILE_PREVIEW_SUFIX:String='_preview';

		[Bindable]
		public var pageNum:int;
		public var sheetNum:int;

		protected var book:FBookProject;
		//public var previewFile:String;
		//public var outFileDebug:String;
		/*
		[Bindable]
		public var state:int;
		[Bindable]
		public var error:String;
		*/
		
		/*
		//script's to show
		[Bindable]
		public var script:String;
		*/

		//page build vars
		//commands
		public var commands:Array;
		//public var finalCommands:Array;
		//msl scripts
		public var msls:Array=[];
		public var finalMontageCommand:IMCommand;
		//final montage command
		public var backgroundCommand:IMCommand;
		//build sizes
		public var pageSize:Point;
		//public var outFilePath:String;
		
		private var pageOffset:Point;
		//private var wrkFolder:String;
		private var outFolder:String
		//нарезка финальной сборки на фотовставки (для BookCoverPrintType.PARTIAL), массив Rectangle
		private var slices:Array;

		public function PageData(book:FBookProject, pageNum:int, outFolder:String, sheetNum:int){
			this.book=book;
			this.pageNum=pageNum;
			this.sheetNum=sheetNum;
			adjustSizes();
			this.outFolder=outFolder;
			finalMontageCommand=new IMCommand(IMCommand.IM_CMD_CONVERT);
			commands=[];
		}

		public function get pageName():String{
			return 'p'+pageNum.toString();
		}
		
		private function adjustSizes():void{
			pageSize=new Point(0,0);
			pageOffset=new Point(0,0);
			book.adjustPageSizes(pageNum,pageSize,pageOffset);
		}
		
		public function postprocess():void{
			var gc:IMCommand;
			var i:int;
			var msl:IMMsl;
			//add msls to commands
			for (i=msls.length-1;i>=0;i--){
				msl=msls[i] as IMMsl;
				msl.fileName=scriptFileName(i);
				//add msl script
				gc = new IMCommand(IMCommand.IM_CMD_MSL); gc.add(msl.fileName);
				gc.setProfile('MSL скрипт (подготовка рамок), страница #'+pageNum, msl.fileName);
				commands.unshift(gc);
			}

			finalMontageCommand.prepend(backgroundCommand);

			var outFilePath:String=outFileName(); ////default output to wrk folder
			
			//specific processing
			if(book.type==FBookProject.PROJECT_TYPE_BCARD){
				//save tile template to wrk folder
				setOutputParams(finalMontageCommand);
				finalMontageCommand.add(outFilePath);
				finalMontageCommand.setProfile('Сборка tile #'+pageNum,outFilePath);
				commands.push(finalMontageCommand);
				//create result page
				finalMontageCommand=new IMCommand(IMCommand.IM_CMD_CONVERT);
				//tile vs template
				var bcp:CardProject=book.project as CardProject;
				finalMontageCommand.add('-size'); finalMontageCommand.add(bcp.getTemplate().getFormat().realWidth+'x'+bcp.getTemplate().getFormat().realHeight);
				finalMontageCommand.add('tile:'+outFilePath);
				//outFilePath=outFileName(); //bug if !outFolder
				pageSize= new Point(bcp.getTemplate().getFormat().realWidth,bcp.getTemplate().getFormat().realHeight);
			}else if(book.type==FotocupProject.PROJECT_TYPE){
				var fc:FotocupProject=book.project as FotocupProject;
				if (fc.template.printWidth>fc.template.format.realWidth){
					//resize to fc.template.printWidth
					//remove virtual canvas
					finalMontageCommand.add('+repage'); finalMontageCommand.add('-flatten'); 
					//crop
					var sheetCrop:String=fc.template.printWidth.toString()+'x'+fc.template.format.realHeight.toString()
						+'+'+fc.template.printShift.toString()+'+0!';
					finalMontageCommand.add('-gravity'); finalMontageCommand.add('West');
					finalMontageCommand.add('-background'); finalMontageCommand.add('white');
					finalMontageCommand.add('-crop'); finalMontageCommand.add(sheetCrop);
					finalMontageCommand.add('-flatten');
					pageSize= new Point(fc.template.printWidth,fc.template.format.realHeight);
				}
				//Reflect in the horizontal direction
				finalMontageCommand.add('-flop');
			}
			if(!(book.isPageSliced(pageNum) || book.type==MagnetProject.PROJECT_TYPE)){ //Sliced & magnet will stay in wrk
				//redirect to output folder
				if(outFolder) outFilePath=outFolder+File.separator+outFilePath;
			}
			//set depth & quality
			setOutputParams(finalMontageCommand);
			//save
			finalMontageCommand.add(outFilePath);
			finalMontageCommand.setProfile('Сборка страницы #'+pageNum,outFilePath);
			commands.push(finalMontageCommand);

			//generate sices
			if(book.isPageSliced(pageNum)){
				//slice page
				var sNum:int=0;
				var r:Rectangle;
				var sliceOutPath:String;
				if(slices){
					for each(var oo:Object in slices){
						r=oo as Rectangle;
						if(r){
							sNum++;
							gc = new IMCommand(IMCommand.IM_CMD_CONVERT); 
							gc.add(outFilePath); 
							gc.add('-crop'); gc.add(r.width.toString()+'x'+r.height.toString()+'+'+r.x.toString()+'+'+r.y.toString());
							gc.add('+repage');
							sliceOutPath=outFileName(sNum);
							if(outFolder) sliceOutPath=outFolder+File.separator+sliceOutPath;
							gc.add(sliceOutPath);
							gc.setProfile('Фотовставка #'+sNum.toString()+' страницы #'+StrUtil.lPad(pageNum.toString(),2),sliceOutPath);
							//finalCommands.push(gc);
							commands.push(gc);
						}
					}
				}
			}
		}
		
		public function getSliceSize(num:int=0):Point{
			var p:Point=new Point();
			if(!slices || slices.length==0) return p;
			var r:Rectangle=slices[num] as Rectangle;
			if(r){
				p.x=r.width;
				p.y=r.height;
			}
			return p;
		}
		
		private function setOutputParams(command:IMCommand):void{
			//set depth & quality
			if(OUT_FILE_DEPTH){
				command.add('-depth');
				command.add(OUT_FILE_DEPTH);
			}
			if(OUT_FILE_DENSITY){
				command.add('-density');
				command.add(OUT_FILE_DENSITY);
			}
			if(OUT_FILE_QUALITY){
				command.add('-quality');
				command.add(OUT_FILE_QUALITY);
			}
		}

		public function outFileName(sliceNum:int=0):String{
			/*
			var captionNum:int=pageNum;
			if (book.isPageEndPaper(1)){
				//first page in blok skipped (end paper), restore page order
				if(captionNum>0) captionNum--;
			}else if(book.type==FBookProject.PROJECT_TYPE_BCARD
				|| book.type==FotocalendarProject.PROJECT_TYPE
				|| book.type==MagnetProject.PROJECT_TYPE){
				//pages starts from 1 (0- 4 book cover only)
				captionNum++;
			}
			*/
			if(sliceNum<=0){
				//simple out file name
				return OUT_FILE_PREFIX+StrUtil.lPad(sheetNum.toString(),2)+OUT_FILE_EXT;
			}else{
				//slice
				return OUT_FILE_PREFIX+StrUtil.lPad(sheetNum.toString(),2)+OUT_FILE_SLICE_SUFIX+sliceNum.toString()+OUT_FILE_EXT;
			}
		}

		private function scriptFileName(scriptNum:int):String{
			return SCRIPT_FILE_PREFIX+pageNum+'_'+scriptNum.toString()+SCRIPT_FILE_EXT;
		}
		
		public function getPageOffset(isRightSideElement:Boolean=false):Point{
			var result:Point=pageOffset.clone();
			return result;
		}
		
		public function addSlice(rect:Rectangle):void{
			if(!slices) slices= new Array();
			if(rect) slices.push(rect);
		}

	}
}