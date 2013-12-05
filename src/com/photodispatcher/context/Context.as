package com.photodispatcher.context{
	import com.photodispatcher.model.AppConfig;
	import com.photodispatcher.model.AttrType;
	import com.photodispatcher.model.Source;
	import com.photodispatcher.model.dao.AppConfigDAO;
	import com.photodispatcher.model.dao.AttrTypeDAO;
	import com.photodispatcher.model.dao.DictionaryDAO;
	import com.photodispatcher.model.dao.SourcesDAO;
	
	import flash.utils.Dictionary;
	
	import mx.collections.ArrayCollection;

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
		
		public static function fillFromConfig():void{
			var appConfDAO:AppConfigDAO=new AppConfigDAO();
			var appConf:AppConfig=appConfDAO.getItem();
			if(appConf){
				Context.setAttribute('workFolder',appConf.wrk_path);//backward compatibility, use local SharedObject .data.workFolder
				
				Context.setAttribute('syncInterval',appConf.monitor_interval);
				
				//set fbook params
				//block
				Context.setAttribute('fbook.block.font.size',appConf.fbblok_font);
				Context.setAttribute('fbook.block.notching',appConf.fbblok_notching);
				Context.setAttribute('fbook.block.barcode.size',appConf.fbblok_bar);
				Context.setAttribute('fbook.block.barcode.offset',appConf.fbblok_bar_offset);
				//cover
				Context.setAttribute('fbook.cover.font.size',appConf.fbcover_font);
				Context.setAttribute('fbook.cover.notching',appConf.fbcover_notching);
				Context.setAttribute('fbook.cover.barcode.size',appConf.fbcover_bar);
				Context.setAttribute('fbook.cover.barcode.offset',appConf.fbcover_bar_offset);

				//set tech params
				Context.setAttribute('tech.add',appConf.tech_add);
				Context.setAttribute('tech.barcode.size',appConf.tech_bar);
				Context.setAttribute('tech.barcode.step',appConf.tech_bar_step);
				Context.setAttribute('tech.barcode.color',appConf.tech_bar_color);
				Context.setAttribute('tech.barcode.offset',appConf.tech_bar_offset);
			}else{
				//set to defaults
				
				Context.setAttribute('syncInterval',10);

				//set fbook params
				//block
				Context.setAttribute('fbook.block.font.size',0);
				Context.setAttribute('fbook.block.notching',0);
				Context.setAttribute('fbook.block.barcode.size',0);
				Context.setAttribute('fbook.block.barcode.offset','+0+0');
				//cover
				Context.setAttribute('fbook.cover.font.size',0);
				Context.setAttribute('fbook.cover.notching',0);
				Context.setAttribute('fbook.cover.barcode.size',0);
				Context.setAttribute('fbook.cover.barcode.offset','+0+0');
				
				//set tech params
				Context.setAttribute('tech.add',0);
				Context.setAttribute('fbook.tech.barcode.size',0);
				Context.setAttribute('fbook.tech.barcode.offset','+0+0');

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
		public static function initSourceLists():Boolean{
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
			setSources(soArr);
			return true;
		}
		
		public static function initAttributeLists():void{
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
			/*
			if(!Context.getAttribute('pdfList')){
				a=dDao.getPDFValueList();
				Context.setAttribute('pdfList', a);
			}
			*/
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

			/*
			//week days
			if(!Context.getAttribute('day_idList')){
				a=dDao.getSrcTypeValueList(Source.LOCATION_TYPE_TECH_POINT);
				Context.setAttribute('day_idList', a);
				a=dDao.getSrcTypeValueList(Source.LOCATION_TYPE_TECH_POINT,false);
				Context.setAttribute('day_idValueList', a);
			}
			*/

			//tech_points
			if(!Context.getAttribute('tech_pointList')){
				a=dDao.getTechPointValueList();
				Context.setAttribute('tech_pointList', a);
				/*
				a=dDao.getTechPointValueList(false);
				Context.setAttribute('tech_pointValueList', a);
				*/
			}

			//tech layers
			if(!Context.getAttribute('layerList')){
				a=dDao.getTechLayerValueList();
				//Context.setAttribute('layerList', a);
				Context.setAttribute('layerValueList', a);
				/*
				a=dDao.getTechPointValueList(false);
				Context.setAttribute('tech_pointValueList', a);
				*/
			}

			//tech seq layers
			if(!Context.getAttribute('seqlayerList')){
				a=dDao.getTechLayerValueList(false);
				//Context.setAttribute('seqlayerList', a);
				Context.setAttribute('seqlayerValueList', a);
			}

			//tech layer group
			if(!Context.getAttribute('layer_groupList')){
				a=dDao.getLayerGroupValueList();
				Context.setAttribute('layer_groupList', a);
				Context.setAttribute('layer_groupValueList', a);
				/*
				a=dDao.getTechPointValueList(false);
				Context.setAttribute('tech_pointValueList', a);
				*/
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

	}
}