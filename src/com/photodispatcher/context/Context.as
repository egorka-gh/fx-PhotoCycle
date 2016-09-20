package com.photodispatcher.context{
	import com.photodispatcher.model.mysql.DbLatch;
	import com.photodispatcher.model.mysql.entities.AliasForward;
	import com.photodispatcher.model.mysql.entities.AppConfig;
	import com.photodispatcher.model.mysql.entities.AttrJsonMap;
	import com.photodispatcher.model.mysql.entities.AttrType;
	import com.photodispatcher.model.mysql.entities.BookSynonym;
	import com.photodispatcher.model.mysql.entities.ContentFilter;
	import com.photodispatcher.model.mysql.entities.DeliveryType;
	import com.photodispatcher.model.mysql.entities.DeliveryTypeDictionary;
	import com.photodispatcher.model.mysql.entities.DeliveryTypePrintForm;
	import com.photodispatcher.model.mysql.entities.FieldValue;
	import com.photodispatcher.model.mysql.entities.HelloResponce;
	import com.photodispatcher.model.mysql.entities.LabPrintCode;
	import com.photodispatcher.model.mysql.entities.LabResize;
	import com.photodispatcher.model.mysql.entities.LabStopType;
	import com.photodispatcher.model.mysql.entities.LayersetSynonym;
	import com.photodispatcher.model.mysql.entities.OrderState;
	import com.photodispatcher.model.mysql.entities.PrintForm;
	import com.photodispatcher.model.mysql.entities.PrintFormField;
	import com.photodispatcher.model.mysql.entities.Roll;
	import com.photodispatcher.model.mysql.entities.SelectResult;
	import com.photodispatcher.model.mysql.entities.Source;
	import com.photodispatcher.model.mysql.entities.SourceProperty;
	import com.photodispatcher.model.mysql.entities.SubordersTemplate;
	import com.photodispatcher.model.mysql.entities.messenger.CycleStation;
	import com.photodispatcher.model.mysql.services.BookSynonymService;
	import com.photodispatcher.model.mysql.services.ConfigService;
	import com.photodispatcher.model.mysql.services.ContentFilterService;
	import com.photodispatcher.model.mysql.services.DictionaryService;
	import com.photodispatcher.model.mysql.services.LabResizeService;
	import com.photodispatcher.model.mysql.services.LabService;
	import com.photodispatcher.model.mysql.services.MailPackageService;
	import com.photodispatcher.model.mysql.services.OrderLoadService;
	import com.photodispatcher.model.mysql.services.OrderService;
	import com.photodispatcher.model.mysql.services.OrderStateService;
	import com.photodispatcher.model.mysql.services.PrintGroupService;
	import com.photodispatcher.model.mysql.services.PrnStrategyService;
	import com.photodispatcher.model.mysql.services.RollService;
	import com.photodispatcher.model.mysql.services.SourceService;
	import com.photodispatcher.model.mysql.services.StaffActivityService;
	import com.photodispatcher.model.mysql.services.TechPickerService;
	import com.photodispatcher.model.mysql.services.TechPointService;
	import com.photodispatcher.model.mysql.services.TechRejecService;
	import com.photodispatcher.model.mysql.services.TechService;
	import com.photodispatcher.model.mysql.services.XReportService;
	import com.photodispatcher.util.ArrayUtil;
	import com.photodispatcher.util.NetUtil;
	
	import flash.events.Event;
	import flash.filesystem.File;
	import flash.net.SharedObject;
	import flash.utils.Dictionary;
	
	import mx.collections.ArrayCollection;
	import mx.collections.IList;
	import mx.core.FlexGlobals;
	import mx.rpc.AsyncToken;
	import mx.utils.UIDUtil;
	
	import org.granite.meta;
	import org.granite.tide.Tide;
	import org.granite.tide.events.TideResultEvent;

	public dynamic class Context{

		public static const PRODUCTION_ANY:int=-1;
		public static const PRODUCTION_NOT_SET:int=0;


		private static var instance:Context;

		public static var config:AppConfig;


		// Static initializer
		{
			instance = new Context();

			//DOTO implement some config
			setAttribute('wrkDir','D:\\Buffer\\ftp');
		}

		public function Context(){
		}

		public static function getAttribute(name:String):*{
			if (instance.hasOwnProperty(name)){
				return instance[name];
			}else{
				trace("Context property '" + name + "' not found");
				return null;
			}
		}		

		public static function initPhotoCycle():DbLatch{
			var latch:DbLatch=new DbLatch();
			latch.debugName='initPhotoCycle';
			//register services
			
			Tide.getInstance().addComponents([
				DictionaryService, 
				SourceService, 
				LabResizeService, 
				OrderStateService, 
				BookSynonymService, 
				RollService, 
				ContentFilterService, 
				LabService,
				TechPointService,
				TechPickerService,
				OrderService,
				PrintGroupService,
				XReportService,
				TechService,
				ConfigService,
				StaffActivityService,
				MailPackageService,
				PrnStrategyService,
				TechRejecService//+
			]);
			
			//fill from config
			//Context.fillFromConfig();

			//init static maps
			latch.join(Context.loadConfig());
			latch.join(Context.initSourceLists());
			latch.join(Context.initAttributeLists());
			latch.join(LabResize.initSizeMap());
			latch.join(OrderState.initStateMap());
			latch.join(BookSynonym.initSynonymMap());
			latch.join(FieldValue.initSynonymMap());
			latch.join(Roll.initItemsMap());
			latch.join(LabPrintCode.initChanelMap());
			latch.join(AttrJsonMap.initJsonMap());
			latch.join(SourceProperty.initMap());
			latch.join(SubordersTemplate.initMap());
			latch.join(LayersetSynonym.initMap());
			latch.join(DeliveryTypeDictionary.initDeliveryTypeMap());
			latch.join(AliasForward.initMap());
			latch.join(LabStopType.initMap());

			latch.addEventListener(Event.COMPLETE,oninitTechOTK);

			//latch.start();//start at caller?
			return latch;
		}

		public static function initPhotoLoader():DbLatch{
			var latch:DbLatch=new DbLatch();
			latch.debugName='initPhotoLoader';
			//register services
			
			Tide.getInstance().addComponents([
				DictionaryService, 
				SourceService, 
				OrderStateService,
				OrderLoadService,
				ConfigService//+
			]);
			
			//fill from config
			//Context.fillFromConfig();
			
			//init static maps
			latch.join(Context.loadConfig());
			latch.join(Context.initSourceLists());
			latch.join(Context.initAttributeLists());
			latch.join(OrderState.initStateMap());
			latch.join(FieldValue.initSynonymMap());
			latch.join(AttrJsonMap.initJsonMap());
			latch.join(AliasForward.initMap());
			
			return latch;
		}

		public static function initLab():DbLatch{
			var latch:DbLatch=new DbLatch();
			latch.debugName='initLab';
			//register services
			Tide.getInstance().addComponents([
				DictionaryService, 
				SourceService, 
				//LabResizeService, 
				OrderStateService, 
				BookSynonymService, 
				RollService, 
				//ContentFilterService, 
				LabService,
				//TechPointService,
				//TechPickerService,
				OrderService,
				PrintGroupService,
				PrnStrategyService
			]);
			
			//fill from config
			//Context.fillFromConfig();
			
			//init static maps
			latch.join(Context.initSourceLists());
			latch.join(Context.initAttributeLists());
			//latch.join(LabResize.initSizeMap());
			latch.join(OrderState.initStateMap());
			latch.join(BookSynonym.initSynonymMap());
			//latch.join(FieldValue.initSynonymMap());
			latch.join(Roll.initItemsMap());
			latch.join(LabStopType.initMap());
			//latch.join(LabPrintCode.initChanelMap());
			//latch.join(AttrJsonMap.initJsonMap());
			//latch.join(SourceProperty.initMap());
			
			//latch.start();//start at caller?
			return latch;
		}
		
		public static function initPhotoTech():DbLatch{
			var latch:DbLatch=new DbLatch();
			latch.debugName='initPhotoTech';
			//register services
			Tide.getInstance().addComponents([
				DictionaryService, 
				SourceService, 
				//LabResizeService, 
				OrderStateService, 
				//BookSynonymService, 
				//RollService, 
				//ContentFilterService, 
				//LabService,
				TechPointService,
				TechService,
				OrderService //+
			]);
			
			//fill from config
			//Context.fillFromConfig();
			
			//init static maps
			latch.join(Context.initSourceLists());
			latch.join(Context.initAttributeLists());
			//latch.join(LabResize.initSizeMap());
			latch.join(OrderState.initStateMap());
			//latch.join(BookSynonym.initSynonymMap());
			//latch.join(FieldValue.initSynonymMap());
			//latch.join(Roll.initItemsMap());
			//latch.join(LabPrintCode.initChanelMap());
			//latch.join(AttrJsonMap.initJsonMap());
			
			//latch.start();//start at caller?
			return latch;
		}
		
		public static function initTechMonitor():DbLatch{
			var latch:DbLatch=new DbLatch();
			latch.debugName='initTechMonitor';
			//register services
			Tide.getInstance().addComponents([
				DictionaryService, 
				SourceService, 
				//LabResizeService, 
				OrderStateService, 
				//BookSynonymService, 
				//RollService, 
				//ContentFilterService, 
				//LabService,
				TechPointService,
				TechService,
				OrderService //+
			]);
			
			//fill from config
			//Context.fillFromConfig();
			
			//init static maps
			latch.join(Context.initSourceLists());
			latch.join(Context.initAttributeLists());
			//latch.join(LabResize.initSizeMap());
			latch.join(OrderState.initStateMap());
			//latch.join(BookSynonym.initSynonymMap());
			//latch.join(FieldValue.initSynonymMap());
			//latch.join(Roll.initItemsMap());
			//latch.join(LabPrintCode.initChanelMap());
			//latch.join(AttrJsonMap.initJsonMap());
			
			//latch.start();//start at caller?
			return latch;
		}

		public static function initPhotoPicker():DbLatch{
			var latch:DbLatch=new DbLatch();
			latch.debugName='initPhotoPicker';
			//register services
			Tide.getInstance().addComponents([
				DictionaryService, 
				SourceService, 
				//LabResizeService, 
				OrderStateService, 
				//BookSynonymService, 
				//RollService, 
				//ContentFilterService, 
				//LabService,
				TechPointService,
				TechPickerService,
				TechService,
				OrderService //+
			]);
			
			//fill from config
			//Context.fillFromConfig();
			
			//init static maps
			latch.join(Context.initSourceLists());
			latch.join(Context.initAttributeLists());
			//latch.join(LabResize.initSizeMap());
			latch.join(OrderState.initStateMap());
			//latch.join(BookSynonym.initSynonymMap());
			//latch.join(FieldValue.initSynonymMap());
			//latch.join(Roll.initItemsMap());
			//latch.join(LabPrintCode.initChanelMap());
			//latch.join(AttrJsonMap.initJsonMap());
			
			//latch.start();//start at caller?
			return latch;
		}

		public static function initPhotoGlue():DbLatch{
			var latch:DbLatch=new DbLatch();
			latch.debugName='initPhotoPicker';
			//register services
			Tide.getInstance().addComponents([
				DictionaryService, 
				SourceService, 
				//LabResizeService, 
				OrderStateService, 
				BookSynonymService, 
				//RollService, 
				//ContentFilterService, 
				//LabService,
				TechPointService,
				TechPickerService,
				TechService,
				OrderService,
				PrintGroupService//+
			]);
			
			//fill from config
			//Context.fillFromConfig();
			
			//init static maps
			latch.join(Context.initSourceLists());
			latch.join(Context.initAttributeLists());
			//latch.join(LabResize.initSizeMap());
			latch.join(OrderState.initStateMap());
			latch.join(BookSynonym.initSynonymMap());
			//latch.join(FieldValue.initSynonymMap());
			//latch.join(Roll.initItemsMap());
			//latch.join(LabPrintCode.initChanelMap());
			//latch.join(AttrJsonMap.initJsonMap());
			
			//latch.start();//start at caller?
			return latch;
		}

		public static function initReject():DbLatch{
			var latch:DbLatch=new DbLatch();
			latch.debugName='initReject';
			//register services
			Tide.getInstance().addComponents([
				DictionaryService, 
				SourceService, 
				OrderStateService, 
				TechPointService,
				OrderService ,
				TechRejecService,
				StaffActivityService,
				TechService//+
			]);

			//init static maps
			latch.join(Context.initSourceLists());
			latch.join(Context.initAttributeLists());
			latch.join(OrderState.initStateMap());
			return latch;
		}

		public static function initPhotoCorrector():DbLatch{
			var latch:DbLatch=new DbLatch();
			latch.debugName='initPhotoCorrector';
			//register services
			Tide.getInstance().addComponents([
				DictionaryService, 
				SourceService, 
				OrderStateService, 
				TechPointService,
				OrderService //+
			]);
			
			//init static maps
			latch.join(Context.initSourceLists());
			latch.join(Context.initAttributeLists());
			latch.join(OrderState.initStateMap());
			return latch;
		}

		public static function initTechOTK():DbLatch{
			var latch:DbLatch=new DbLatch();
			latch.debugName='initTechOTK';
			//register services
			Tide.getInstance().addComponents([
				DictionaryService, 
				SourceService, 
				//LabResizeService, 
				OrderStateService, 
				BookSynonymService, 
				//RollService, 
				//ContentFilterService, 
				//LabService,
				TechPointService,
				TechPickerService,
				TechService,
				OrderService,
				MailPackageService,
				XReportService//+
			]);
			
			//fill from config
			//Context.fillFromConfig();
			
			//init static maps
			latch.join(Context.initSourceLists());
			latch.join(Context.initAttributeLists());
			latch.join(OrderState.initStateMap());
			latch.join(BookSynonym.initSynonymMap());
			latch.join(FieldValue.initSynonymMap());
			latch.join(AttrJsonMap.initJsonMap());
			latch.join(DeliveryTypeDictionary.initDeliveryTypeMap());
			latch.join(PrintFormField.initFieldItemsMap());
			latch.join(DeliveryTypePrintForm.initFormsMap());
			latch.join(PrintForm.initParametersMap());
			
			latch.addEventListener(Event.COMPLETE,oninitTechOTK);

			//latch.start();//start at caller?
			return latch;
		}
		private static function oninitTechOTK(event:Event):void{
			var latch:DbLatch= event.target as DbLatch;
			if(latch){
				latch.removeEventListener(Event.COMPLETE,oninitTechOTK);
				if(latch.complite){
					DeliveryType.initHideClienMap();
				}
			}
		}

		public static function initTechSpy():DbLatch{
			var latch:DbLatch=new DbLatch();
			latch.debugName='initTechSpy';
			//register services
			Tide.getInstance().addComponents([
				DictionaryService, 
				SourceService, 
				//LabResizeService, 
				OrderStateService, 
				//BookSynonymService, 
				//RollService, 
				//ContentFilterService, 
				//LabService,
				TechPointService,
				TechPickerService,
				TechService,
				OrderService,
				XReportService //+
			]);
			
			//fill from config
			//Context.fillFromConfig();
			
			//init static maps
			latch.join(Context.initSourceLists());
			latch.join(Context.initAttributeLists());
			//latch.join(LabResize.initSizeMap());
			latch.join(OrderState.initStateMap());
			//latch.join(BookSynonym.initSynonymMap());
			//latch.join(FieldValue.initSynonymMap());
			//latch.join(Roll.initItemsMap());
			//latch.join(LabPrintCode.initChanelMap());
			//latch.join(AttrJsonMap.initJsonMap());
			
			//latch.start();//start at caller?
			return latch;
		}


		private static var _appID:String;
		public static function get appID():String{
			if(_appID) return _appID;
			
			_appID=NetUtil.getIP();
			if(_appID){
				_appID=_appID+':'+currentOSUser;
				_appID=_appID.substr(0,50);
			}
			if(!_appID) _appID=UIDUtil.createUID();
			return _appID;
		}

		private static var _station:CycleStation;
		public static function get station():CycleStation{
			if(!_station){
				_station= new CycleStation;
				_station.id=appID;
				_station.name=FlexGlobals.topLevelApplication.name;
				
			}
			return _station;
		}
		public static function checkStationId(id:String):Boolean{
			if(id=='*') return true;
			return _station && _station.id==id;
		}

		public static function get currentOSUser():String		{
			var userDir:String = File.userDirectory.nativePath;
			var userName:String = userDir.substr(userDir.lastIndexOf(File.separator) + 1);
			return userName;
		}

		
		public static function setAttribute(name:String, value:*):void{
			instance[name] = value;	
		}		

		private static var sourcesArr:Array;
		private static var sourcesMap:Dictionary;
		
		public static function setSources(value:Array):void{
			sourcesArr=value;
			sourcesMap=new Dictionary();
			if(value){
				for each (var o:Object in value){
					var s:Source=o as Source;
					if(s){
						sourcesMap[s.id]=s;
					}
				}
			}
		}		
		public static function getSources():Array{
			return sourcesArr?sourcesArr.slice():null;
		}
		public static function getSource(id:int):Source{
			if(!sourcesMap) return null;
			return (sourcesMap[id] as Source);
		}
		public static function getSourceCodeById(id:int):String{
			var src:Source=getSource(id);
			if(!src) return '';
			return src.code;
		}
		public static function getSourceIdByCode(code:String):int{
			if(!code) return 0;
			var arr:Array=getSources();
			if(!arr) return 0;
			var src:Source=ArrayUtil.searchItem('code',code,arr) as Source;
			return src?src.id:0;
		}
		public static function getSourceType(id:int):int{
			var src:Source=getSource(id);
			return src?src.type:0;
		}

		public static function initSourceLists():DbLatch{
			var latch:DbLatch=new DbLatch();
			//latch.debugName='initSourceLists';
			var svc:SourceService=Tide.getInstance().getContext().byType(SourceService,true) as SourceService;
			latch.addEventListener(Event.COMPLETE,onSourceLoad);
			latch.addLatch(svc.loadAll(Source.LOCATION_TYPE_SOURCE));
			latch.start();
			return latch;
		}
		private static function onSourceLoad(event:Event):void{
			var latch:DbLatch= event.target as DbLatch;
			if(latch){
				latch.removeEventListener(Event.COMPLETE,onSourceLoad);
				if(latch.complite){
					setSources(latch.lastDataArr);
				}
			}
		}
		public static function loadConfig():DbLatch{
			var latch:DbLatch=new DbLatch();
			//latch.debugName='initSourceLists';
			var svc:ConfigService=Tide.getInstance().getContext().byType(ConfigService,true) as ConfigService;
			latch.addEventListener(Event.COMPLETE,onConfigLoad);
			latch.addLatch(svc.loadConfig());
			latch.start();
			return latch;
		}
		private static function onConfigLoad(event:Event):void{
			var latch:DbLatch= event.target as DbLatch;
			if(latch){
				latch.removeEventListener(Event.COMPLETE,onConfigLoad);
				if(latch.complite){
					config=latch.lastDataItem as AppConfig;
				}
			}
		}

		public static function saveConfig():void{
			if(!config) return;
			var latch:DbLatch=new DbLatch();
			//latch.debugName='initSourceLists';
			var svc:ConfigService=Tide.getInstance().getContext().byType(ConfigService,true) as ConfigService;
			latch.addEventListener(Event.COMPLETE,onConfigSave);
			latch.addLatch(svc.saveConfig(config));
			latch.start();
			//return latch;
		}
		private static function onConfigSave(event:Event):void{
			var latch:DbLatch= event.target as DbLatch;
			if(latch){
				latch.removeEventListener(Event.COMPLETE,onConfigLoad);
			}
		}

		public static function getProduction():int{
			if(!config) return -1;
			return config.production;
		}
		public static function getProductionName():String{
			var p:int=PRODUCTION_ANY;
			if(config) p=config.production;
			if(p==PRODUCTION_ANY) return 'Все заказы (отключено)';
			if(p==PRODUCTION_NOT_SET) return 'Не назначено';
			return config.production_name;
		}

		
		private static var serverRootUrl:String;
		public static function getServerRootUrl():String{
			if(!serverRootUrl){
				var str:String;
				var so:SharedObject = SharedObject.getLocal('appProps','/');
				str=so.data.bdServer;
				var bdServerPort:String=so.data.bdServerPort;
				if(!bdServerPort) bdServerPort='8080';

				if(str) serverRootUrl='http://'+str+':'+bdServerPort+'/PhCServer';
			}
			return serverRootUrl;
		}

		private static var chatRootUrl:String;
		public static function getChatRootUrl():String{
			if(!chatRootUrl){
				var str:String;
				var so:SharedObject = SharedObject.getLocal('appProps','/');
				str=so.data.bdServer;
				var bdServerPort:String=so.data.bdServerPort;
				if(!bdServerPort) bdServerPort='8080';
				
				if(str) chatRootUrl='http://'+str+':'+bdServerPort+'/PhChat';
			}
			return chatRootUrl;
		}

		private static var latchAttributeLists:DbLatch;
		public static function initAttributeLists():DbLatch{
			latchAttributeLists= new DbLatch();
			var dict:DictionaryService=Tide.getInstance().getContext().byType(DictionaryService,true) as DictionaryService;
			var latch:DbLatch=new DbLatch();
			latch.addEventListener(Event.COMPLETE,onAttributeLists);
			latch.addLatch(dict.getPrintAttrs());
			latch.start();
			return latchAttributeLists;
		}
		private static function onAttributeLists(event:Event):void{
			var latch:DbLatch= event.target as DbLatch;
			if(latch){
				latch.removeEventListener(Event.COMPLETE,onAttributeLists);
				if(latch.hasError){
					latchAttributeLists.join(latch);
					latchAttributeLists.start();
					return;
				}
				//fillAttributeLists((latch.lastResult as SelectResult));
				fillAttributeLists(latch.lastDataArr);
			}
		}

		private static function onFieldList(event:TideResultEvent):void{
			var field:String=event.asyncToken.tag; 
			var res:SelectResult=event.result as SelectResult;
			if(field && res && res.complete){
				var ac:ArrayCollection =new ArrayCollection();
				ac.addAll(res.data);
				Context.setAttribute(field+'ValueList', ac);
				//add empty 0 value, ' ' label
				ac=new ArrayCollection();
				ac.addAll(res.data);
				var fv:FieldValue= new FieldValue();
				fv.value=0;
				fv.label=' ';
				ac.addItemAt(fv,0);
				Context.setAttribute(field+'List', ac);
			}
		}
		private static function onFieldListSimpleList(event:TideResultEvent):void{
			var field:String=event.asyncToken.tag; 
			var res:SelectResult=event.result as SelectResult;
			if(field && res && res.complete){
				var ac:ArrayCollection =new ArrayCollection();
				ac.addAll(res.data);
				Context.setAttribute(field+'List', ac);
			}
		}
		
		private static function fillAttributeLists(data:Array):void{ 
			if(!data){
				latchAttributeLists.releaseError('Ошибка инициализации (Context.fillAttributeLists)');
				latchAttributeLists.start();
				return;
			}
			var at:AttrType;
			var field:String;
			//var dDao:DictionaryDAO=new DictionaryDAO();
			var dict:DictionaryService=Tide.getInstance().getContext().byType(DictionaryService,true) as DictionaryService;
			//var t:AsyncToken;
			
			//var a:ArrayCollection;
			for each (var o:Object in data){
				at=o as AttrType;
				if(at){
					field=at.field;
					latchAttributeLists.addLatch(dict.getFieldValueList(at.id,false,onFieldList),field);
				}
			}

			latchAttributeLists.addLatch(dict.getBookTypeValueList(false,onFieldList),'book_type');

			latchAttributeLists.addLatch(dict.getBookPartValueList(false,onFieldList),'book_part');

			latchAttributeLists.addLatch(dict.getSrcTypeValueList(Source.LOCATION_TYPE_SOURCE, false, onFieldList),'src_type');

			latchAttributeLists.addLatch(dict.getSrcTypeValueList(Source.LOCATION_TYPE_LAB, false, onFieldList),'lab_type');

			//tech_typeList !!!!
			//latchAttributeLists.addLatch(dict.getSrcTypeValueList(Source.LOCATION_TYPE_TECH_POINT, false, onFieldList),'tech_type');
			latchAttributeLists.addLatch(dict.getTechTypeValueList(onFieldList),'tech_type');

			//tech_points
			latchAttributeLists.addLatch(dict.getTechPointValueList(true, onFieldList),'tech_point');

			//tech layers
			latchAttributeLists.addLatch(dict.getTechLayerValueList(true, onFieldList),'layer');

			//tech interlayer
			latchAttributeLists.addLatch(dict.getInterlayerValueList(onFieldList),'interlayer');

			//tech seq layers
			latchAttributeLists.addLatch(dict.getTechLayerValueList(true, onFieldList),'seqlayer');
			
			//tech layer group
			latchAttributeLists.addLatch(dict.getLayerGroupValueList(false, onFieldList),'layer_group');
			
			//lab rolls
			latchAttributeLists.addLatch(dict.getRollValueList(false, onFieldList),'roll');
			
			//book synonym_type
			latchAttributeLists.addLatch(dict.getBookSynonimTypeValueList(onFieldList),'synonym_type');

			//staff
			latchAttributeLists.addLatch(dict.getStaffValueList(onFieldList),'staff');
			//staff activity group
			latchAttributeLists.addLatch(dict.getStaffActivityGroupValueList(onFieldList),'sa_group');
			
			//order state 
			latchAttributeLists.addLatch(dict.getStateValueList(onFieldList),'state');
			//racks 
			latchAttributeLists.addLatch(dict.getRackValueList(onFieldList),'rack');
			//lab stop_type
			latchAttributeLists.addLatch(dict.getStopTypeValueList(onFieldList),'lab_stop_type');
			//print strategy_type
			//latchAttributeLists.addLatch(dict.getPrnStrategyValueList(onFieldList),'strategy_type');
			latchAttributeLists.addLatch(dict.getPrnStrategyManualValueList(onFieldList),'strategy_type');
			//print strategy_type manual
			latchAttributeLists.addLatch(dict.getPrnStrategyManualValueList(onFieldList),'strategy_type_manual');

			//reject_unit
			latchAttributeLists.addLatch(dict.getRejectUnitValueList(onFieldList),'reject_unit');
			//reject_unit
			latchAttributeLists.addLatch(dict.getTechUnitValueList(onFieldList),'thech_unit');

			//glue_cmd
			latchAttributeLists.addLatch(dict.getGlueCmdValueList(onFieldList),'glue_cmd');
			//order program
			latchAttributeLists.addLatch(dict.getOrderProgramValueList(onFieldList),'order_program');

			var a:ArrayCollection;
			if(!Context.getAttribute('booleanList')){
				a=new ArrayCollection();
				a.source=[{value:0,label:'-'},
					{value:true,label:'Да'},
					{value:false,label:'Нет'}];
				Context.setAttribute('booleanList', a);
			}
			latchAttributeLists.start();
		}


	}
}