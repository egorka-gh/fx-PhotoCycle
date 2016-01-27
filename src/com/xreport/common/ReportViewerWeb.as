package com.xreport.common{
	import com.photodispatcher.model.mysql.entities.report.Report;
	
	import flash.net.URLRequest;
	import flash.net.navigateToURL;

	public class ReportViewerWeb implements IReportViewer{

		public function open(report:Report, releaseReport:Boolean=true):void{
			if(report && report.result && report.result.url){
				var urlRequest:URLRequest = new URLRequest(report.result.url);
				navigateToURL(urlRequest,'_new');
			}
		}
	}
}