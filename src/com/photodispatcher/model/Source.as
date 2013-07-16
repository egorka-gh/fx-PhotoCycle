package com.photodispatcher.model{
	import com.akmeful.fotokniga.book.data.Book;
	import com.photodispatcher.context.Context;
	import com.photodispatcher.model.dao.SourceServiceDAO;
	import com.photodispatcher.util.StrUtil;
	
	import flash.filesystem.File;
	
	public class Source extends DBRecord{
		public static const LOCATION_TYPE_SOURCE:int=1;
		public static const LOCATION_TYPE_LAB:int=2;
		public static const LOCATION_TYPE_TECH_POINT:int=3;

		[Bindable]
		public var syncState:ProcessState= new ProcessState();
		[Bindable]
		public var ftpState:ProcessState= new ProcessState();
		
		//database props
		[Bindable]
		public var id:int;
		[Bindable]
		public var name:String;
		[Bindable]
		public var type_id:int;
		[Bindable]
		public var sync:int=0;
		[Bindable]
		public var loc_type:int;
		[Bindable]
		public var online:Boolean = false;
		[Bindable]
		public var code:String='';

		//drived
		[Bindable]
		public var type_name:String;
		[Bindable]
		public var type_id_name:String;//TODO refactor, same as type_name used 4 grid editor   
		
		//runtime, 4 Laboratory config
		[Bindable]
		public var isSelected:Boolean;

		// Lazy loading Services
		private var srvcloaded:Boolean = false;
		public function loadServices():Boolean{
			if(srvcloaded) return true;
			var svc:SourceServiceDAO= new SourceServiceDAO();
			var asvc:Array=svc.getBySource(id);
			if(asvc){
				for each(var o:* in asvc){
					var s:SourceService=o as SourceService;
					switch (s.srvc_id){
						case SourceService.FTP_SERVICE:
							_ftpService=s;
							break;
						case SourceService.WEB_SERVICE:
							_webService=s;
							break;
						case SourceService.FBOOK_SERVICE:
							_fbookService=s;
							break;
						case SourceService.HOT_FOLDER:
							_hotFolder=s;
							break;
					}
				}
			}else{
				return false;
			}
			if(loaded){
				if (!_ftpService){
					_ftpService=new SourceService();
					_ftpService.loc_type=this.loc_type;
					_ftpService.src_id=this.id; _ftpService.srvc_id=SourceService.FTP_SERVICE;
				}
				if (!_webService){
					_webService=new SourceService();
					_webService.loc_type=this.loc_type;
					_webService.src_id=this.id; _webService.srvc_id=SourceService.WEB_SERVICE;
				}
				if (!_fbookService){
					_fbookService=new SourceService();
					_fbookService.loc_type=this.loc_type;
					_fbookService.src_id=this.id; 
					_fbookService.srvc_id=SourceService.FBOOK_SERVICE;
				}
				if (!_hotFolder){
					_hotFolder=new SourceService();
					_hotFolder.loc_type=this.loc_type;
					_hotFolder.src_id=this.id; _hotFolder.srvc_id=SourceService.HOT_FOLDER;
				}
			}
			srvcloaded=true;
			return true;
		}
		
		protected var _ftpService:SourceService;
		public function get ftpService():SourceService{
			loadServices();
			return _ftpService;
		}

		protected var _webService:SourceService;
		public function get webService():SourceService{
			loadServices();
			return _webService;
		}

		protected var _fbookService:SourceService;
		public function get fbookService():SourceService{
			loadServices();
			return _fbookService;
		}
		public function get hasFbookService():Boolean{
			return (_fbookService && _fbookService.url && _fbookService.connections>0);
		}

		protected var _hotFolder:SourceService;
		public function get hotFolder():SourceService{
			loadServices();
			return _hotFolder;
		}

		public function incrementSync():int{
			if(sync == int.MAX_VALUE) sync=0;
			sync++;
			return sync; 
		}

		public function getWrkFolder():String{
			var wrkFolder:String=Context.getAttribute('workFolder');
			wrkFolder=wrkFolder+File.separator+StrUtil.toFileName(this.name);
			//fl=fl.resolvePath(StrUtil.toFileName(src.name)+File.separator+currentOrder.ftp_folder);
			return wrkFolder;
		}
		public function getPrtFolder():String{
			var wrkFolder:String=Context.getAttribute('prtPath');
			wrkFolder=wrkFolder+File.separator+StrUtil.toFileName(this.name);
			//fl=fl.resolvePath(StrUtil.toFileName(src.name)+File.separator+currentOrder.ftp_folder);
			return wrkFolder;
		}

	}
}