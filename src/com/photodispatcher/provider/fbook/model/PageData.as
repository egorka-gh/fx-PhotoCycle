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
	import com.photodispatcher.provider.fbook.makeup.IMLayer;
	import com.photodispatcher.provider.fbook.makeup.IMMsl;
	import com.photodispatcher.shell.IMCommand;
	import com.photodispatcher.util.StrUtil;
	
	import flash.filesystem.File;
	import flash.geom.Point;
	import flash.geom.Rectangle;

	public class PageData{
		public static const OUT_FILE_DEPTH:String='8';
		public static const OUT_FILE_UNIT:String='PixelsPerInch';
		public static const OUT_FILE_DENSITY:String='300x300';
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

		//page build vars
		//commands
		//public var commands:Array;
		//public var finalCommands:Array;
		//msl scripts
		//public var msls:Array=[];
		//public var finalMontageCommand:IMCommand;
		//final montage command
		public var backgroundCommand:IMCommand;
		//build sizes
		public var pageSize:Point;
		//public var outFilePath:String;
		public var rootLayer:IMLayer;

		private var pageOffset:Point;
		//private var wrkFolder:String;
		private var outFolder:String
		//нарезка финальной сборки на фотовставки (для BookCoverPrintType.PARTIAL), массив Rectangle
		private var slices:Array;

		private var layerStack:Array;

		public function PageData(book:FBookProject, pageNum:int, outFolder:String, sheetNum:int){
			this.book=book;
			this.pageNum=pageNum;
			this.sheetNum=sheetNum;
			adjustSizes();
			this.outFolder=outFolder;
			//finalMontageCommand=new IMCommand(IMCommand.IM_CMD_CONVERT);
			//commands=[];
			layerStack=[];
			//create default layer
			rootLayer= new IMLayer();
			layerStack.push(rootLayer);
		}

		public function get currentLayer():IMLayer{
			return layerStack[layerStack.length-1] as IMLayer;
		}
		public function layerAdd(layer:IMLayer):void{
			layerStack.push(layer);
		}
		public function layerPop():IMLayer{
			if(layerStack.length>1){
				return layerStack.pop() as IMLayer;
			}else{
				return layerStack[0] as IMLayer;
			}
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
			for (i=rootLayer.msls.length-1;i>=0;i--){
				msl=rootLayer.msls[i] as IMMsl;
				msl.fileName=scriptFileName(i);
				//add msl script
				gc = new IMCommand(IMCommand.IM_CMD_MSL); gc.add(msl.fileName);
				gc.setProfile('MSL скрипт (подготовка рамок), страница #'+pageNum, msl.fileName);
				rootLayer.commands.unshift(gc);
			}

			rootLayer.finalMontageCommand.prepend(backgroundCommand);

			var outFilePath:String=outFileName(); ////default output to wrk folder
			
			//specific processing
			if(book.type==FBookProject.PROJECT_TYPE_BCARD){
				//save tile template to wrk folder
				setOutputParams(rootLayer.finalMontageCommand);
				rootLayer.finalMontageCommand.add(outFilePath);
				rootLayer.finalMontageCommand.setProfile('Сборка tile #'+pageNum,outFilePath);
				rootLayer.commands.push(rootLayer.finalMontageCommand);
				//create result page
				rootLayer.finalMontageCommand=new IMCommand(IMCommand.IM_CMD_CONVERT);
				//tile vs template
				var bcp:CardProject=book.project as CardProject;
				rootLayer.finalMontageCommand.add('-size'); rootLayer.finalMontageCommand.add(bcp.getTemplate().getFormat().realWidth+'x'+bcp.getTemplate().getFormat().realHeight);
				rootLayer.finalMontageCommand.add('tile:'+outFilePath);
				//outFilePath=outFileName(); //bug if !outFolder
				pageSize= new Point(bcp.getTemplate().getFormat().realWidth,bcp.getTemplate().getFormat().realHeight);
			}else if(book.type==FotocupProject.PROJECT_TYPE){
				var fc:FotocupProject=book.project as FotocupProject;
				if (fc.template.printWidth>fc.template.format.realWidth){
					//resize to fc.template.printWidth
					//remove virtual canvas
					rootLayer.finalMontageCommand.add('+repage'); rootLayer.finalMontageCommand.add('-flatten'); 
					//crop
					var sheetCrop:String=fc.template.printWidth.toString()+'x'+fc.template.format.realHeight.toString()
						+'+'+fc.template.printShift.toString()+'+0!';
					rootLayer.finalMontageCommand.add('-gravity'); rootLayer.finalMontageCommand.add('West');
					rootLayer.finalMontageCommand.add('-background'); rootLayer.finalMontageCommand.add('white');
					rootLayer.finalMontageCommand.add('-crop'); rootLayer.finalMontageCommand.add(sheetCrop);
					rootLayer.finalMontageCommand.add('-flatten');
					pageSize= new Point(fc.template.printWidth,fc.template.format.realHeight);
				}
				//Reflect in the horizontal direction
				rootLayer.finalMontageCommand.add('-flop');
			}
			if(!(book.isPageSliced(pageNum) || book.type==MagnetProject.PROJECT_TYPE)){ //Sliced & magnet will stay in wrk
				//redirect to output folder
				if(outFolder) outFilePath=outFolder+File.separator+outFilePath;
			}
			//set depth & quality
			setOutputParams(rootLayer.finalMontageCommand);
			//save
			rootLayer.finalMontageCommand.add(outFilePath);
			rootLayer.finalMontageCommand.setProfile('Сборка страницы #'+pageNum,outFilePath);
			rootLayer.commands.push(rootLayer.finalMontageCommand);

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
							rootLayer.commands.push(gc);
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
			if(OUT_FILE_UNIT){
				command.add('-units');
				command.add(OUT_FILE_UNIT);
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