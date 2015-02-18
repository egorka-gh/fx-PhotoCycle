package com.photodispatcher.printer{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.model.mysql.entities.PrintGroup;
	import com.photodispatcher.model.mysql.entities.report.Parameter;
	import com.photodispatcher.model.mysql.entities.report.Report;
	import com.photodispatcher.model.mysql.entities.report.ReportResult;
	import com.photodispatcher.model.mysql.services.XReportService;
	import com.photodispatcher.shell.OORuner;
	import com.photodispatcher.util.Code128;
	import com.xreport.common.ReportViewer;
	
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	
	import org.granite.tide.Tide;
	import org.granite.tide.events.TideFaultEvent;
	import org.granite.tide.events.TideResultEvent;
	
	[Event(name="error", type="flash.events.ErrorEvent")]
	[Event(name="complete", type="flash.events.Event")]
	public class Printer extends EventDispatcher{
		private static const DATA_SOURCE:String='dataSource';
		
		private static var _instance:Printer;
		public static function get instance():Printer{
			if(_instance == null) _instance=new Printer();
			return _instance;
		}
		
		private var queue:Array;
		private var reportService:XReportService;
		private var reportPrinter:OORuner;
		private var reportViewer:ReportViewer
		private var curReport:Report; 

		public function Printer(){
			super(null);
			if(_instance != null){
				throw new Error('Printer singleton exception');
			}
			queue=[];
			reportService=Tide.getInstance().getContext().byType(XReportService,true) as XReportService;
			reportPrinter=new OORuner();
			//listen
			reportPrinter.addEventListener(ErrorEvent.ERROR, onPrintErr);
			reportPrinter.addEventListener(Event.COMPLETE, onPrintComplite);
			reportViewer= new ReportViewer();
			reportViewer.silent=true;
			reportViewer.addEventListener(Event.COMPLETE, onPrintComplite);
		}
		
		public function print(report:Report):void{
			if(!report) return;
			queue.push(report);
			printNext();
		}
		
		private function releaseErr(err:String):void{
			dispatchEvent(new ErrorEvent(ErrorEvent.ERROR,false,false,'Ошибка печати: '+err));
		}
		
		private function printNext():void{
			if(curReport) return;
			while(!curReport && queue.length>0) curReport=queue.shift() as Report;
			if(!curReport) return;
			reportService.buildReport(curReport, DATA_SOURCE, onBuildReport, onBuildReportFault);
		}
		private function onBuildReport(event:TideResultEvent):void{
			var result:ReportResult=event.result as ReportResult;
			if (!result) return; //alert?
			if(result.hasError){
				releaseErr(result.error);
				curReport=null;
				printNext();
			}
			if(result.url){
				if(reportPrinter && reportPrinter.enabled){
					var prn:String=curReport.printer;
					if(!prn) prn=Context.getAttribute('printer');
					reportPrinter.print(result.url, prn);
				}else{
					reportViewer.open(result.url,curReport);
				}
			}
		}
		private function onBuildReportFault(event:TideFaultEvent):void{
			releaseErr(event.fault.faultString);
			curReport=null;
			printNext();
		}

		private function onPrintErr(event:ErrorEvent):void{
			releaseErr(event.text);
			curReport=null;
			printNext();
		}

		private function onPrintComplite(event:Event):void{
			curReport=null;
			printNext();
		}

		/*form printing -------------------------------------------------------------------*/

		public function printOrderTicket(pg:PrintGroup):void{
			if(!pg) return;
			var report:Report=new Report();
			
			report.id='OrderTicketFrm';
			report.parameters=[];
			var param:Parameter;
			param=new Parameter(); param.id='pgid'; param.valString=pg.id; report.parameters.push(param);
			param=new Parameter(); param.id='pbarcode'; param.valString=Code128.codeIt(pg.orderBarcode()); report.parameters.push(param);
			param=new Parameter(); param.id='pbarcodebest'; param.valString=Code128.codeIt(pg.orderBarcodeBest()); report.parameters.push(param);
			print(report);
		}

		public function printMPBarcode(idCaption:String, barcode:String):void{
			if(!idCaption || !barcode) return;
			
			var report:Report=new Report();
			report.printer=	Context.getAttribute('termPrinter');

			report.id='mpBarcodeFrm';
			report.parameters=[];
			var param:Parameter;
			param=new Parameter(); param.id='pgroup_hm'; param.valString=idCaption; report.parameters.push(param);
			param=new Parameter(); param.id='pbarcode'; param.valString=Code128.codeIt(barcode); report.parameters.push(param);
			param=new Parameter(); param.id='pbarcode_hm'; param.valString=barcode; report.parameters.push(param);
			print(report);
		}

	}
}