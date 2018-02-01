package com.photodispatcher.service.web{
	import com.photodispatcher.event.WebEvent;

	public class DataInv extends WebInvoker{
		private var url:InvokerUrl;
		private var post:Object;

		private var loginSuccess:Boolean;

		public function DataInv(client:WebClient, url:InvokerUrl, post:Object, timeout:int=INVOK_TIMEOUT){
			super(client);
			this.url=url;
			this.post=post;
			loginSuccess=false;
			this.timeout=timeout;
		}

		override protected function startSequence ():void{
			sendRequest(url.url,post);
		}
		
		override protected function responseHandler(evt:WebEvent):void{
			switch (evt.response){
				case Responses.HTTP_STATUS:					
			 		loginSuccess= !url.locationUrl || evt.responseURL==url.locationUrl;
					//client.httpStatus
					break;
				case Responses.COMPLETE:
					if (loginSuccess){
						var e:WebEvent = new WebEvent(WebEvent.DATA);
						e.data=evt.data;
						release(e);
					}else{
						releaseWithError('Нет доступа к данным, url: '+url.locationUrl);
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