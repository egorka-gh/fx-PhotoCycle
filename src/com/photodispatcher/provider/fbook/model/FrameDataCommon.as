package com.photodispatcher.provider.fbook.model{
	import com.akmeful.flex.transformer.TransformData;
	import com.akmeful.fotakrama.library.data.frame.IFrameInfo;
	
	import flash.geom.Matrix;

	public class FrameDataCommon{
		
		public var id:String='0';
		public var size:IFrameInfo;
		public var width:int;
		public var height:int;
		public var matrix:Matrix;
		public var imageMatrix:Matrix;
		public var imageWidth:int;
		public var imageHeight:int;
		public var imageId:String;
		
		public var rawObj:*;
		
		protected var _fromRight:Boolean;
		public function get fromRight():Boolean{
			return _fromRight;
		}
		public function set fromRight(value:Boolean):void{
			_fromRight = value;
		}
		
		public function FrameDataCommon(contentElement:*)
		{
			fillFromContentObject(contentElement);
		}
		
		public function fillFromContentObject(contentElement:*):void{
			rawObj=contentElement;
			if(!contentElement){
				return;
			}
			//matrix=GeomUtil.matrixFromString(contentElement.transform);
			matrix = TransformData.fromString(contentElement.transform).matrix;
			if(contentElement.iId){
				imageId=contentElement.iId;
				imageWidth=contentElement.iW;
				imageHeight=contentElement.iH;
				if (contentElement.imageTransform){
					imageMatrix = TransformData.fromString(contentElement.imageTransform).matrix;
				}
			}
			id=contentElement.id;
			width=int(contentElement.w);
			height=int(contentElement.h);
			fromRight=Boolean(contentElement.r);
			
		}
		
		public function get valid():Boolean{
			//TODO dummy check
			return true;
		}
		
	}
}