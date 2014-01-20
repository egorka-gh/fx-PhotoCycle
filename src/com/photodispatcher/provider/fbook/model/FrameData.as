package com.photodispatcher.provider.fbook.model{
	import com.akmeful.fotakrama.library.data.frame.FrameInfo;
	import com.photodispatcher.provider.fbook.FBookProject;
	
	import flash.filesystem.File;
	
	import mx.rpc.IResponder;
	
	public class FrameData extends FrameDataCommon{// implements IResponder{
		public static const CORNER_TL:String = 'tl';
		public static const CORNER_TR:String = 'tr';
		public static const CORNER_BL:String = 'bl';
		public static const CORNER_BR:String = 'br';
		public static const BORDER_T:String = 't';
		public static const BORDER_B:String = 'b';
		public static const BORDER_L:String = 'l';
		public static const BORDER_R:String = 'r';
		//TODO file ext is hardcoded to '.png'
		public static const FILE_EXT:String = '.png';
		
		public static const FRAME_ELEMENTS:Object={tl:CORNER_TL,tr:CORNER_TR,bl:CORNER_BL,br:CORNER_BR,t:BORDER_T,b:BORDER_B,l:BORDER_L,r:BORDER_R};
		
		public function FrameData(contentElement:*){
			super(contentElement);
		}
		
		override public function fillFromContentObject(contentElement:*):void{
			super.fillFromContentObject(contentElement);
			if(contentElement.hasOwnProperty('size')){
				size = new FrameInfo(contentElement.size);
			}
		}
		
		public function getFileName(element:String):String{
			//var result:String=MakeupConfig.artSubDir;
			var result:String=FBookProject.SUBDIR_ART+File.separator;
			//add escape char
			result=result.replace('\\','\\\\');
			result=result+id+'_'+element+FILE_EXT
			return result;
		}
		
		public static function getFileNameSufix(element:String):String{
			return '_'+element+FILE_EXT;
		}
		
		/*
		//TODO 4 debug (async)
		public function getSize(baseUrl:String):void{
			var ri:RemoteImageInfo;
			ri=new RemoteImageInfo(CORNER_TL,this);
			ri.getImageSize(baseUrl+id+'_'+CORNER_TL+'.png');
			ri=new RemoteImageInfo(CORNER_TR,this);
			ri.getImageSize(baseUrl+id+'_'+CORNER_TR+'.png');
			ri=new RemoteImageInfo(CORNER_BL,this);
			ri.getImageSize(baseUrl+id+'_'+CORNER_BL+'.png');
			ri=new RemoteImageInfo(CORNER_BR,this);
			ri.getImageSize(baseUrl+id+'_'+CORNER_BR+'.png');
			
			ri=new RemoteImageInfo(BORDER_T,this);
			ri.getImageSize(baseUrl+id+'_'+BORDER_T+'.png');
			ri=new RemoteImageInfo(BORDER_B,this);
			ri.getImageSize(baseUrl+id+'_'+BORDER_B+'.png');
			ri=new RemoteImageInfo(BORDER_L,this);
			ri.getImageSize(baseUrl+id+'_'+BORDER_L+'.png');
			ri=new RemoteImageInfo(BORDER_R,this);
			ri.getImageSize(baseUrl+id+'_'+BORDER_R+'.png');
		}
		
		public function fault(info:Object):void {
			trace('FrameData/getSize error: '+info.tag+' '+info.response);
		}
		
		public function result(data:Object):void{
			if(!size){
				size= new FrameInfo();
			}
			var res:TaggedPointResponce = (data as TaggedPointResponce);
			switch(res.tag){
				case CORNER_TL:
					(this.size as FrameInfo).tlS=res.response;
					break;
				case CORNER_TR:
					(this.size as FrameInfo).trS=res.response;
					break;
				case CORNER_BL:
					(this.size as FrameInfo).blS=res.response;
					break;
				case CORNER_BR:
					(this.size as FrameInfo).brS=res.response;
					break;
				case BORDER_T:
					(this.size as FrameInfo).tS=res.response;
					break;
				case BORDER_B:
					(this.size as FrameInfo).bS=res.response;
					break;
				case BORDER_L:
					(this.size as FrameInfo).lS=res.response;
					break;
				case BORDER_R:
					(this.size as FrameInfo).rS=res.response;
					break;
			}
		}
		*/
		
	}
}