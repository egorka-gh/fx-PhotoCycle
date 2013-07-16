package com.photodispatcher.model{
	public class LabPrintCode extends DBRecord{
		//database props
		[Bindable]
		public var id:int;
		[Bindable]
		public var src_type:int;
		[Bindable]
		public var src_id:int=0;
		[Bindable]
		public var prt_code:String;
		[Bindable]
		public var width:int;
		[Bindable]
		public var height:int;
		[Bindable]
		public var paper:int=0;
		[Bindable]
		public var frame:int=0;
		[Bindable]
		public var correction:int=0;
		[Bindable]
		public var cutting:int=0;
		[Bindable]
		public var is_duplex:Boolean=false;
		[Bindable]
		public var is_pdf:Boolean=false;
		
		//ref
		[Bindable]
		public var paper_name:String;
		[Bindable]
		public var frame_name:String;
		[Bindable]
		public var correction_name:String;
		[Bindable]
		public var cutting_name:String;

		public function key(srcType:int=SourceType.LAB_NORITSU,fullness:int=0):String{
			var sizeKey:String;
			switch(fullness){
				case 1:
					//no height 
					sizeKey=width.toString()+'_h'; 
					break;
				case 2:
					//no size at all 
					sizeKey='w_h'; 
					break;
				default:
					//full
					sizeKey=width.toString()+'_'+height.toString(); 
			}
			var result:String;
			switch(srcType){
				case SourceType.LAB_FUJI:
					//SourceType.LAB_FUJI - short key, exlude correction & cutting 
					result=sizeKey+'_'+paper.toString()+'_'+frame.toString(); 
					break;
				case SourceType.LAB_PLOTTER:
					//SourceType.LAB_PLOTTER - short key, exlude correction, cutting & frame 
					result=sizeKey+'_'+paper.toString(); 
					break;
				case SourceType.LAB_XEROX:
					//SourceType.LAB_XEROX - short key, include w/h/pape/duplex
					result=sizeKey+'_'+paper.toString()+'_'+is_duplex.toString(); 
					break;
				case SourceType.LAB_NORITSU_NHF:
					//include w/h
					result=sizeKey; 
					break;
				default:
					//full key (SourceType.LAB_NORITSU or any)
					result=sizeKey+'_'+paper.toString()+'_'+frame.toString()+'_'+correction.toString()+'_'+cutting.toString(); 
					break;
			}
			return result;
		}
		
	}
}