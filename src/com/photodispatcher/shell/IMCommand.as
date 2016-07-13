package com.photodispatcher.shell{
	public class IMCommand{
		/*
		public static const IM_CMD_CONVERT:String='convert.exe';
		public static const IM_CMD_MSL:String='conjure.exe';
		public static const IM_CMD_MONTAGE:String='montage.exe';
		*/
		public static function get IM_CMD_CONVERT():String{
			if (ProcessRunner.isWindows()) return 'convert.exe';
			return 'convert';
		}

		public static function get IM_CMD_MSL():String{
			if (ProcessRunner.isWindows()) return 'conjure.exe';
			return 'conjure';
		}

		public static function get IM_CMD_MONTAGE():String{
			if (ProcessRunner.isWindows()) return 'montage.exe';
			return 'montage';
		}

		public static function get IM_CMD_JPG2PDF():String{
			if (ProcessRunner.isWindows()) return 'bmpp.exe';
			return '';
		}

		public static function get IM_CMD_PDF_TOOL():String{
			if (ProcessRunner.isWindows()) return 'pdftk.exe';
			return '';
		}

		public static function get IM_CMD_PDF2JPG():String{
			if (ProcessRunner.isWindows()) return 'pdfimages.exe';
			return '';
		}

		public static const STATE_WAITE:int=0;
		public static const STATE_STARTED:int=1;
		public static const STATE_COMPLITE:int=2;
		public static const STATE_ERR:int=3;

		public var state:int=STATE_WAITE;
		public var folder:String;

		[Bindable]
		public var profileCaption:String;
		[Bindable]
		public var profileTarget:String;
		[Bindable]
		public var profileStart:Number;
		[Bindable]
		public var profileEnd:Number;
		[Bindable]
		public var profileDuration:Number;

		//TODO implement in IMRuner.procRespond
		public var redirectOut:String;

		
		public var parameters:Array=[];
		public var executable:String;
		public function IMCommand(type:String=null){
			if (type){
				executable=type;
			}
		}

		public function add(parameter:String):void{
			parameters.push(parameter);
		}

		public function append(command:IMCommand):void{
			parameters=parameters.concat(command.parameters);
		}

		public function prepend(command:IMCommand):void{
			parameters=command.parameters.concat(parameters);
		}
		
		public function toString():String{
			var result:String=executable+' "'+parameters.join('" "')+'"';
			if(redirectOut) result=result+' '+redirectOut;
			return result;
		}

		public function setProfile(caption:String,target:String):void{
			profileCaption=caption;
			profileTarget=target;
		}

	}
}