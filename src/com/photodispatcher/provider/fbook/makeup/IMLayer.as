package com.photodispatcher.provider.fbook.makeup{
	import com.akmeful.fotakrama.canvas.content.CanvasGroupPrintMaskImage;
	import com.photodispatcher.shell.IMCommand;
	
	import flash.geom.Matrix;
	import flash.geom.Point;

	public class IMLayer{
		public static const TYPE:String = "imLayer";
		
		public var maskSize:Point;
		public var maskMatrix:Matrix;
		
		//IM commands
		public var commands:Array=[];
		//MSL scripts
		public var msls:Array=[];
		//final montage command
		public var finalMontageCommand:IMCommand;
		
		public var fileName:String;
		
		//childs
		protected var content:Array;
		private var _isRoot:Boolean;
		private var _raw:*;
		
		public function IMLayer(raw:*=null){
			content=[];
			finalMontageCommand=new IMCommand(IMCommand.IM_CMD_CONVERT);
			if(raw){
				//import from raw (not need)
				_raw=raw;
				_isRoot=false;
			}else{
				//default (root) layer
				_isRoot=true;
			}
		}
		
		public function get type():String{
			return TYPE;
		}
		
		public function get isRoot():Boolean{
			return _isRoot;
		}
		
		public function addElement(item:*):void{
			if(item.type==CanvasGroupPrintMaskImage.TYPE){
				var crop:CanvasGroupPrintMaskImage=new CanvasGroupPrintMaskImage();
				crop.importRaw(item);
				//set layer size & transform
				maskSize=new Point(crop.width,crop.height);
				maskMatrix=crop.transformData.matrix.clone();
			}else{
				content.push(item);
			}
		}
		public function joinContent(layer:IMLayer):void{
			if(layer && layer.content && !(this===layer)) this.content=this.content.concat(layer.content);
		}
		public function get elements():Array{
			return content;
		}
		
		public function get isOrdinary():Boolean{
			var result:Boolean= maskSize==null; 
			return result;
		}
		
		public function joinScrips(layer:IMLayer):void{
			if(layer){
				this.msls=this.msls.concat(layer.msls);
				this.commands=this.commands.concat(layer.commands);
				if(layer.finalMontageCommand) this.commands.push(layer.finalMontageCommand);
			}
		}
		
	}
}