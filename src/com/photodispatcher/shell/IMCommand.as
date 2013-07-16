package com.photodispatcher.shell{
	public class IMCommand{
		public static const IM_CMD_CONVERT:String='convert.exe';
		public static const IM_CMD_MSL:String='conjure.exe';

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
			return executable+' "'+parameters.join('" "')+'"';
		}

		public function setProfile(caption:String,target:String):void{
			profileCaption=caption;
			profileTarget=target;
		}

	}
}