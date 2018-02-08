package com.photodispatcher.service.glue
{
	import mx.collections.ArrayCollection;

	[Bindable]
	public class GlueProgramStep
	{
		public static const TYPE_NONE:int=0;
		public static const TYPE_WAIT_FOR:int=1;
		public static const TYPE_PAUSE:int=2;
		public static const TYPE_PUSH_BUTTON:int=3;

		public static const TYPES_LIST:ArrayCollection= new ArrayCollection(['','Ожидать состояние','Пауза','Нажать']);

		public function GlueProgramStep()
		{
		}
		
		private var _type:int;
		public function get type():int{
			return _type;
		}

		public function set type(value:int):void{
			_type = value;
			setCaption();
		}

		public var interval:int=200;
		public var command:String='';
		public var caption:String='-';
		public var checkBlocks:ArrayCollection;//GlueMessageBlock

		public function getItems():ArrayCollection{
			var items:Array=[];
			if(checkBlocks){
				for each (var b:GlueMessageBlock in checkBlocks){
					items=items.concat(b.items.source);	
				}
				
			}
			return new ArrayCollection(items);
		}
		
		public function setCaption():void{
			var ss:String=TYPES_LIST.getItemAt(_type) as String;
			switch(_type)
			{
				case TYPE_PAUSE:
				{
					ss=ss+' '+interval.toString(); 	
					break;
				}
				case TYPE_PUSH_BUTTON:
				{
					ss=ss+' '+command; 	
					break;
				}
				case TYPE_WAIT_FOR:
				{
					ss=ss;
					for each (var b:GlueMessageBlock in checkBlocks) ss=ss+' '+b.key+';';  
					break;
				}
			}
			if(!ss) ss='-';
			caption=ss;
		}

	}
}