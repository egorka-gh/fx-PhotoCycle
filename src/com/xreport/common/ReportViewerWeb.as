package com.xreport.common{
	import com.photodispatcher.model.mysql.entities.report.Report;
	
	import flash.net.URLRequest;
	import flash.net.navigateToURL;

	public class ReportViewerWeb implements IReportViewer{

		public function open(url:String, report:Report):void{
			if(url){
				var urlRequest:URLRequest = new URLRequest(url);
				navigateToURL(urlRequest,'_new');
			}
		}
	}
}