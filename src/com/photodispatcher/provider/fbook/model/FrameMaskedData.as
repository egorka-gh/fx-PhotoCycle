package com.photodispatcher.provider.fbook.model{

	import com.akmeful.fotakrama.canvas.content.CanvasFrameImageCommon;
	import com.akmeful.fotakrama.canvas.content.CanvasFrameMaskedImage;
	import com.akmeful.fotakrama.library.data.frame.FrameMaskInfo;
	
	import flash.geom.Matrix;
	
	import mx.rpc.IResponder;
	
	public class FrameMaskedData extends FrameDataCommon implements IResponder{
		
		protected var _maskMatrix:Matrix;
		public function get maskMatrix():Matrix {
			return _maskMatrix;
		}
		
		public function FrameMaskedData(contentElement:*){
			super(contentElement);
		}
		
		override public function fillFromContentObject(contentElement:*):void{
			
			super.fillFromContentObject(contentElement);
			
			if(contentElement.hasOwnProperty('size')){
				size = new FrameMaskInfo(contentElement.size);
				_maskMatrix = CanvasFrameImageCommon.getTransformDataToFit(size.minWidth, size.minHeight, width, height, 0, CanvasFrameMaskedImage.MASK_PADDING).matrix;
			}
			
		}
		
		public function result(data:Object):void{
		}
		
		public function fault(info:Object):void{
		}
	}
}