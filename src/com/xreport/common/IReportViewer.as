package com.xreport.common{
	import com.photodispatcher.model.mysql.entities.report.Report;

	public interface IReportViewer{
		function open(report:Report, releaseReport:Boolean=true):void;
	}
}