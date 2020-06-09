/**
 * Generated by Gas3 v2.3.2 (Granite Data Services).
 *
 * NOTE: this file is only generated if it does not exist. You may safely put
 * your custom code here.
 */

package com.photodispatcher.model.mysql.entities {
	import com.photodispatcher.context.Context;
	import com.photodispatcher.model.ProcessState;
	import com.photodispatcher.util.StrUtil;
	
	import flash.filesystem.File;
	
	import mx.collections.ArrayList;
	
	import spark.components.gridClasses.GridColumn;

    [Bindable]
    [RemoteClass(alias="com.photodispatcher.model.mysql.entities.Source")]
    public class Source extends SourceBase {
		public static const LOCATION_TYPE_SOURCE:int=1;
		public static const LOCATION_TYPE_LAB:int=2;
		public static const LOCATION_TYPE_TECH_POINT:int=3;
		
		public static function gridColumns(labColumns:Boolean=false):ArrayList{
			var result:ArrayList= new ArrayList();
			
			var col:GridColumn= new GridColumn('id'); col.headerText='ID'; result.addItem(col);
			col= new GridColumn('name'); col.headerText='Наименование'; result.addItem(col); 
			col= new GridColumn('type_name'); col.headerText='Тип'; result.addItem(col); 
			col= new GridColumn('online'); col.headerText='Online'; result.addItem(col); 
			if(!labColumns){
				col= new GridColumn('code'); col.headerText='Код'; result.addItem(col); 
			}
			return result;
		}

		
		public function edit():void{
			var ss:SourceSvc;
			if(!loaded) return;
			if (!ftpService){
				ss=new SourceSvc();
				ss.loc_type=this.loc_type;
				ss.src_id=this.id; 
				ss.srvc_id=SourceSvc.FTP_SERVICE;
				ftpService=ss;
			}
			if (!webService){
				ss=new SourceSvc();
				ss.loc_type=this.loc_type;
				ss.src_id=this.id; 
				ss.srvc_id=SourceSvc.WEB_SERVICE;
				webService=ss;
			}
			if (!fbookService){
				ss=new SourceSvc();
				ss.loc_type=this.loc_type;
				ss.src_id=this.id; 
				ss.srvc_id=SourceSvc.FBOOK_SERVICE;
				fbookService=ss;
			}	
			if (!hotFolder){
				ss=new SourceSvc();
				ss.loc_type=this.loc_type;
				ss.src_id=this.id; 
				ss.srvc_id=SourceSvc.HOT_FOLDER;
				hotFolder=ss;
			}
		}
		
		public function get hasFbookService():Boolean{
			return (fbookService && fbookService.url && fbookService.connections>0);
		}
		
		/*
		public function incrementSync():int{
			if(sync == int.MAX_VALUE) sync=0;
			sync++;
			return sync; 
		}
		*/
		public var syncState:ProcessState= new ProcessState();
		public var ftpState:ProcessState= new ProcessState();
		
		//runtime, 4 Laboratory config
		public var isSelected:Boolean;
		
		//runtime
		public var fbookSid:String;

		public function getWrkFolder():String{
			var wrkFolder:String=Context.getAttribute('workFolder');
			wrkFolder=wrkFolder+File.separator+StrUtil.toFileName(this.name);
			return wrkFolder;
		}
		public function getPrtFolder():String{
			var wrkFolder:String=Context.getAttribute('prtPath');
			wrkFolder=wrkFolder+File.separator+StrUtil.toFileName(this.name);
			return wrkFolder;
		}

    }
}