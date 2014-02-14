package com.photodispatcher.util{
	import com.google.zxing.oned.Code128Writer;
	import com.photodispatcher.shell.IMCommand;
	
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.geom.Matrix;
	import flash.utils.ByteArray;
	
	import mx.graphics.codec.PNGEncoder;

	public class IMCommandUtil{
		private static const SHADOWED_TEXT_FORE_COLOR:String='#eeeeee';
		private static const CODE128_QUIET_ZONE:int=60;
		
		public static function annotateImage(command:IMCommand,font_size:int,undercolor:String, text:String, offset:String, double:Boolean=false):void{
			if(!command || !text) return;
			if(!undercolor) undercolor='white';
			if(!offset) offset='+0+0';
			if(font_size){
				//calc points 4 density 300
				var points:int=font_size*300/72;
				//( -pointsize 33 -undercolor "white" label:" 123456-1 1/10 " -trim +repage -bordercolor white -border 10x3 -repage "+23+23" ) -flatten
				//( -pointsize 33 -undercolor "white" label:" 123456-1 1/10 " -trim +repage -bordercolor white -border 10x3 -repage "+500+0" -write mpr:label ) -flatten -gravity southwest mpr:label -geometry +500+0 -composite
				command.add('(');
				command.add('-strokewidth'); command.add('0');
				command.add('-pointsize'); command.add(points.toString());
				command.add('-undercolor'); command.add(undercolor);
				var label:String='label:'+text;
				command.add(label);
				command.add('-trim');
				command.add('+repage');
				command.add('-bordercolor'); command.add(undercolor);
				command.add('-border'); command.add('10x3');
				command.add('-repage'); command.add(offset);
				if(double) command.add('-write'); command.add('mpr:label');
				command.add(')');
				command.add('-flatten');
				if(double){
					command.add('-gravity'); command.add('southwest');
					command.add('mpr:label');
					command.add('-geometry'); command.add(offset);
					command.add('-composite');
				}
			}
		}

		public static function drawNotching(command:IMCommand,notching:int,length:int,width:int,buttPix:int=0):void{
			var line:String;
			if(notching>0){
				if(buttPix){
					//-stroke white -strokewidth 9 -draw "line 1000,0 1000,50 line 1500,0 1500,50" -stroke black -strokewidth 3 -draw "line 1000,0 1000,50 line 1500,0 1500,50"
					var xl:int=(length-buttPix)/2;
					var xr:int=xl+buttPix;
					line='line '+xl.toString()+',0 '+xl.toString()+','+notching.toString()+' line '+xr.toString()+',0 '+xr.toString()+','+notching.toString()+
						' line '+xl.toString()+','+(width-notching).toString()+' '+xl.toString()+','+width.toString()+' line '+xr.toString()+','+(width-notching).toString()+' '+xr.toString()+','+width.toString();
					command.add('-stroke'); command.add('white');
					command.add('-strokewidth'); command.add('9');
					command.add('-draw'); command.add(line);
					command.add('-stroke'); command.add('black');
					command.add('-strokewidth'); command.add('3');
					command.add('-draw'); command.add(line);
				}else{
					//-stroke white -strokewidth 9 -draw "line 1000,0 1000,50" -stroke black -strokewidth 3 -draw "line 1000,0 1000,50"
					var x:int=(length)/2;
					line='line '+x.toString()+',0 '+x.toString()+','+notching.toString()+
						' line '+x.toString()+','+(width-notching).toString()+' '+x.toString()+','+width.toString();
					command.add('-stroke'); command.add('white');
					command.add('-strokewidth'); command.add('9');
					command.add('-draw'); command.add(line);
					command.add('-stroke'); command.add('black');
					command.add('-strokewidth'); command.add('3');
					command.add('-draw'); command.add(line);
				}
			}
		}

		public static function drawBarcodeTTF(command:IMCommand,font_size:int, text:String, offset:String, gravity:String='southwest'):void{
			if(!command || !text) return;
			var undercolor:String='white';
			if(!offset) offset='+0+0';
			if(font_size){
				//calc points 4 density 300
				var points:int=font_size*300/72;
				//convert img.jpg ( -font Code-128 -pointsize 33 -undercolor "white" label:"O,BXI-1 1/10EO" -trim +repage -bordercolor white -border 10x3 -write mpr:label +delete ) -gravity southeast mpr:label -geometry +500+100 -composite labeled.jpg
				command.add('(');
				command.add('-font'); command.add('Code-128');
				command.add('-pointsize'); command.add(points.toString());
				command.add('-undercolor'); command.add(undercolor);
				var label:String='label:'+Code128.codeIt(text);
				command.add(label);
				command.add('-trim');
				command.add('+repage');
				command.add('-bordercolor'); command.add(undercolor);
				command.add('-border'); command.add('10x3');
				command.add('-write'); command.add('mpr:label');
				command.add('+delete');
				command.add(')');
				command.add('-gravity'); command.add(gravity);
				command.add('mpr:label');
				command.add('-geometry'); command.add(offset);
				command.add('-composite');
			}
		}
		
		public static function annotateTransparent(command:IMCommand, height:int, text:String, offset:String, rotate:int=0, gravity:String='southeast'):void{
			if(!command || !text || height<=0) return;
			if(!offset) offset='+0+0';
			
			//convert img.jpg ( -pointsize 30 -undercolor none -background transparent label:R12345-7 ( +clone +negate ) -geometry "+1+1" -composite -trim +repage -rotate -90 ) -gravity east -geometry "+0+0" -composite labeled.jpg
			command.add('(');
			command.add('-background'); command.add('none');
			command.add('-undercolor'); command.add('none');
			command.add('-stroke'); command.add('none');
			command.add('-strokewidth'); command.add('0');
			command.add('-fill'); command.add('black');
			command.add('-pointsize'); command.add(height.toString());
			var label:String='label:'+text;
			command.add(label);
			/*
			command.add('(');
			command.add('+clone');
			command.add('+negate');
			command.add(')');
			command.add('-gravity'); command.add('center');
			command.add('-geometry'); command.add('+2+2');
			command.add('-composite');
			*/
			//-gravity center -fill "#eeeeee" -annotate "+1+1" "R12345:7" 
			command.add('-gravity'); command.add('center');
			command.add('-fill'); command.add(SHADOWED_TEXT_FORE_COLOR);
			command.add('-annotate'); command.add('+2-2'); command.add(text);
			command.add('-trim');
			command.add('+repage');
			if(rotate!=0){
				command.add('-rotate'); command.add(rotate.toString());
			}
			command.add(')');
			command.add('-gravity'); command.add(gravity);
			command.add('-geometry'); command.add(offset);
			command.add('-composite');
		}

		public static function expandImageH(command:IMCommand, amountMM:int, imageGravity:String='east'):void{
			if(amountMM>0){
				//expand to right
				var amount:int=UnitUtil.mm2Pixels300(amountMM);
				//-gravity east -background white  -splice 20x0
				command.add('-gravity'); command.add(imageGravity);
				command.add('-background'); command.add('white');
				command.add('-splice'); command.add(amount.toString()+'x0');
			}
		}
		
		public static function drawBarcode(wrkDir:String, command:IMCommand, height:int, barcode:String, text:String, 
										   offset:String, rotate:int=0, gravity:String='southwest',
										   step:Number=3, color:int=0, quietZone:int=CODE128_QUIET_ZONE):void{
			if(!command || !barcode || !wrkDir || height<=0) return;
			var undercolor:String='white';
			if(!offset) offset='+0+0';

			var file:File=new File(wrkDir);
			if(!file.exists) return;
			var fileName:String=StrUtil.toFileName('brc_'+barcode)+'.png';
			file=file.resolvePath(fileName);
			var drawStep:int= Math.ceil(step);

			//create barcode image
			if(!file.exists){
				var c128Writer:Code128Writer= new Code128Writer();
				var bmp:Bitmap=c128Writer.draw(barcode,height,drawStep,color,quietZone);
				if (!bmp) return;
				var data:BitmapData=bmp.bitmapData;
				/*
				if(drawStep>2 && step<drawStep){
					//scale
					var matrix:Matrix = new Matrix();
					matrix.scale(step/drawStep, 1);
					var w:int=Math.round(data.width*step/drawStep);
					data= new BitmapData(w, height);
					data.draw(bmp.bitmapData, matrix); 
				}
				*/
				var encoder:PNGEncoder= new PNGEncoder();
				var imgByteArr:ByteArray = encoder.encode(data);
				
				var fs:FileStream = new FileStream();
				try{
					fs.open(file, FileMode.WRITE);
					fs.writeBytes(imgByteArr);
					fs.close();
				}catch(e:Error){
					return;
				}
			}
			
			//fill command
			//convert img.jpg ( barcode.png ( -pointsize 30 -undercolor "white" label:"R12345-7" -trim +repage -bordercolor white -border 2x2 ) -gravity center +append -write mpr:label +delete ) -gravity SouthWest mpr:label -geometry +500+50 -composite labeled.jpg
			//convert "img.jpg" "(" "barcode.png" "(" "-pointsize" "30" "-undercolor" "white" "label:R12345-7" "-trim" "+repage" "-bordercolor" "white" "-border" "2x2" ")" "-gravity" "center" "+append" "-rotate" "-90" "-write" "mpr:label" "+delete" ")" "-gravity" "east" "mpr:label" "-geometry" "+100+100" "-composite" "labeled.jpg"
			//convert "img.jpg" ( -pointsize 30 -undercolor white label:R12345-7 -trim +repage -bordercolor white -border "2x2" barcode.png +swap -gravity "center" "+append" "-rotate" "-90" "-write" "mpr:label" "+delete" ")" "-gravity" "east" mpr:label -geometry "+100+100" -composite labeled.jpg
			//convert img.jpg ( barcode.png -gravity South -background none -splice 0x30 -pointsize 28 -fill black -annotate "0" "R12345:7" -fill white -annotate "+1+1" "R12345:7" -rotate -90 ) -gravity east mpr:label -geometry "+100+100" -composite labeled.jpg
			//convert img.jpg ( barcode.png -rotate -90 ) -gravity east -geometry "+100+100" -composite labeled.jpg
			command.add('(');
			command.add(fileName);
			if(drawStep>2 && step<drawStep){
				//scale by width
				//-resize 25%x100%
				var geometry:String=Math.ceil(step*100/drawStep).toString()+'%x100%';
				command.add('-resize'); command.add(geometry);
			}
			if(text && height>8){
				command.add('-gravity'); command.add('south');
				command.add('-background'); command.add('none');
				command.add('-splice'); command.add('0x'+height.toString());
				command.add('-undercolor'); command.add('none');
				command.add('-stroke'); command.add('none');
				command.add('-strokewidth'); command.add('0');
				command.add('-pointsize'); command.add((height-2).toString());
				command.add('-fill'); command.add('black');
				command.add('-annotate'); command.add('0'); command.add(text);
				command.add('-fill'); command.add(SHADOWED_TEXT_FORE_COLOR);
				command.add('-annotate'); command.add('+2+2'); command.add(text);
			}
			if(rotate!=0){
				command.add('-rotate'); command.add(rotate.toString());
			}
			command.add(')');
			command.add('-gravity'); command.add(gravity);
			command.add('-geometry'); command.add(offset);
			command.add('-composite');
		}
	}
}