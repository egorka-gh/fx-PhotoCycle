package com.photodispatcher.service.web
{
	import com.google.zxing.common.flexdatatypes.StringBuilder;

	public class LocalWebAction
	{
		public var action:String;
		public var task:String;
		public var data:String;
		public var hasError:Boolean;
		public var error:String;
		public var httpStatus:int;
		public var responce:String;
		
		
		public function LocalWebAction(action:String, task:String, data:String)
		{
			this.action=action;
			this.task=task;
			this.data=data;
		}
		
		public function toPostObject():Object{
			var post:Object = new Object();
			post.action=action;
			post.task=task;
			post.data=data;
			return post;			
		}

		public function toString():String{
			return 'Action:'+action+'; Task:'+task+'; Data: '+data+'; HttpStatus: '+httpStatus+'; Responce: '+responce;			
		}

	}
}