package com.photodispatcher.provider.fbook.makeup{
	import com.akmeful.flex.transformer.TransformData;
	import com.akmeful.fotakrama.canvas.content.CanvasBackgroundImage;
	import com.akmeful.fotakrama.canvas.content.CanvasFillImage;
	import com.akmeful.fotakrama.canvas.content.CanvasFrameImage;
	import com.akmeful.fotakrama.canvas.content.CanvasFrameMaskedImage;
	import com.akmeful.fotakrama.canvas.content.CanvasImage;
	import com.akmeful.fotakrama.canvas.content.CanvasPhotoBackgroundImage;
	import com.akmeful.fotakrama.canvas.content.CanvasText;
	import com.akmeful.fotakrama.canvas.text.CanvasTextStyle;
	import com.akmeful.fotakrama.data.ProjectBookPage;
	import com.akmeful.fotakrama.library.data.frame.FrameInfo;
	import com.akmeful.fotakrama.library.data.frame.FrameMaskInfo;
	import com.akmeful.fotokniga.book.contentClasses.BookCoverFrameImage;
	import com.akmeful.fotokniga.book.contentClasses.BookCoverPrintImage;
	import com.akmeful.util.GeomUtil;
	import com.photodispatcher.provider.fbook.FBookProject;
	import com.photodispatcher.provider.fbook.data.FrameData;
	import com.photodispatcher.provider.fbook.data.FrameDataCommon;
	import com.photodispatcher.provider.fbook.data.FrameMaskedData;
	import com.photodispatcher.provider.fbook.data.PageData;
	import com.photodispatcher.provider.fbook.download.DownloadErrorItem;
	import com.photodispatcher.shell.IMCommand;
	
	import flash.filesystem.File;
	import flash.geom.Matrix;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.utils.getQualifiedClassName;
	
	
	public class IMScript{
		public static const GM_XML_HEAD:String='<?xml version="1.0" encoding="UTF-8"?>\n';
		public static const PAGE_PREVIEW_BOUND:int=250;
		public static const IMAGE_DEPTH:String='8';

		private var _book:FBookProject;
		//private var wrkFolder:String;
		private var outFolder:String
		//used as image Id in script
		private var elementNumber:int=0;
		private var _pages:Array=[];//PageData
		
		public function IMScript(book:FBookProject, outFolder:String){ 
			_book=book;
			this.outFolder=outFolder;
			_pages=[];
		}

		public function build():Boolean{
			_pages=[];
			if(!_book || !_book.pages){
				return false;
			}
			
			var pageNum:int=0;
			var page:ProjectBookPage;
			for (pageNum = 0; pageNum < _book.pages.length; pageNum++){
				page=_book.pages[pageNum];
				trace('Page '+pageNum);
				if (_book.isPageEndPaper(pageNum)){
					//skip endpaper
					trace('Page skipped. Endpaper... ');
				}else{
					var pageData:PageData=new PageData(_book, pageNum, outFolder);
					//process page
					elementNumber=0;
					solidColorBackground(pageData,'white');
					for each (var contentElement:* in page.content){
						elementNumber++;
						var xml:XML;
						//process page element
						switch(contentElement.type){
							case BookCoverFrameImage.TYPE:
								//cover frame (sliced cover)
								//process as BookFrameImage 
							case CanvasFrameImage.TYPE: 
								//frame
								//TODO don't cast to BookFrameImage till it has importRaw specific & incomplite
								var fd:FrameData= new FrameData(contentElement);
								drawFrame(pageData,fd);
								break;
							case CanvasFrameMaskedImage.TYPE:
								var fmd:FrameMaskedData = new FrameMaskedData(contentElement);
								drawFrameMasked(pageData, fmd);
								break;
							case BookCoverPrintImage.TYPE:
								//page slice element
								var cpi:BookCoverPrintImage= new BookCoverPrintImage();
								cpi.importRaw(contentElement);
								createSlice(pageData,cpi);
								break;
							case CanvasImage.TYPE: // BookImage.TYPE:
								//clipart image
								var ci:CanvasImage=new CanvasImage();
								ci.importRaw(contentElement);
								ci.fromRight=Boolean(contentElement.r);
								if (!isNotLoaded(ci.imageId,pageData)) drawClipartImage(pageData,ci);
								break;
							case CanvasBackgroundImage.TYPE: 
								//background image, replace current bg
								var bi:CanvasBackgroundImage=new CanvasBackgroundImage();
								bi.importRaw(contentElement);
								if (!isNotLoaded(bi.imageId,pageData)) drawBackgroundImage(pageData,bi,artSubDir);
								break;
							case CanvasPhotoBackgroundImage.TYPE: 
								//user photo as background image, replace current bg
								var bp:CanvasPhotoBackgroundImage=new CanvasPhotoBackgroundImage();
								bp.importRaw(contentElement);
								if (!isNotLoaded(bp.imageId,pageData)) drawBackgroundImage(pageData,bp,userSubDir);
								break;
							case CanvasFillImage.TYPE: 
								//background fill image, replace current bg
								var bf:CanvasFillImage=new CanvasFillImage();
								bf.importRaw(contentElement);
								if (!isNotLoaded(bf.imageId,pageData)) tileBackground(pageData, bf.imageId);
								break;
							case CanvasText.TYPE:
								drawText(pageData,contentElement);
								break;
							default:
								//TODO unsupported IBookContentElement type
								//return false;
								trace('IMScript.build unsupported element type:'+contentElement.type);
						}
					}
					//complite page
					pageData.postprocess();
					pages.push(pageData);
				}
			}
			return true;
		}

		private function loadImageXML(id:String, filename:String):XML{
			var result:XML=<image id="imageId" background="none">
								<read filename="xc:white"/>
							</image>;
			//set id
			result.@id=id;
			//set file name
			result.read.@filename=filename;
			return result;
		}
		
		private function createImageXML(id:String, width:int, height:int, backColor:String=''):XML{
			var result:XML=<image id="imageId" size="50x50" background="none">
								<read filename="xc:none"/>
							</image>;
			//set id
			result.@id=id;
			//set colr background color
			if(backColor){
				result.@background=backColor;
				result.read.@filename='xc:'+backColor;
			}
			//set size
			result.@size=width+'x'+height;
			return result;
		}

		private function resizeXML(width:int,height:int):XML{
			//TODO resample filter
			var result:XML=<resize geometry="100x100+0+0!"/>;
			var str:String=width+'x'+height+'!';//%!: % -percent,!- do not maintain the aspect ratio
			result.@geometry=str; 
			return result;
		}
		
		private function compositeXML(imageId:String,x:int,y:int,offset:Point=null):XML{
			var result:XML=<composite image="image_01" geometry="+50+50"/>;
			var _x:int=x;
			var _y:int=y;
			if(offset){
				_x+=offset.x;
				_y+=offset.y;
			}
			result.@image=imageId;
			var str:String=((_x>=0)?'+':'')+_x+((_y>=0)?'+':'')+_y;
			result.@geometry=str;
			return result;
		}
		
		private function saveImageXML(filePath:String):XML{
			var result:XML=<write filename="filePath"/>;
			result.@filename='PNG32:'+filePath;
			return result;
		}
		
		private function dummyXML(message:String):XML{
			var result:XML=<print output="message"/>;
			result.@output=message;
			return result;
		}
		
		public function get pages():Array{
			return _pages;
		}
		
		private function tileBackground(pd:PageData, tile:String):void{
			if (!tile){return;}
			var gc:IMCommand=new IMCommand();
			gc.add('-size'); gc.add(pd.pageSize.x+'x'+pd.pageSize.y);
			gc.add('tile:'+artSubDir+tile);
			pd.backgroundCommand=gc;
		}
		
		private function solidColorBackground(pd:PageData, color:String):void{
			pd.backgroundCommand=cmdSolidColorImage(pd.pageSize,color);
		}
		
		private function cmdSolidColorImage(size:Point, color:String='transparent'):IMCommand{
			var gc:IMCommand=new IMCommand();
			gc.add('-size'); gc.add(size.x+'x'+size.y);
			gc.add('xc:'+color);
			return gc;
		}
		
		private function drawBackgroundImage(pd:PageData,element:CanvasBackgroundImage, subDir:String):void{
			var result:IMCommand;
			var m:Matrix;
			if(!element.imageId){return;}
			var fileName:String=subDir+element.imageId;
			//use matrix
			m=element.transformData.matrix;
			//add offset relative canvas 0,0 or reset tx ty
			result=cmdDrawImage(fileName,m,pd.getPageOffset());

			pd.finalMontageCommand.append(result);	
		}
		
		private function cmdApplyMaskImage(file:String, maskFile:String):IMCommand {
			var result:IMCommand=new IMCommand(IMCommand.IM_CMD_CONVERT);
			// convert image.png alpha.png -alpha off -compose copy_opacity -composite result.png
			// convert b10394_p0_3_ui.png ( mask.png -negate ) -alpha off -compose copy_opacity -composite b10394_p0_3_fu.png
			// convert ( mask.png -negate -write mpr:mask +delete )  b10394_p0_3_ui.png mpr:mask -alpha off -compose copy_opacity -composite b10394_p0_3_fu.png
			result.add(file);
			result.add(maskFile);
			result.add('-alpha');
			result.add('off');
			result.add('-compose');
			result.add('copy_opacity');
			result.add('-composite');
			return result;
		}
		
		private function cmdDrawImage(file:String, matrix:Matrix=null, offset:Point=null):IMCommand{
			var result:IMCommand=new IMCommand();
			var m:Matrix;
			if(matrix==null){
				m=new Matrix();
			}else{
				m=matrix.clone();
			}
			if(offset!=null){
				m.tx+=offset.x;
				m.ty+=offset.y;
			}
			m = toGMMatrix(m);
			//check if zero transform matrix			
			if(m.a!=1 || m.b!=0 || m.c!=0 || m.d!=1){
				//transform
				//-draw " affine 0.984025,-0.178029,0.178029,0.984025,1278,1650 image over 0,0 0,0 'b2_p3_5_fu.png' "
				result.add('-draw');
				result.add(paramMatrix(m)+' image over 0,0 0,0 \''+file+'\'');
			}else{
				//simple offset
				result.add('-draw');
				result.add('image Over '+m.tx.toString()+','+m.ty.toString()+' 0,0 \''+file+'\'');
			}
			return result;
		}
		
		private function paramMatrix(matrix:Matrix):String{
			var param:String;
			param='affine '+matrix.a.toFixed(6)+','+matrix.b.toFixed(6)+','+matrix.c.toFixed(6)+','+matrix.d.toFixed(6)+','+Math.round(matrix.tx).toString()+','+Math.round(matrix.ty).toString();
			return param;			
		}

		private function toGMMatrix(m:Matrix):Matrix{
			var result:Matrix= new Matrix();
			result.a=Math.round(m.a*1000000)/1000000;
			result.b=Math.round(m.b*1000000)/1000000;
			result.c=Math.round(m.c*1000000)/1000000;
			result.d=Math.round(m.d*1000000)/1000000;
			result.tx=Math.round(m.tx);
			result.ty=Math.round(m.ty);
			return result;
		}
		
		private function drawClipartImage(pd:PageData,element:CanvasImage):void{
			//script ID
			var fileName:String=artSubDir+element.imageId;
			var m:Matrix=element.transformData.matrix.clone();
			pd.finalMontageCommand.append(cmdDrawImage(fileName,m,pd.getPageOffset(element.fromRight)));
		}

		private function createSlice(pd:PageData,element:BookCoverPrintImage):void{
			var m:Matrix=element.transformData.matrix;
			var offset:Point=pd.getPageOffset();
			var rect:Rectangle= new Rectangle(element.x+offset.x,element.y+offset.y,element.width,element.height);
			pd.addSlice(rect);
		}

		private function drawText(pd:PageData,contentElement:Object):void{
			//script ID

			if (!contentElement.hasOwnProperty('index') || 
				!contentElement.transform || 
				!contentElement.text || 
				contentElement.w<=0 || !contentElement.h){
				return;
			}

			//check text is not default, user made some changes
			if (contentElement.hasOwnProperty('print') && contentElement.print==0){
				//txt is not calendar date?
				if(!contentElement.hasOwnProperty('aid')) return;
			}
			var fromRight:Boolean=Boolean(contentElement.r);
			//TODO hardcoded t_[pageNum]_[index].png
			var fileName:String='t_'+pd.pageNum.toString()+'_'+contentElement.index+'.png' 
			var m:Matrix = TransformData.fromString(contentElement.transform).matrix;
			
			var bts:CanvasTextStyle=CanvasTextStyle.defaultTextStyle();
			if(contentElement.style){
				bts = new CanvasTextStyle(contentElement.style);
			}
			//4 Й & italic added top/left offset =bts.fontSize
			//remove it
			if (GeomUtil.getRotationRadians(m) && bts.fontSize){
				//if txt rotate, restore offset after rotate
				var extOffset:Point=new Point(bts.fontSize,bts.fontSize);
				var me:Matrix=m.clone();
				me.tx=0; me.ty=0;
				extOffset=me.transformPoint(extOffset);
				m.tx-=extOffset.x;
				m.ty-=extOffset.y;
			}else{
				//restore offset
				m.tx-=bts.fontSize;
				m.ty-=bts.fontSize;
			}
			//m.ty-=bts.fontSize;
			
			pd.finalMontageCommand.append(cmdDrawImage(fileName,m,pd.getPageOffset(fromRight)));
		}

		private function drawFrame(pd:PageData,fd:FrameData):void{
			
			var fdInfo:FrameInfo = fd.size as FrameInfo;
			
			var hasPhoto:Boolean=(fd.imageId)?true:false;
			if(hasPhoto) hasPhoto = !isNotLoaded(fd.imageId,pd); 
			var hasFrame:Boolean=(fd.id)?true:false;
			if(hasFrame) hasFrame = !isNotLoaded(fd.id,pd); 
			var filePrefix:String=pd.pageName+'_'+elementNumber.toString();//+'_ui.png'; '_fr.png';

			if(!hasPhoto && !hasFrame){
				return;
			}
			if(hasPhoto){
				//resize & crop photo
				drawUserImage(pd,fd);
			}
			
			if(hasFrame){
				//build frame
				drawFrameImage(pd, fd);
			}
			
			//add to page
			//calc farme size
			var frameSize:Point=new Point(fd.width,fd.height);
			var photoSize:Point=new Point(fd.width,fd.height);
			var frameExtent:Point= new Point();
			if (hasFrame){
				//has frame
				frameExtent=new Point(fdInfo.padding.x,fdInfo.padding.y);
			}
			var fm:Matrix=toGMMatrix(fd.matrix);
			var scX:Number=GeomUtil.getScaleX(fd.matrix);
			var scY:Number=GeomUtil.getScaleY(fd.matrix);
			
			//frame size after scaling
			frameSize.x=Math.round((frameSize.x+2*frameExtent.x)*scX);
			frameSize.y=Math.round((frameSize.y+2*frameExtent.y)*scY);
			//photo size after scaling
			photoSize.x=Math.round(photoSize.x*scX);
			photoSize.y=Math.round(photoSize.y*scY);
			
			//compoze frame vs (or) photo
			var ofs:Point=new Point();
			var fileOut:String=filePrefix+'_fu.png';
			var gc:IMCommand=new IMCommand(IMCommand.IM_CMD_CONVERT);
			if(hasPhoto && hasFrame){
				//draw frame vs photo
				//gc.add('-depth'); gc.add(IMAGE_DEPTH);
				gc.append(cmdSolidColorImage(frameSize));
				//photo
				ofs.x=Math.round((frameSize.x-photoSize.x)/2);
				ofs.y=Math.round((frameSize.y-photoSize.y)/2);
				gc.add('-draw');
				gc.add('image Over '+ofs.x.toString()+','+ofs.y.toString()+' 0,0 \''+filePrefix+'_ui.png'+'\'');
				//frame
				ofs.x=0;
				ofs.y=ofs.x;
				gc.add('-draw');
				//resize frame!!!
				gc.add('image Over '+ofs.x.toString()+','+ofs.y.toString()+' '+(frameSize.x-2*ofs.x).toString()+','+(frameSize.y-2*ofs.y).toString()+' \''+filePrefix+'_fr.png'+'\'');
				//gc.append(cmdSolidColorImage(frameSize));
				gc.add(fileOut);
				gc.setProfile('Рамка +фото+рамка, страница #'+ pd.pageNum,fileOut);
				pd.commands.push(gc);
			}else if(hasPhoto){
				//draw photo
				if (photoSize.x==frameSize.x && photoSize.y==frameSize.y){
					fileOut=filePrefix+'_ui.png';
				}else{
					//gc.add('-depth'); gc.add(IMAGE_DEPTH);
					ofs.x=Math.round((frameSize.x-photoSize.x)/2);
					ofs.y=Math.round((frameSize.y-photoSize.y)/2);
					gc.append(cmdSolidColorImage(frameSize));
					gc.add('-draw');
					gc.add('image Over '+ofs.x.toString()+','+ofs.y.toString()+' 0,0 \''+filePrefix+'_ui.png'+'\'');
					//gc.append(cmdSolidColorImage(frameSize));
					gc.add(fileOut);
					gc.setProfile('Рамка +фото-рамка, страница #'+ pd.pageNum,fileOut);
					pd.commands.push(gc);
				}
			}else{
				//draw empty frame
				fileOut=filePrefix+'_fr.png';
			}

			//draw on page, frame already sized, apply rotate and offset 
			//offset after transform
			var extOffset:Point=new Point();
			if(frameExtent.x!=0 || frameExtent.y!=0){
				//calc extent offset (offset original 0,0 after rotate/scale around new origin (frameExtent))
				extOffset= frameExtent.clone();
				var m:Matrix=fd.matrix.clone();
				m.tx=0; m.ty=0;
				extOffset=m.transformPoint(extOffset);
			}
			var rotateMatrix:Matrix=new Matrix();
			rotateMatrix.rotate(GeomUtil.getRotationRadians(fm));
			rotateMatrix.tx=fm.tx-extOffset.x;
			rotateMatrix.ty=fm.ty-extOffset.y;
			pd.finalMontageCommand.append(cmdDrawImage(fileOut,rotateMatrix,pd.getPageOffset(fd.fromRight)));
		}
		
		private function drawFrameMasked(pd:PageData,fmd:FrameMaskedData):void{
			var hasPhoto:Boolean=(fmd.imageId)?true:false;
			if(hasPhoto) hasPhoto = !isNotLoaded(fmd.imageId,pd);
			var hasMask:Boolean=(fmd.id)?true:false;
			var info:FrameMaskInfo = fmd.size as FrameMaskInfo;
			
			if(hasMask) hasMask = !isNotLoaded(info.imgName,pd);
			
			if(!hasPhoto && !hasMask){
				return;
			}
			
			var filePrefix:String = pd.pageName+'_'+elementNumber.toString();
			var maskFile:String;
			
			var frameSize:Point=new Point(fmd.width,fmd.height);
			frameSize.x=Math.round(frameSize.x*GeomUtil.getScaleX(fmd.matrix));
			frameSize.y=Math.round(frameSize.y*GeomUtil.getScaleY(fmd.matrix));
			
			var gc:IMCommand;
			
			if(hasMask){
				maskFile = filePrefix + '_mask.jpg';
				var maskMatrix:Matrix = fmd.maskMatrix.clone();
				maskMatrix.scale(GeomUtil.getScaleX(fmd.matrix),GeomUtil.getScaleY(fmd.matrix));
				// сначала формируем маску
				var fileName:String = artSubDir + info.imgName;
				gc = new IMCommand(IMCommand.IM_CMD_CONVERT);
				gc.append(cmdSolidColorImage(frameSize, 'black'));
				gc.append(cmdDrawImage(fileName, maskMatrix, null));
				gc.add(maskFile);
				gc.setProfile('Подготовка маски, страница #'+ pd.pageNum,maskFile);
				pd.commands.push(gc);
			}
			
			if(hasPhoto) drawUserImage(pd, fmd, maskFile);
			
			var fm:Matrix = toGMMatrix(fmd.matrix);
			var fileOut:String = filePrefix+'_ui.png';
			var rotateMatrix:Matrix=new Matrix();
			rotateMatrix.rotate(GeomUtil.getRotationRadians(fm));
			rotateMatrix.tx=fm.tx;
			rotateMatrix.ty=fm.ty;
			pd.finalMontageCommand.append(cmdDrawImage(fileOut,rotateMatrix,pd.getPageOffset(fmd.fromRight)));
		}
		
		private function drawUserImage(pd:PageData,fd:FrameDataCommon, maskFile:String = null):void{
			var tmpFile:String=pd.pageName+'_'+elementNumber.toString()+'_ui.png';
			if(!fd.imageId){
				return;
			}
			//image matrix 4 crop (without frame rotate and frame offsets) 
			var iMatrix:Matrix=fd.imageMatrix.clone();
			iMatrix.scale(GeomUtil.getScaleX(fd.matrix),GeomUtil.getScaleY(fd.matrix));

			var frameSize:Point=new Point(fd.width,fd.height);
			//frame size after scaling
			frameSize.x=Math.round(frameSize.x*GeomUtil.getScaleX(fd.matrix));
			frameSize.y=Math.round(frameSize.y*GeomUtil.getScaleY(fd.matrix));
			
			//generate sized photo
			var fileName:String=userSubDir+fd.imageId;
			var gc:IMCommand=new IMCommand(IMCommand.IM_CMD_CONVERT);
			//gc.add('-depth'); gc.add(IMAGE_DEPTH);
			gc.append(cmdSolidColorImage(frameSize));
			gc.append(cmdDrawImage(fileName, iMatrix, null));
			//gc.append(cmdSolidColorImage(frameSize));
			//save
			gc.add(tmpFile);
			gc.setProfile('Подготовка фото, страница #'+ pd.pageNum,tmpFile);
			pd.commands.push(gc);
			
			if(maskFile){
				gc = cmdApplyMaskImage(tmpFile, maskFile);
				gc.add(tmpFile);
				gc.setProfile('Маскирование фото, страница #'+ pd.pageNum,tmpFile);
				pd.commands.push(gc);
			}
		}

		private function drawFrameImage(pd:PageData, fd:FrameData):void{
			
			var fdInfo:FrameInfo = fd.size as FrameInfo;
			
			function getElementsNum(lenth:int,elementLenth:int):int{
				var k:int=0;
				if (lenth>0 && lenth>elementLenth){
					k=Math.round(lenth/elementLenth);
				}else if (lenth>0){
					k=1;
				}	
				return k;
			}
			
			function createBorder(id:String,type:String,lenth:int):void{
				var hBorder:Boolean;
				var size:Point;
				if(lenth>0){
					switch(type){
						case FrameData.BORDER_T:
							size=fdInfo.tS;
							hBorder=true;
							break;
						case FrameData.BORDER_B:
							size=fdInfo.bS;
							hBorder=true;
							break;
						case FrameData.BORDER_L:
							size=fdInfo.lS;
							hBorder=false;
							break;
						case FrameData.BORDER_R:
							size=fdInfo.rS;
							hBorder=false;
							break;
						default:
							return;
					}
					//read element
					var x:XML=loadImageXML(id+'_'+type,fd.getFileName(type));
					group.appendChild(x);
					//build
					var elNum:int;
					var lenthCalc:int;
					var i:int;
					if (hBorder){
						elNum=getElementsNum(lenth,size.x);
						lenthCalc=elNum*size.x;
						//create border
						x=createImageXML(id,lenthCalc,size.y);
						/*texture - bad case
						//add element as texture
						x.appendChild(textureXML(id+'_'+type));
						*/
						//fill vs elements
						for (i=0;i<elNum;i++){
							x.appendChild(compositeXML(id+'_'+type,i*size.x,0));		
						}
						//resize
						if(lenth!=lenthCalc){
							x.appendChild(resizeXML(lenth,size.y));
						}
					}else{
						elNum=getElementsNum(lenth,size.y);
						lenthCalc=elNum*size.y;
						x=createImageXML(id,size.x,lenthCalc);
						//fill vs elements
						for (i=0;i<elNum;i++){
							x.appendChild(compositeXML(id+'_'+type,0,i*size.y));		
						}
						//resize
						if(lenth!=lenthCalc){
							x.appendChild(resizeXML(size.x,lenth));
						}
					}
					group.appendChild(x);
				}
			}
			if (!fd.id){
				trace('empty frame');
				return;
			}
			//build frame script
			//TODO implement corner resize?(if frame too small to hold corners)
			//calc borders lenth
			var wT:int= fd.width-fdInfo.tlS.x-fdInfo.trS.x+2*fdInfo.padding.x;
			var wB:int= fd.width-fdInfo.blS.x-fdInfo.brS.x+2*fdInfo.padding.x;
			var hL:int= fd.height-fdInfo.tlS.y-fdInfo.blS.y+2*fdInfo.padding.y;
			var hR:int= fd.height-fdInfo.trS.y-fdInfo.brS.y+2*fdInfo.padding.y;
			//script ID
			var scriptID:String=pd.pageName+'_'+elementNumber.toString();
			//frame subgroup
			var group:XML=<group></group>;
			var frameImage:XML=createImageXML('frameImage',fd.width+2*fdInfo.padding.x,fd.height+2*fdInfo.padding.y);
			//load images
			//read corners
			var elementName:String=scriptID+'_'+FrameData.CORNER_TL;
			group.appendChild(loadImageXML(elementName,fd.getFileName(FrameData.CORNER_TL)));
			frameImage.appendChild(compositeXML(elementName,0,0));
			
			elementName=scriptID+'_'+FrameData.CORNER_TR;
			group.appendChild(loadImageXML(elementName,fd.getFileName(FrameData.CORNER_TR)));
			frameImage.appendChild(compositeXML(elementName,fd.width-fdInfo.trS.x+2*fdInfo.padding.x,0));
			
			elementName=scriptID+'_'+FrameData.CORNER_BL;
			group.appendChild(loadImageXML(elementName,fd.getFileName(FrameData.CORNER_BL)));
			frameImage.appendChild(compositeXML(elementName,0,fd.height-fdInfo.blS.y+2*fdInfo.padding.y));
			
			elementName=scriptID+'_'+FrameData.CORNER_BR;
			group.appendChild(loadImageXML(elementName,fd.getFileName(FrameData.CORNER_BR)));
			frameImage.appendChild(compositeXML(elementName,fd.width-fdInfo.brS.x+2*fdInfo.padding.x,fd.height-fdInfo.brS.y+2*fdInfo.padding.y));
			
			//build borders
			elementName=scriptID+'_'+FrameData.BORDER_T;
			createBorder(elementName,FrameData.BORDER_T,wT);
			frameImage.appendChild(compositeXML(elementName,fdInfo.tlS.x,fdInfo.tlS.y-fdInfo.tS.y));
			
			elementName=scriptID+'_'+FrameData.BORDER_B;
			createBorder(elementName,FrameData.BORDER_B,wB);
			frameImage.appendChild(compositeXML(elementName,fdInfo.blS.x,fd.height+2*fdInfo.padding.y-fdInfo.blS.y)); 
			
			elementName=scriptID+'_'+FrameData.BORDER_L;
			createBorder(elementName,FrameData.BORDER_L,hL);
			frameImage.appendChild(compositeXML(elementName,fdInfo.tlS.x-fdInfo.lS.x,fdInfo.tlS.y));
			
			elementName=scriptID+'_'+FrameData.BORDER_R;
			createBorder(elementName,FrameData.BORDER_R,hR);
			frameImage.appendChild(compositeXML(elementName,fd.width+2*fdInfo.padding.x-fdInfo.trS.x,fdInfo.trS.y));
			//add frameImage to group & save
			group.appendChild(frameImage);
			var imageFileName:String=scriptID+'_fr.png';
			group.appendChild(saveImageXML(imageFileName));
			pd.msls.push(group);
		}
		
		private function isNotLoaded(elementId:String, pd:PageData):Boolean{
			if (!_book.notLoadedItems || _book.notLoadedItems.length==0) return false;
			var errItm:DownloadErrorItem;
			for each(errItm in _book.notLoadedItems){
				if (!errItm) continue;
				if (errItm.id==elementId){
					//errItm.used++;
					errItm.usedOnPage(pd.pageNum);
					return true;
				}
			}
			return false;
		}

		private function get artSubDir():String{
			var dir:String=FBookProject.SUBDIR_ART+File.separator;
			return dir;
		}
		
		private function get userSubDir():String{
			var dir:String=FBookProject.SUBDIR_USER+File.separator;
			return dir;
		}

	}
	
}