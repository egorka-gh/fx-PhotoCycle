package com.photodispatcher.provider.preprocess{
	import com.photodispatcher.model.PrintGroupFile;
	
	import flash.geom.Point;

	public class ResizeItem{
		public static const RESIZE_NON:int=0;
		public static const RESIZE_BY_LONG:int=1;
		public static const RESIZE_BY_SHORT:int=2;

		public var printGroupFile:PrintGroupFile;
		//public var size:int=0;
		//public var fitSize:int=0;
		public var size:Point=new Point();
		public var fitSize:Point=new Point();
		public var resizeType:int=RESIZE_NON;
		public var resizeSize:int=0;

		public var isNotJPG:Boolean=false;
		public var isComplete:Boolean=false;

		public var order_id:String;
		public var fileFolder:String;
		public var outFolder:String;
		public var resultFileName:String;

		public function ResizeItem(printGroupFile:PrintGroupFile){
			this.printGroupFile=printGroupFile;
		}
		
		public function mustToResize():Boolean{
			resizeType=RESIZE_NON;
			//check if frame size detected
			if(Math.min(fitSize.x,fitSize.y)<=0) return false;
			//check if image size detected
			if(Math.min(size.x,size.y)<=0) return false;
			//detect type
			if(size.y/size.x<=fitSize.y/fitSize.x){
				//by long side
				resizeSize=fitSize.y;
				if(resizeSize<size.y) resizeType=RESIZE_BY_LONG;
			}else{
				//by short side
				resizeSize=fitSize.x;
				if(resizeSize<size.x) resizeType=RESIZE_BY_SHORT;
			}
			return resizeType!=RESIZE_NON;
		}
	}
}