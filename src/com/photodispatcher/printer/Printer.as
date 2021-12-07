package com.photodispatcher.printer{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.model.mysql.DbLatch;
	import com.photodispatcher.model.mysql.entities.DeliveryType;
	import com.photodispatcher.model.mysql.entities.DeliveryTypePrintForm;
	import com.photodispatcher.model.mysql.entities.MailPackage;
	import com.photodispatcher.model.mysql.entities.MailPackageBarcode;
	import com.photodispatcher.model.mysql.entities.MailPackageProperty;
	import com.photodispatcher.model.mysql.entities.OrderState;
	import com.photodispatcher.model.mysql.entities.PrintForm;
	import com.photodispatcher.model.mysql.entities.PrintFormField;
	import com.photodispatcher.model.mysql.entities.PrintFormParametr;
	import com.photodispatcher.model.mysql.entities.PrintGroup;
	import com.photodispatcher.model.mysql.entities.StateLog;
	import com.photodispatcher.model.mysql.entities.report.Parameter;
	import com.photodispatcher.model.mysql.entities.report.Report;
	import com.photodispatcher.model.mysql.entities.report.ReportResult;
	import com.photodispatcher.model.mysql.services.XReportService;
	import com.photodispatcher.shell.OORuner;
	import com.photodispatcher.util.Code128;
	import com.photodispatcher.util.StrUtil;
	import com.xreport.common.ReportLoader;
	import com.xreport.common.ReportViewer;
	
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.globalization.DateTimeStyle;
	
	import mx.controls.Alert;
	
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
		private var reportViewer:ReportViewer;
		private var reportLoader:ReportLoader;
		private var curReport:Report; 

		public function Printer(){
			super(null);
			if(_instance != null){
				throw new Error('Printer singleton exception');
			}
			queue=[];
			reportService=Tide.getInstance().getContext().byType(XReportService,true) as XReportService;
			reportPrinter=new OORuner();
			reportPrinter.transport = OORuner.TRANSPORT_FILESYSTEM;
			//listen
			reportPrinter.addEventListener(ErrorEvent.ERROR, onPrintErr);
			reportPrinter.addEventListener(Event.COMPLETE, onPrintComplite);
			reportViewer= new ReportViewer();
			reportViewer.silent=true;
			reportViewer.addEventListener(Event.COMPLETE, onPrintComplite);
			
			reportLoader= new ReportLoader();
			reportLoader.silent=true;
			reportLoader.addEventListener(Event.COMPLETE, onLoadComplite);
		}
		
		public function silent(value:Boolean):void{
			reportViewer.silent=value;
			reportLoader.silent=value;
		}
		
		public function print(report:Report):void{
			if(!report) return;
			queue.push(report);
			printNext();
		}
		
		private function releaseErr(err:String):void{
			if(curReport && curReport.logOn){
				if(curReport.logPrintGroupId){
					StateLog.logByPGroup(OrderState.PRN_POST,curReport.logPrintGroupId,'Форма: '+curReport.name+'. Ошибка печати: '+err);
				}else if(curReport.logOrderId){
					StateLog.log(OrderState.PRN_POST,curReport.logOrderId,'','Форма: '+curReport.name+'. Ошибка печати: '+err);
				}
			}
			dispatchEvent(new ErrorEvent(ErrorEvent.ERROR,false,false,'Ошибка печати: '+err));
		}
		
		private function printNext():void{
			if(curReport) return;
			while(!curReport && queue.length>0) curReport=queue.shift() as Report;
			if(!curReport) return;

			if(!curReport.result){
				reportService.buildReport(curReport, DATA_SOURCE, onBuildReport, onBuildReportFault);
				return;
			}
			
			onReportResult()
		}
		private function onBuildReport(event:TideResultEvent):void{
			//var result:ReportResult=event.result as ReportResult;
			curReport.result = event.result as ReportResult;
			onReportResult()
		}
		private function onReportResult():void{
			if (!curReport.result) return; //alert?
			if(curReport.result.hasError){
				releaseErr(curReport.result.error);
				if(curReport && curReport.logOn){
					if(curReport.logPrintGroupId){
						StateLog.logByPGroup(OrderState.PRN_POST,curReport.logPrintGroupId,'Форма: '+curReport.name+'. Ошибка печати: '+curReport.result.error);
					}else if(curReport.logOrderId){
						StateLog.log(OrderState.PRN_POST,curReport.logOrderId,'','Форма: '+curReport.name+'. Ошибка печати: '+curReport.result.error);
					}
				}
				curReport=null;
				printNext();
				return;
			}
			if(curReport.result.url){
				if(reportPrinter && reportPrinter.enabled){
					//load report
					reportLoader.load(curReport, curReport.result.releaseReport);
				}else{
					if(curReport.logOn){
						if(curReport.logPrintGroupId){
							StateLog.logByPGroup(OrderState.PRN_POST,curReport.logPrintGroupId,'Форма: '+curReport.name+'. Не напечатана, принтер не доступен');
						}else if(curReport.logOrderId){
							StateLog.log(OrderState.PRN_POST,curReport.logOrderId,'','Форма: '+curReport.name+'.  Не напечатана, принтер не доступен');
						}
					}
					reportViewer.open(curReport,false);
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

		private function onLoadComplite(event:Event):void{
			if(!reportLoader || !reportLoader.resultFile) {
				curReport=null;
				return;
			}
			var prn:String=curReport.printer;
			if(!prn) prn=Context.getAttribute('printer');
			var prnStr:String=prn;
			if(!prnStr) prnStr='default';
			if(curReport.logOn){
				if(curReport.logPrintGroupId){
					StateLog.logByPGroup(OrderState.PRN_POST,curReport.logPrintGroupId,curReport.name+' отправлен на принтер '+prnStr);
				}else if(curReport.logOrderId){
					StateLog.log(OrderState.PRN_POST,curReport.logOrderId,'',curReport.name+' отправлен на принтер '+prnStr);
				}
			}
			reportPrinter.print(reportLoader.resultFile.nativePath, prn);
			curReport=null;
			printNext();
		}
		
		private function onPrintComplite(event:Event):void{
			if(curReport && curReport.result){
				var latch:DbLatch= new DbLatch();
				latch.addLatch(reportService.releaseReport(curReport.result));
				latch.start();
			}
			if(curReport && curReport.logOn){
				if(curReport.logPrintGroupId){
					StateLog.logByPGroup(OrderState.PRN_POST,curReport.logPrintGroupId,'Форма: '+curReport.name+' напечатана');
				}else if(curReport.logOrderId){
					StateLog.log(OrderState.PRN_POST,curReport.logOrderId,'','Форма: '+curReport.name+' напечатана');
				}
			}
			curReport=null;
			printNext();
		}

		/*form printing -------------------------------------------------------------------*/

		public function printOrderTicket(pg:PrintGroup):void{
			if(!pg) return;
			var report:Report=new Report();
			
			report.id='OrderTicketFrm';
			report.name='Квиток';

			report.logOn=true;
			report.logPrintGroupId=pg.id;
			
			report.parameters=[];
			var param:Parameter;
			param=new Parameter(); param.id='pgid'; param.valString=pg.id; report.parameters.push(param);
			param=new Parameter(); param.id='pbarcode'; param.valString=Code128.codeIt(pg.orderBarcode()); report.parameters.push(param);
			param=new Parameter(); param.id='pbarcodebest'; param.valString=Code128.codeIt(pg.orderBarcodeBest()); report.parameters.push(param);
			print(report);
		}

		//public function printDeliveryForm(packege:MailPackage, form:DeliveryTypePrintForm, barcode:String='', providerId:String=''):void{
		public function printDeliveryForm(packege:MailPackage, form:DeliveryTypePrintForm, barcode:MailPackageBarcode):void{
			if(!packege || !form) return;
			var s:String;
			switch(form.report){
				case 'mpBarcodeFrm':
					if(packege.state<OrderState.PACKAGE_PACKED){
						s=OrderState.getStateName(OrderState.PACKAGE_PACKED);
						Alert.show('Печать ШК разрешена в статусе не ниже '+s);
					}else{
						printMPBarcode(packege.id_name, barcode);
					}
					break;
				case 'mpBarcodeFrm2':
					printMPBarcode2(barcode);
					break;
				case 'evropochta':
					printEvropochta(barcode);
					break;
				default:
					var report:Report=prepareFormReport(packege,form);
					if(report) print(report);
					break;
			}
		}
		
		protected function printMPBarcode(idCaption:String, barcode:MailPackageBarcode):void{
			if(!idCaption || !barcode) return;
			
			var report:Report=new Report();
			report.printer=	Context.getAttribute('termPrinter');
			
			report.id='mpBarcodeFrm';
			report.parameters=[];
			var param:Parameter;
			param=new Parameter(); param.id='pgroup_hm'; param.valString=idCaption; report.parameters.push(param);
			param=new Parameter(); param.id='pprovider_id'; param.valString=(barcode.preorder_num?('K'+barcode.preorder_num):''); report.parameters.push(param);
			param=new Parameter(); param.id='pbarcode'; param.valString=Code128.codeIt(barcode.barcode); report.parameters.push(param);
			param=new Parameter(); param.id='pbarcode_hm'; param.valString=barcode.barcode; report.parameters.push(param);
			print(report);
		}
		
		protected function printMPBarcode2(barcode:MailPackageBarcode):void{
			if(!barcode) return;

			var report:Report=new Report();
			report.printer=	Context.getAttribute('termPrinter');
			
			report.id='mpBarcodeFrm2';
			report.parameters=[];
			var param:Parameter;
			
			param=new Parameter(); param.id='pgroup_hm'; param.valString=''; report.parameters.push(param);
			param=new Parameter(); param.id='pprovider_id'; param.valString=barcode.box_orderNumber; report.parameters.push(param);
			param=new Parameter(); param.id='pbarcode'; param.valString=Code128.codeIt(barcode.box_orderNumber); report.parameters.push(param);
			//param=new Parameter(); param.id='pbarcode'; param.valString=Code128.codeIt(barcode.barcode); report.parameters.push(param);
			//param=new Parameter(); param.id='pbarcode_hm'; param.valString=barcode.barcode; report.parameters.push(param);
			param=new Parameter(); param.id='pbarcode_hm'; param.valString=''; report.parameters.push(param);
			print(report);
		}

		protected function printEvropochta(barcode:MailPackageBarcode):void{
			if(!barcode){ 
				Alert.show('Не задан Штрихкод');
				curReport=null;
				printNext();
				return;
			}
			
			var report:Report=new Report();
			report.printer=	Context.getAttribute('termPrinter');
			
			report.id='evropochta';
			report.parameters=[];
			report.fileExt='.pdf';
			var param:Parameter;
			param=new Parameter(); param.id='pbarcode'; param.valString=barcode.barcode; report.parameters.push(param);
			
			var result:ReportResult = new ReportResult();
			result.hasError=false;
			result.url=barcode.barcode;
 //			4 debug result.url='BY080008021664';
			
			result.releaseReport=false;
			var baseURL:String=Context.getAttribute('evropostHost');
			if (!baseURL){
				Alert.show('Не задан адрес сервиса Европочты');
				curReport=null;
				printNext();
				return;
			}
			if(baseURL.charAt(baseURL.length-1)!='/' ) baseURL+='/';
			baseURL = baseURL +"api/sticker/";
			result.baseURL =baseURL;
			report.result=result;
			
			print(report);
		}

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
			
			var deliverySubType:String;
			
			if(packege.delivery_id==DeliveryType.TYPE_AT){
				deliverySubType=packege.getProperty(MailPackageProperty.PROP_AT_DELIVERY_TYPE);
			}
			
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
							case PrintFormField.FIELD_AT_TO_DOOR:
								param=new Parameter(); 
								param.id=frmParam.parametr; 
								param.valString=''; 
								if(packege.delivery_id==DeliveryType.TYPE_AT && deliverySubType==MailPackageProperty.VAL_AT_DELIVERY_TYPE_COURIER){
									param.valString='До двери';
								}
								report.parameters.push(param);
								break;
						}
					}else{
						//property
						param=new Parameter(); 
						param.id=frmParam.parametr;
						
						if(frmParam.form_field==PrintFormField.FIELD_FULL_ADR && 
							packege.delivery_id==DeliveryType.TYPE_AT && deliverySubType!=MailPackageProperty.VAL_AT_DELIVERY_TYPE_COURIER){
							param.valString='';
							
						}else{
							param.valString=PrintFormField.buildField(frmParam.form_field,props);
						}
						report.parameters.push(param);
					}
				}
			}
			
			return report;
		}

	}
}