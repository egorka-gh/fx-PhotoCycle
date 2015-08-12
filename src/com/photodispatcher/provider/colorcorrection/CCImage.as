package com.photodispatcher.provider.colorcorrection{
	
	[Bindable]
	public class CCImage{
		
		public function CCImage(srcPath:String, orgPath:String, subFolder:String, name:String){
			this.srcPath=srcPath;
			this.orgPath=orgPath;
			this.subFolder=subFolder;
			this.name=name;
		}

		public var srcPath:String;
		public var orgPath:String;
		public var subFolder:String;
		public var name:String;

		public var isStarted:Boolean;
		public var hasErr:Boolean;
		public var zerroCorrection:Boolean;
		public var done:Boolean;

		public var corrCyan:int=0;
		public var corrMagenta:int=0;
		public var corrYellow:int=0;
		public var corrBright:int=0;

		public function get corrFileName():String{
			return 'i('+corrBright.toString()+')('+corrCyan.toString()+')('+corrMagenta.toString()+')('+corrYellow.toString()+').jpg'
		}

		public function resetCorrection():void{
			corrCyan=0;
			corrMagenta=0;
			corrYellow=0;
			corrBright=0;
		}
		
		public function clone():CCImage{
			var ci:CCImage= new CCImage(srcPath, orgPath, subFolder, name);
			ci.hasErr=hasErr;
			ci.corrCyan=corrCyan;
			ci.corrMagenta=corrMagenta;
			ci.corrYellow=corrYellow;
			ci.corrBright=corrBright;
			return ci;
		}
		
		public function get copyResult():Boolean{
			return done && (zerroCorrection || corrCyan!=0 || corrMagenta!=0 || corrYellow!=0 || corrBright!=0)
		}
	}
}