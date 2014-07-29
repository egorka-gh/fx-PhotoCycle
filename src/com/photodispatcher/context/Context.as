package com.photodispatcher.context{
	import com.photodispatcher.model.AppConfig;
	import com.photodispatcher.model.ContentFilter;
	import com.photodispatcher.model.Roll;
	import com.photodispatcher.model.dao.AppConfigDAO;
	import com.photodispatcher.model.dao.AttrTypeDAO;
	import com.photodispatcher.model.dao.BookSynonymDAO;
	import com.photodispatcher.model.dao.DictionaryDAO;
	import com.photodispatcher.model.dao.OrderStateDAO;
	import com.photodispatcher.model.mysql.DbLatch;
	import com.photodispatcher.model.mysql.entities.AttrType;
	import com.photodispatcher.model.mysql.entities.FieldValue;
	import com.photodispatcher.model.mysql.entities.LabResize;
	import com.photodispatcher.model.mysql.entities.SelectResult;
	import com.photodispatcher.model.mysql.entities.Source;
	import com.photodispatcher.model.mysql.services.DictionaryService;
	import com.photodispatcher.model.mysql.services.LabResizeService;
	import com.photodispatcher.model.mysql.services.SourceService;
	import com.photodispatcher.util.ArrayUtil;
	
	import flash.events.Event;
	import flash.utils.Dictionary;
	
	import mx.collections.ArrayCollection;
	import mx.collections.IList;
	import mx.rpc.AsyncToken;
	
	import org.granite.tide.Tide;
	import org.granite.tide.events.TideResultEvent;

	public dynamic class Context{

		private static var instance:Context;

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
			Tide.getInstance().addComponents([DictionaryService, SourceService, LabResizeService]);
			
			//fill from config
			//Context.fillFromConfig();

			latch.join(Context.initSourceLists());
			latch.join(Context.initAttributeLists());
			latch.join(LabResize.initSizeMap());

			//init static maps
			/* TODO Implement*/
			OrderStateDAO.initStateMap();
			BookSynonymDAO.initSynonymMap();
			DictionaryDAO.initSynonymMap();
			Roll.initItemsMap();
			/**/
			latch.start();//start at caller?
			return latch;
		}

		public static function fillFromConfig():void{
			var appConfDAO:AppConfigDAO=new AppConfigDAO();
			var appConf:AppConfig=appConfDAO.getItem();
			if(appConf){
				//Context.setAttribute('workFolder',appConf.wrk_path);//backward compatibility, use local SharedObject .data.workFolder
				
				Context.setAttribute('syncInterval',appConf.monitor_interval);
				//content filter
				//load content filters
				var cfilters:Array=ContentFilter.filters;
				//current content filter
				var currCFilter:ContentFilter;
				if(cfilters) currCFilter=ArrayUtil.searchItem('id',appConf.content_filter,cfilters) as ContentFilter;
				if(!currCFilter){
					currCFilter= new ContentFilter();
					currCFilter.is_alias_filter=false;
					currCFilter.is_photo_allow=true;
					currCFilter.is_pro_allow=true;
					currCFilter.is_retail_allow=true;
				}
				Context.setAttribute('contentFilter',currCFilter);
			}else{
				//set to defaults
				
				Context.setAttribute('syncInterval',10);

			}
		}
		
		public static function setAttribute(name:String, value:*):void{
			instance[name] = value;	
		}		

		private static var sourcesArr:Array;
		private static var sourcesMap:Dictionary;
		
		public static function setSources(value:Array):void{
			if(sourcesArr && sourcesArr.length>0) return;
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
		public static function initSourceLists():DbLatch{
			/*
			if(sourcesArr && sourcesArr.length>0) return true;
			var dao:SourcesDAO= new SourcesDAO();
			//dao.findAll();
			var soArr:Array=dao.findAllArray();
			if(!soArr) return false;
			var sourse:Source;
			for each(sourse in soArr){
				if(sourse){
					if (!sourse.loadServices()) return false;
				}
			}
			*/
			var latch:DbLatch=new DbLatch();
			latch.debugName='initSourceLists';
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
					setSources((latch.lastResult as SelectResult).data.toArray());
				}
			}
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
				fillAttributeLists((latch.lastResult as SelectResult));
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
		
		private static function fillAttributeLists(select:SelectResult):void{
			if(!select){
				latchAttributeLists.releaseError('Ошибка инициализации (Context.fillAttributeLists)');
				latchAttributeLists.start();
				return;
			}
			var at:AttrType;
			var field:String;
			//var dDao:DictionaryDAO=new DictionaryDAO();
			var dict:DictionaryService=Tide.getInstance().getContext().byType(DictionaryService,true) as DictionaryService;
			var t:AsyncToken;
			
			//var a:ArrayCollection;
			for each (var o:Object in select.data){
				at=o as AttrType;
				if(at){
					field=at.field;
					t=dict.getFieldValueList(at.id,false,onFieldList);
					t.tag=field;
					latchAttributeLists.addLatch(t);
				}
			}

			t=dict.getBookTypeValueList(false,onFieldList);
			t.tag='book_type';
			latchAttributeLists.addLatch(t);

			t=dict.getBookPartValueList(false,onFieldList);
			t.tag='book_part';
			latchAttributeLists.addLatch(t);

			t=dict.getSrcTypeValueList(Source.LOCATION_TYPE_SOURCE, false, onFieldList);
			t.tag='src_type';
			latchAttributeLists.addLatch(t);

			t=dict.getSrcTypeValueList(Source.LOCATION_TYPE_LAB, true, onFieldListSimpleList);
			t.tag='lab_type';
			latchAttributeLists.addLatch(t);

			//tech_typeList !!!!
			t=dict.getSrcTypeValueList(Source.LOCATION_TYPE_TECH_POINT, false, onFieldList);
			t.tag='tech_type';
			latchAttributeLists.addLatch(t);

			//tech_points
			t=dict.getTechPointValueList(true, onFieldListSimpleList);
			t.tag='tech_point';
			latchAttributeLists.addLatch(t);

			//tech layers
			t=dict.getTechLayerValueList(true, onFieldList);
			t.tag='layer';
			latchAttributeLists.addLatch(t);

			//tech seq layers
			t=dict.getTechLayerValueList(true, onFieldList);
			t.tag='seqlayer';
			latchAttributeLists.addLatch(t);
			
			//tech layer group
			t=dict.getLayerGroupValueList(false, onFieldList);
			t.tag='layer_group';
			latchAttributeLists.addLatch(t);
			
			//lab rolls
			t=dict.getRollValueList(false, onFieldList);
			t.tag='roll';
			latchAttributeLists.addLatch(t);

			if(!Context.getAttribute('booleanList')){
				var a:ArrayCollection=new ArrayCollection();
				a.source=[{value:0,label:'-'},
					{value:true,label:'Да'},
					{value:false,label:'Нет'}];
				Context.setAttribute('booleanList', a);
			}
			latchAttributeLists.start();
		}

		/*
		public static function initAttributeListsOld():void{
			var at:AttrType;
			var field:String;
			//var atDao:AttrTypeDAO=new AttrTypeDAO();
			var dDao:DictionaryDAO=new DictionaryDAO();
			var a:ArrayCollection;
			for each (var o:Object in AttrType.getPrintAttrs()){
				at=o as AttrType;
				if(at){
					field=at.field;
					if(!Context.getAttribute(field+'List')){
						a=dDao.getFieldValueList(at.id);
						Context.setAttribute(field+'List', a);
					}
					if(!Context.getAttribute(field+'ValueList')){
						a=dDao.getFieldValueList(at.id,false);
						Context.setAttribute(field+'ValueList', a);
					}
				}
			}
			if(!Context.getAttribute('book_typeList')){
				a=dDao.getBookTypeValueList();
				Context.setAttribute('book_typeList', a);
				a=dDao.getBookTypeValueList(false);
				Context.setAttribute('book_typeValueList', a);
			}
			if(!Context.getAttribute('book_partList')){
				a=dDao.getBookPartValueList();
				Context.setAttribute('book_partList', a);
				a=dDao.getBookPartValueList(false);
				Context.setAttribute('book_partValueList', a);
			}
			if(!Context.getAttribute('src_typeList')){
				a=dDao.getSrcTypeValueList();
				Context.setAttribute('src_typeList', a);
			}
			if(!Context.getAttribute('lab_typeList')){
				a=dDao.getSrcTypeValueList(Source.LOCATION_TYPE_LAB);
				Context.setAttribute('lab_typeList', a);
			}
			//tech_typeList !!!!
			if(!Context.getAttribute('tech_typeList')){
				a=dDao.getSrcTypeValueList(Source.LOCATION_TYPE_TECH_POINT);
				Context.setAttribute('tech_typeList', a);
				a=dDao.getSrcTypeValueList(Source.LOCATION_TYPE_TECH_POINT,false);
				Context.setAttribute('tech_typeValueList', a);
			}

			//tech_points
			if(!Context.getAttribute('tech_pointList')){
				a=dDao.getTechPointValueList();
				Context.setAttribute('tech_pointList', a);
			}

			//tech layers
			if(!Context.getAttribute('layerValueList')){
				a=dDao.getTechLayerValueList();
				//Context.setAttribute('layerList', a);
				//Context.setAttribute('layerList', a);
				Context.setAttribute('layerValueList', a);
			}

			//tech seq layers
			if(!Context.getAttribute('seqlayerList')){
				a=dDao.getTechLayerValueList(false);
				Context.setAttribute('seqlayerList', a);
				Context.setAttribute('seqlayerValueList', a);
			}

			//tech layer group
			if(!Context.getAttribute('layer_groupList')){
				a=dDao.getLayerGroupValueList();
				Context.setAttribute('layer_groupList', a);
				Context.setAttribute('layer_groupValueList', a);
			}

			//lab rolls
			if(!Context.getAttribute('rollList')){
				a=dDao.getRollValueList();
				Context.setAttribute('rollList', a);
				a=dDao.getRollValueList(false);
				Context.setAttribute('rollValueList', a);
			}

			if(!Context.getAttribute('booleanList')){
				a=new ArrayCollection();
				a.source=[{value:0,label:'-'},
						  {value:true,label:'Да'},
						  {value:false,label:'Нет'}];
				Context.setAttribute('booleanList', a);
			}
		}

		if(!Context.getAttribute('book_typeList')){
			a=dDao.getBookTypeValueList();
			Context.setAttribute('book_typeList', a);
			a=dDao.getBookTypeValueList(false);
			Context.setAttribute('book_typeValueList', a);
		}
		if(!Context.getAttribute('book_partList')){
			a=dDao.getBookPartValueList();
			Context.setAttribute('book_partList', a);
			a=dDao.getBookPartValueList(false);
			Context.setAttribute('book_partValueList', a);
		}
		if(!Context.getAttribute('src_typeList')){
			a=dDao.getSrcTypeValueList();
			Context.setAttribute('src_typeList', a);
		}
		if(!Context.getAttribute('lab_typeList')){
			a=dDao.getSrcTypeValueList(Source.LOCATION_TYPE_LAB);
			Context.setAttribute('lab_typeList', a);
		}
		//tech_typeList !!!!
		if(!Context.getAttribute('tech_typeList')){
			a=dDao.getSrcTypeValueList(Source.LOCATION_TYPE_TECH_POINT);
			Context.setAttribute('tech_typeList', a);
			a=dDao.getSrcTypeValueList(Source.LOCATION_TYPE_TECH_POINT,false);
			Context.setAttribute('tech_typeValueList', a);
		}
		
		//tech_points
		if(!Context.getAttribute('tech_pointList')){
			a=dDao.getTechPointValueList();
			Context.setAttribute('tech_pointList', a);
		}
		
		//tech layers
		if(!Context.getAttribute('layerValueList')){
			a=dDao.getTechLayerValueList();
			//Context.setAttribute('layerList', a);
			//Context.setAttribute('layerList', a);
			Context.setAttribute('layerValueList', a);
		}
		
		//tech seq layers
		if(!Context.getAttribute('seqlayerList')){
			a=dDao.getTechLayerValueList(false);
			Context.setAttribute('seqlayerList', a);
			Context.setAttribute('seqlayerValueList', a);
		}
		
		//tech layer group
		if(!Context.getAttribute('layer_groupList')){
			a=dDao.getLayerGroupValueList();
			Context.setAttribute('layer_groupList', a);
			Context.setAttribute('layer_groupValueList', a);
		}
		
		//lab rolls
		if(!Context.getAttribute('rollList')){
			a=dDao.getRollValueList();
			Context.setAttribute('rollList', a);
			a=dDao.getRollValueList(false);
			Context.setAttribute('rollValueList', a);
		}
		
		if(!Context.getAttribute('booleanList')){
			a=new ArrayCollection();
			a.source=[{value:0,label:'-'},
				{value:true,label:'Да'},
				{value:false,label:'Нет'}];
			Context.setAttribute('booleanList', a);
		}
	}
		*/
	}
}