package com.photodispatcher.provider.fbook{
	import com.akmeful.fotokniga.net.vo.AuthLoginVO;
	import com.photodispatcher.util.JsonUtil;
	
	import mx.rpc.AsyncResponder;
	import mx.rpc.AsyncToken;
	import mx.rpc.events.FaultEvent;
	import mx.rpc.events.ResultEvent;
	import mx.rpc.http.mxml.HTTPService;
	
	public class FBookAuthService extends HTTPService{
		public static var _URL:String = "/auth";
		
		[Bindable]
		public var authorized:Boolean;
		[Bindable]
		public var email:String;
		public var baseUrl:String='/fbook';
		
		public function FBookAuthService(rootURL:String=null, destination:String=null){
			super(rootURL, destination);
		}
		
		/*
		public function checkLogin():void {
		
		
		this.url = AUTH_URL + "/check/";
		var token:AsyncToken = send();
		token.addResponder(new AsyncResponder(checkLogin_ResultHandler,checkLogin_FaultHandler));
		
		
		
		}
		*/
		
		private var loginForm:AuthLoginVO;
		public function siteLogin(email:String = "akmeful@gmail.com", pass:String = "123"):AsyncToken{
			this.url = baseUrl+_URL + "/login/";
			loginForm = new AuthLoginVO(email, pass);
			var data:Object = loginForm.generate();
			var token:AsyncToken = send(data);
			token.addResponder(new AsyncResponder(login_ResultHandler,login_FaultHandler));
			return token;
		}
		
		protected function login_ResultHandler(event:ResultEvent, token:AsyncToken):void {
			var r:Object = JsonUtil.decode(event.result as String);
			if(r.result){
				email = loginForm.email;
				authorized = true;
			} else {
				authorized = false;
			}
			loginForm = null;
		}
		
		protected function login_FaultHandler(event:FaultEvent, token:AsyncToken):void {
			authorized = false;
			loginForm = null;
		}
		
		public function siteLogout():AsyncToken {
			this.url = baseUrl+_URL + "/logout/";
			var token:AsyncToken = send({flash: "logout"});
			token.addResponder(new AsyncResponder(logout_ResultHandler,logout_FaultHandler));
			return token;
		}
		
		protected function logout_ResultHandler(event:ResultEvent, token:AsyncToken):void {
			var r:Object = JsonUtil.decode(event.result as String);
			if(r.result){
				authorized = false;
				email = null;
			}
		}
		
		protected function logout_FaultHandler(event:FaultEvent, token:AsyncToken):void {
		}
		
	}
}