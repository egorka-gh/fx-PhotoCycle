package com.xreport.common{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.model.mysql.DbLatch;
	import com.photodispatcher.model.mysql.entities.report.Report;
	import com.photodispatcher.model.mysql.services.XReportService;
	import com.photodispatcher.util.RemoteFileLoader;
	
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.filesystem.File;
	
	import mx.controls.Alert;
	
	import org.granite.tide.Tide;

	[Event(name="complete", type="flash.events.Event")]
	public class ReportLoader extends EventDispatcher {
		
		public var report:Report;
		public var silent:Boolean;
		public var resultFile:File;
		
		private var releaseReport:Boolean;
		
		public function ReportLoader(){
			super(null);
		}
		
		private var _loader:RemoteFileLoader;
		public function get loader():RemoteFileLoader{
			return _loader;
		}
		public function set loader(value:RemoteFileLoader):void{
			if(_loader){
				//stop listen
				_loader.removeEventListener(Event.COMPLETE,onComplite);
				_loader.removeEventListener(ErrorEvent.ERROR,onError);
				_loader.destroy();
			}
			_loader = value;
			if(_loader){
				//start listen
				_loader.addEventListener(Event.COMPLETE,onComplite);
				_loader.addEventListener(ErrorEvent.ERROR,onError);
			}
		}

		public function load(report:Report, releaseReport:Boolean=true):void{
			resultFile=null;
			this.report=report;
			this.releaseReport=releaseReport;
			if(!report || !report.result || !report.result.url) return;

			var fileExt:String=report.fileExt;
			if (!fileExt){
				fileExt='.xls';
			} 
			
			var baseURL:String=report.result.baseURL;
			if (!baseURL){
				baseURL=Context.getServerRootUrl();
			}
			
			loader= new RemoteFileLoader(report.result.url, report.id+fileExt, baseURL);
			loader.load();
		}
		
		private function onComplite(evt : Event):void{
			if(loader && loader.targetFile){
				resultFile=loader.targetFile;
			}
			if(report && releaseReport){
				var reportService:XReportService=Tide.getInstance().getContext().byType(XReportService,true) as XReportService;
				var latch:DbLatch=new DbLatch();
				latch.addLatch(reportService.releaseReport(report.result));
				latch.start();
			}
			report=null;
			loader=null;
			dispatchEvent(new Event(Event.COMPLETE));
		}

		private function onError(evt : ErrorEvent):void{
			if(!silent) Alert.show(evt.text);
			dispatchEvent(new Event(Event.COMPLETE));
		}
	}
}