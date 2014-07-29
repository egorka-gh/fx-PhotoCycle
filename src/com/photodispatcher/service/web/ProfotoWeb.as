package com.photodispatcher.service.web{
	import com.adobe.serialization.json.JSONDecoder;
	import com.photodispatcher.event.WebEvent;
	import com.photodispatcher.factory.OrderBuilder;
	import com.photodispatcher.model.Order;
	import com.photodispatcher.model.mysql.entities.Source;
	import com.photodispatcher.model.SourceType;
	import com.photodispatcher.model.mysql.entities.SourceSvc;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.HTTPStatusEvent;
	import flash.events.IEventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.net.URLRequestMethod;
	import flash.net.URLVariables;

	[Event(name="complete", type="flash.events.Event")]
	public class ProfotoWeb extends BaseWeb{
		//urls
		public static const URL_LOGIN:String='personal/login/';
		public static const URL_LOGIN_REDIRECT_SUCCESS:String='albom/';
		public static const URL_ORDERS:String='zone51/storage/orders/';
		
		//login params
		public static const PARAM_USER:String='login'; 
		public static const PARAM_PASSWORD:String='password';
		
		//order list params
		public static const PARAM_SORT_TYPE:String='dir'; //ASC DESC
		public static const PARAM_ITEM_LIMIT:String='limit'; //orders to fetch
		public static const PARAM_OPERATION:String='op'; //operation
		public static const PARAM_OPERATION_LIST:String='list'; //operation
		public static const PARAM_ORDER_STATUS:String='orderstatus'; //filter by status
		/*
		1 Ждет обработки оператором
		2 Изготовлен, ждет доставки
		10 Ждёт выбора способа оплаты
		*/
		public static const PARAM_ORDER_STATUS_VALUE:int=2; //remote orders state
		public static const PARAM_STATUS_PRELOAD_VALUES:Array=[1,10];
		public static const PARAM_ORDER_STATUS_MATCH:String='orderstatus_match'; //status compare type
		public static const PARAM_SORT_FIELD:String='sort'; //sort by field
		public static const PARAM_LIST_START:String='start'; //starting row
		public static const PARAM_ORDER_ID:String='human_id'; //order to search 
		public static const PARAM_ORDER_ID_MATCH:String='human_id_match'; //order search compare type
		public static const PARAM_ORDER_ID_MATCH_VALUE:String='equal'; //order search compare type value

		private static const STATE_LOGIN:int=0;
		private static const STATE_GET_ORDERS_NUM:int=1;
		private static const STATE_GET_ORDERS:int=2;
		private static const STATE_CHECK_ORDER_STATE:int=3;


		private var state:int;

		public function ProfotoWeb(source:Source){
			super(source);
		}
		
		private var preloadStates:Array=[];
		private var is_preload:Boolean;
		private var fetchState:int=-1;

		override public function sync():void{
			if(!source || source.type!=SourceType.SRC_PROFOTO){
				abort('Не верная иннициализация синхронизации');
				return;
			}
			cmd=CMD_SYNC;
			state=STATE_LOGIN;
			_hasError=false;
			_errMesage='';
			orderes=[];
			is_preload=true;
			preloadStates=PARAM_STATUS_PRELOAD_VALUES.concat();
			startListen();
			login();
		}

		private var _getOrder:Order;
		override public function get lastOrderId():String{
			return _getOrder?_getOrder.id:'';
		}
		override public function getOrder(order:Order):void{
			lastOrder=null;
			if(!source || source.type!==SourceType.SRC_PROFOTO || !order || !order.ftp_folder){
				abort('Не верная иннициализация синхронизации');
				return;
			}
			_getOrder=order;
			cmd=CMD_CHECK_STATE;
			state=STATE_LOGIN;
			_hasError=false;
			_errMesage='';
			orderes=[];
			startListen();
			login();
		}
		
		override public function isValidLastOrder(forLoad:Boolean=false):Boolean{
			if(forLoad){
				return (lastOrder && PARAM_STATUS_PRELOAD_VALUES.concat(PARAM_ORDER_STATUS_VALUE).indexOf(int(lastOrder.src_state))!=-1);
			}else{
				return (lastOrder && int(lastOrder.src_state)==PARAM_ORDER_STATUS_VALUE);
			}
		}
		
		private function login():void{
			var svc:SourceSvc=source.webService;
			if(!baseUrl){
				abort('Не указан url сервиса');
				return;
			}
			var post:Object= new Object();
			post[PARAM_USER]=svc.user;
			post[PARAM_PASSWORD]=svc.pass;
			client.login(new InvokerUrl(baseUrl+URL_LOGIN,baseUrl+URL_LOGIN_REDIRECT_SUCCESS),post);
		}

		override protected function handleLogin(e:Event):void{
			var post:Object;
			switch (cmd){
				case CMD_SYNC:
					/*
					state=STATE_GET_ORDERS_NUM;
					post= new Object();
					post[PARAM_SORT_TYPE]='ASC';
					post[PARAM_ITEM_LIMIT]='1';//getting tottal count
					post[PARAM_OPERATION]=PARAM_OPERATION_LIST;
					post[PARAM_ORDER_STATUS]=PARAM_ORDER_STATUS_VALUE;
					post[PARAM_ORDER_STATUS_MATCH]='equal_int';
					post[PARAM_SORT_FIELD]='orderdate';
					post[PARAM_LIST_START]='0';
					client.getData( new InvokerUrl(baseUrl+URL_ORDERS,baseUrl+URL_ORDERS),post);
					*/
					getData();
					break;
				case CMD_CHECK_STATE:
					state=STATE_CHECK_ORDER_STATE;
					post= new Object();
					/* check state post params
					dir	ASC
					human_id	20120820013_21931
					human_id_match	equal
					limit	20
					op	list
					sort	orderstatus
					*/
					post[PARAM_SORT_TYPE]='ASC';
					post[PARAM_ITEM_LIMIT]='1';//expecting 1 order
					post[PARAM_OPERATION]=PARAM_OPERATION_LIST;
					post[PARAM_ORDER_ID]=_getOrder.ftp_folder;
					post[PARAM_ORDER_ID_MATCH]=PARAM_ORDER_ID_MATCH_VALUE;
					post[PARAM_SORT_FIELD]='orderdate';
					client.getData( new InvokerUrl(baseUrl+URL_ORDERS,baseUrl+URL_ORDERS),post);
					break;
				
			}
		}

		protected function getData():void{
			var post:Object;
			if(!is_preload){
				//complited
				endSync();
				return;
			}
			is_preload=preloadStates.length>0;
			if(is_preload){
				fetchState=preloadStates.pop();
			}else{
				fetchState=PARAM_ORDER_STATUS_VALUE;
			}
			state=STATE_GET_ORDERS_NUM;
			post= new Object();
			post[PARAM_SORT_TYPE]='ASC';
			post[PARAM_ITEM_LIMIT]='1';//getting tottal count
			post[PARAM_OPERATION]=PARAM_OPERATION_LIST;
			post[PARAM_ORDER_STATUS]=fetchState;
			post[PARAM_ORDER_STATUS_MATCH]='equal_int';
			post[PARAM_SORT_FIELD]='orderdate';
			post[PARAM_LIST_START]='0';
			client.getData( new InvokerUrl(baseUrl+URL_ORDERS,baseUrl+URL_ORDERS),post);
		}
		
		override protected function handleData(e:WebEvent):void{
			//data -> {items:array, totalCount:num}
			var result:Object;
			switch (state){
				case STATE_GET_ORDERS_NUM:
					result=parseOrders(e.data);
					//TODO hardcoded totalCount
					if(!result || !result.hasOwnProperty('totalCount')){
						abort('Ошибка структуры данных');
						return;
					}
					var ordersNum:int=result.totalCount;
					if(ordersNum<=0){
						/*
						orderes=[];
						endSync();
						*/
						getData();
						return;
					}
					state=STATE_GET_ORDERS;
					var post:Object= new Object();
					post[PARAM_SORT_TYPE]='ASC';
					post[PARAM_ITEM_LIMIT]=ordersNum.toString();
					post[PARAM_OPERATION]=PARAM_OPERATION_LIST;
					//post[PARAM_ORDER_STATUS]=PARAM_ORDER_STATUS_VALUE;
					post[PARAM_ORDER_STATUS]=fetchState;
					post[PARAM_ORDER_STATUS_MATCH]='equal_int';
					post[PARAM_SORT_FIELD]='orderdate';
					post[PARAM_LIST_START]='0';
					client.getData( new InvokerUrl(baseUrl+URL_ORDERS,baseUrl+URL_ORDERS),post);
					break;
				case STATE_GET_ORDERS:
					result=parseOrders(e.data);
					//TODO hardcoded items
					if(!result || !result.hasOwnProperty('items') || !(result.items is Array)){
						abort('Ошибка структуры данных');
						return;
					}
					//orderes=result.items;
					//set preload mark
					var a:Array=result.items;
					var it:Object;
					for each(it in a){
						it.is_preload=is_preload?1:0;
					}
					//add to result
					orderes=orderes.concat(a);
					//endSync();
					getData();
					break;
				case STATE_CHECK_ORDER_STATE:
					result=parseOrders(e.data);
					//TODO hardcoded items
					if(!result || !result.hasOwnProperty('items') || !(result.items is Array)){
						abort('Ошибка структуры данных');
						return;
					}
					orderes=result.items;
					endGetOrder();
					break;
			}
			
		}

	}
}