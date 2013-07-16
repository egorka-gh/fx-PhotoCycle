package com.photodispatcher.service.web{
	import com.photodispatcher.event.WebEvent;

	public class LoginInv extends WebInvoker{
		private var url:InvokerUrl;
		private var post:Object;
		private var loginSuccess:Boolean;

		public function LoginInv(client:WebClient, url:InvokerUrl, post:Object){
			super(client);
			this.url = url;
			this.post = post;
			loginSuccess=false;
		}

		override protected function startSequence ():void{
			sendRequest(url.url,post);
		}
		
		override protected function responseHandler(evt:WebEvent):void{
			switch (evt.response){
				case Responses.HTTP_STATUS:					
					loginSuccess= !url.locationUrl || evt.responseURL==url.locationUrl;
					break;
				case Responses.COMPLETE:
					if (loginSuccess){
						var logEvent:WebEvent = new WebEvent(WebEvent.LOGGED);
						release(logEvent);
					}else{
						releaseWithError('Не верный пароль или пользователь');
					}
					break;
				default:					
					releaseWithError(evt.error);
			}
		}
		
		override protected function cleanUp ():void{
		}

	}
}