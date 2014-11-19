package com.xreport.common{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.model.mysql.entities.report.Report;
	import com.photodispatcher.util.RemoteFileLoader;
	
	import flash.events.ErrorEvent;
	import flash.events.Event;
	
	import mx.controls.Alert;
	
	public class ReportViewer implements IReportViewer{
		
		public var url:String;
		public var report:Report;
		
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

		public function open(url:String, report:Report):void{
			this.url=url;
			this.report=report;
			if(!url || !report) return;
			loader= new RemoteFileLoader(url,report.id+'.xls',Context.getServerRootUrl());
			loader.load();
		}
		
		private function onComplite(evt : Event):void{
			if(loader && loader.targetFile){
				loader.targetFile.openWithDefaultApplication();
			}
			url=null;
			report=null;
			loader=null;
		}

		private function onError(evt : ErrorEvent):void{
			Alert.show(evt.text);
		}
	}
}