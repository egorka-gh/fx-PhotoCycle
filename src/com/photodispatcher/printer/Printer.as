package com.photodispatcher.printer{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.model.mysql.entities.DeliveryTypePrintForm;
	import com.photodispatcher.model.mysql.entities.MailPackage;
	import com.photodispatcher.model.mysql.entities.PrintForm;
	import com.photodispatcher.model.mysql.entities.PrintFormField;
	import com.photodispatcher.model.mysql.entities.PrintFormParametr;
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
	import flash.globalization.DateTimeStyle;
	
	import org.granite.tide.Tide;
	import org.granite.tide.events.TideFaultEvent;
	import org.granite.tide.events.TideResultEvent;
	
	import spark.formatters.DateTimeFormatter;
	
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

		public function printDeliveryForm(packege:MailPackage, form:DeliveryTypePrintForm, barcode:String=''):void{
			if(!packege || !form) return;
			switch(form.report){
				case 'mpBarcodeFrm':
					printMPBarcode(packege.id_name, barcode);
					break;
				/*
				case 'frmATzaiava':
					printATzaiava(packege);
					break;
				*/
				default:
					var report:Report=prepareFormReport(packege,form);
					if(report) print(report);
					break;
			}
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
/*
		private function printATzaiava(packege:MailPackage):void{
			if(!packege || !packege.properties) return;
			var props:Array=packege.properties.toArray();
			if(!props || props.length==0) return;
			
			var report:Report=new Report();
			report.id='frmATzaiava';
			report.parameters=[];
			var param:Parameter;
			param=new Parameter(); param.id='pcity'; param.valString=PrintFormField.buildField(PrintFormField.FIELD_CITY,props); report.parameters.push(param);
			param=new Parameter(); param.id='pfio'; param.valString=PrintFormField.buildField(PrintFormField.FIELD_FIO,props); report.parameters.push(param);
			param=new Parameter(); param.id='ppass_num'; param.valString=PrintFormField.buildField(PrintFormField.FIELD_PASS_NUM,props); report.parameters.push(param);
			param=new Parameter(); param.id='ppass_info'; param.valString=PrintFormField.buildField(PrintFormField.FIELD_PASS_INFO,props); report.parameters.push(param);
			param=new Parameter(); param.id='pphone'; param.valString=PrintFormField.buildField(PrintFormField.FIELD_PHONE,props);; report.parameters.push(param);
			print(report);
		}
		*/
		
		private function prepareFormReport(packege:MailPackage, form:DeliveryTypePrintForm):Report{
			if(!packege || !packege.properties || !form) return null;
			
			var props:Array=packege.properties.toArray();
			if(!props || props.length==0) return null;
			var params:Array=PrintForm.getFormParameters(form.form);
			if(!params) return null;
			
			var report:Report=new Report();
			report.id=form.report;
			report.parameters=[];
			var frmParam:PrintFormParametr;
			var param:Parameter;
			
			for each(frmParam in params){
				if(frmParam && frmParam.parametr){
					if(frmParam.simplex){
						//packege field
						switch(frmParam.form_field){
							case PrintFormField.FIELD_CLIENT_ID:
								param=new Parameter(); 
								param.id=frmParam.parametr; 
								param.valString=packege.client_id.toString(); 
								report.parameters.push(param);
								break;
							case PrintFormField.FIELD_DELIVERY_NAME:
								param=new Parameter(); 
								param.id=frmParam.parametr; 
								param.valString=packege.delivery_name; 
								report.parameters.push(param);
								break;
							case PrintFormField.FIELD_EXECUTION_DATE:
								param=new Parameter(); 
								param.id=frmParam.parametr;
								var fmt:DateTimeFormatter=new DateTimeFormatter(); fmt.dateStyle=fmt.timeStyle=DateTimeStyle.SHORT; 
								param.valString=fmt.format(packege.execution_date); 
								report.parameters.push(param);
								break;
							case PrintFormField.FIELD_ID:
								param=new Parameter(); 
								param.id=frmParam.parametr; 
								param.valString=packege.id.toString(); 
								report.parameters.push(param);
								break;
							case PrintFormField.FIELD_ID_NAME:
								param=new Parameter(); 
								param.id=frmParam.parametr; 
								param.valString=packege.id_name; 
								report.parameters.push(param);
								break;
							case PrintFormField.FIELD_ORDERS_NUM:
								param=new Parameter(); 
								param.id=frmParam.parametr; 
								param.valString=packege.orders_num.toString(); 
								report.parameters.push(param);
								break;
							case PrintFormField.FIELD_SOURCE_CODE:
								param=new Parameter(); 
								param.id=frmParam.parametr; 
								param.valString=packege.source_code; 
								report.parameters.push(param);
								break;
							case PrintFormField.FIELD_SOURCE_NAME:
								param=new Parameter(); 
								param.id=frmParam.parametr; 
								param.valString=packege.source_name; 
								report.parameters.push(param);
								break;
						}
					}else{
						//property
						param=new Parameter(); 
						param.id=frmParam.parametr; 
						param.valString=PrintFormField.buildField(frmParam.form_field,props); 
						report.parameters.push(param);
					}
				}
			}
			
			return report;
		}

	}
}