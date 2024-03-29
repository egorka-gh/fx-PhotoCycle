/**
 * Generated by Gas3 v2.3.2 (Granite Data Services).
 *
 * NOTE: this file is only generated if it does not exist. You may safely put
 * your custom code here.
 */

package com.photodispatcher.model.mysql.entities {
	import com.photodispatcher.context.Context;
	import com.photodispatcher.print.LabGeneric;
	import com.photodispatcher.print.PreparePrint;
	import com.photodispatcher.util.GridUtil;
	import com.photodispatcher.util.StrUtil;
	
	import flash.filesystem.File;
	import flash.globalization.DateTimeStyle;
	
	import mx.collections.ArrayCollection;
	import mx.collections.ArrayList;
	import mx.collections.IList;
	
	import org.granite.reflect.Field;
	import org.granite.reflect.Type;
	
	import spark.components.gridClasses.GridColumn;
	import spark.formatters.DateTimeFormatter;
	import spark.formatters.NumberFormatter;

    [Bindable]
    [RemoteClass(alias="com.photodispatcher.model.mysql.entities.PrintGroup")]
    public class PrintGroup extends PrintGroupBase {
		public static const PDF_FILENAME_COVERS:String='oblogka';
		public static const PDF_FILENAME_SHEETS:String='blok';
		public static const SUBFOLDER_PRINT:String='print';

		public static const CHECK_STATUS_NONE:int=0;
		public static const CHECK_STATUS_ERR:int=-1;
		public static const CHECK_STATUS_IN_CHECK:int=10;
		public static const CHECK_STATUS_REJECT:int=20;
		public static const CHECK_STATUS_REPRINT:int=30;
		public static const CHECK_STATUS_OK:int=100;

		public static function sourceIdFromId(pgId:String):int{
			var arr:Array;
			if(!pgId) return 0;
			arr=pgId.split('_');
			if(arr && arr.length>0)	return int(arr[0]);
			return 0;
		}
		
		public static function orderIdFromId(pgId:String):String{
			var arr:Array;
			var result:String='';
			if(!pgId) return '';
			
			arr=pgId.split('_');
			if(arr && arr.length>1){
				result=arr[0]+'_'+arr[1];
			}else{
				result=pgId; 
			}
			return result;
		}

		public static function gridColumns(withLab:Boolean=false):ArrayList{
			var a:Array=baseGridColumns();
			var col:GridColumn;
			if(!a) return null;
			if(withLab){
				col= new GridColumn('lab_name'); col.headerText='Лаборатория'; col.width=80;
				a.unshift(col);
			}
			return new ArrayList(a);
		}
		
		private static function baseGridColumns():Array{
			var result:Array= [];
			
			var col:GridColumn= new GridColumn('source_name'); col.headerText='Источник'; col.width=50; result.push(col);
			//col= new GridColumn('order_id'); col.headerText='Id Заказа'; result.addItem(col);
			col= new GridColumn('id'); col.headerText='ID'; col.width=100; result.push(col);
			col= new GridColumn('state_name'); col.headerText='Статус'; col.width=95; result.push(col); 
			var fmt:DateTimeFormatter=new DateTimeFormatter(); fmt.dateStyle=fmt.timeStyle=DateTimeStyle.SHORT; 
			col= new GridColumn('state_date'); col.headerText='Дата статуса'; col.formatter=fmt;  col.width=110; result.push(col);
			col= new GridColumn('alias'); col.headerText='Алиас'; col.width=200; result.push(col);
			col= new GridColumn('compo_type_name'); col.headerText='Комбо'; col.width=70; result.push(col);
			col= new GridColumn('laminat_name'); col.headerText='Ламинат'; col.width=90; result.push(col);
			col= new GridColumn('width'); col.headerText='Ширина'; col.width=50; result.push(col);
			col= new GridColumn('height'); col.headerText='Длина'; col.width=50; result.push(col);
			col= new GridColumn('paper_name'); col.headerText='Бумага'; col.width=100; result.push(col);
			col= new GridColumn('frame_name'); col.headerText='Рамка'; col.width=50; result.push(col);
			col= new GridColumn('correction_name'); col.headerText='Коррекция'; col.width=50; result.push(col);
			col= new GridColumn('cutting_name'); col.headerText='Обрезка'; col.width=50; result.push(col);
			col= new GridColumn('book_type_name'); col.headerText='Тип книги'; col.width=70; result.push(col);
			col= new GridColumn('book_part_name'); col.headerText='Часть книги'; col.width=70; result.push(col);
			col= new GridColumn('is_pdf'); col.headerText='PDF'; col.labelFunction=GridUtil.booleanToLabel; col.width=50; result.push(col);
			col= new GridColumn('book_num'); col.headerText='Кол книг'; col.width=50; result.push(col);
			//col= new GridColumn('cover_name'); col.headerText='Обложка'; result.addItem(col);
			col= new GridColumn('prints'); col.headerText='Кол отпечатков'; col.width=50; result.push(col);
			return result;
		}
		
		public static function shortGridColumns():ArrayList{
			var result:Array= [];
			var col:GridColumn;
			
			col= new GridColumn('id'); col.headerText='ID'; col.width=85; result.push(col);
			col= new GridColumn('state_name'); col.headerText='Статус'; col.width=90; result.push(col); 
			var fmt:DateTimeFormatter=new DateTimeFormatter(); fmt.dateStyle=fmt.timeStyle=DateTimeStyle.SHORT; 
			col= new GridColumn('state_date'); col.headerText='Дата статуса'; col.formatter=fmt;  col.width=110; result.push(col);
			col= new GridColumn('lab_name'); col.headerText='Лаборатория'; col.width=70; result.push(col);
			col= new GridColumn('is_reprint'); col.headerText='Перепечатка'; col.width=70; col.labelFunction=GridUtil.booleanToLabel; result.push(col);
			col= new GridColumn('alias'); col.headerText='Алиас'; col.width=70; result.push(col);
			col= new GridColumn('path'); col.headerText='Папка'; col.width=70; result.push(col);
			col= new GridColumn('laminat_name'); col.headerText='Ламинат'; col.width=90; result.push(col);
			col= new GridColumn('compo_type_name'); col.headerText='Комбо'; col.width=70; result.push(col);
			col= new GridColumn('width'); col.headerText='Ширина'; col.width=70; result.push(col);
			col= new GridColumn('height'); col.headerText='Длина'; col.width=70; result.push(col);
			col= new GridColumn('paper_name'); col.headerText='Бумага'; col.width=70; result.push(col);
			col= new GridColumn('frame_name'); col.headerText='Рамка'; col.width=70; result.push(col);
			col= new GridColumn('correction_name'); col.headerText='Коррекция'; col.width=50; result.push(col);
			col= new GridColumn('cutting_name'); col.headerText='Обрезка'; col.width=50; result.push(col);
			col= new GridColumn('book_type_name'); col.headerText='Тип книги'; col.width=70; result.push(col);
			col= new GridColumn('book_part_name'); col.headerText='Часть книги'; col.width=70; result.push(col);
			col= new GridColumn('is_pdf'); col.headerText='PDF'; col.width=50; col.labelFunction=GridUtil.booleanToLabel; result.push(col);
			col= new GridColumn('book_num'); col.headerText='Кол книг'; col.width=70; result.push(col);
			col= new GridColumn('prints'); col.headerText='Кол отпечатков'; col.width=70; result.push(col);
			return new ArrayList(result);
		}

		public static function printGridColumns():ArrayList{
			var result:Array= [];
			var col:GridColumn;
			
			col= new GridColumn('lab_name'); col.headerText='Лаборатория'; col.width=70; result.push(col);
			col= new GridColumn('id'); col.headerText='ID'; col.width=85; result.push(col);
			col= new GridColumn('state_name'); col.headerText='Статус'; col.width=90; result.push(col); 
			var fmt:DateTimeFormatter=new DateTimeFormatter(); fmt.dateStyle=fmt.timeStyle=DateTimeStyle.SHORT; 
			col= new GridColumn('state_date'); col.headerText='Дата статуса'; col.formatter=fmt;  col.width=110; result.push(col);
			col= new GridColumn('paper_name'); col.headerText='Бумага'; result.push(col);
			col= new GridColumn('laminat_name'); col.headerText='Ламинат'; col.width=90; result.push(col);
			col= new GridColumn('width'); col.headerText='Ширина'; col.width=70; result.push(col);
			col= new GridColumn('height'); col.headerText='Длина'; col.width=70; result.push(col);
			col= new GridColumn('prints'); col.headerText='Кол отпечатков'; col.width=70; result.push(col);
			col= new GridColumn('is_reprint'); col.headerText='Перепечатка'; col.width=70; col.labelFunction=GridUtil.booleanToLabel; result.push(col);
			return new ArrayList(result);
		}

		public static function printQueueColumns():ArrayList{
			var result:Array= [];
			var col:GridColumn;
			
			col= new GridColumn('id'); col.headerText='ID'; col.width=85; result.push(col);
			col= new GridColumn('state_name'); col.headerText='Статус'; col.width=90; result.push(col); 
			var fmt:DateTimeFormatter=new DateTimeFormatter(); fmt.dateStyle=fmt.timeStyle=DateTimeStyle.SHORT; 
			col= new GridColumn('state_date'); col.headerText='Дата статуса'; col.formatter=fmt;  col.width=110; result.push(col);
			col= new GridColumn('alias'); col.headerText='Алиас'; col.width=100; result.push(col);
			col= new GridColumn('laminat_name'); col.headerText='Ламинат'; col.width=90; result.push(col);
			col= new GridColumn('is_pdf'); col.headerText='PDF'; col.labelFunction=GridUtil.booleanToLabel; col.width=50; result.push(col);
			col= new GridColumn('is_reprint'); col.headerText='Перепечатка'; col.labelFunction=GridUtil.booleanToLabel; col.width=50; result.push(col);
			col= new GridColumn('paper_name'); col.headerText='Бумага'; col.width=70; result.push(col);
			col= new GridColumn('width'); col.headerText='Ширина'; col.width=70; result.push(col);
			col= new GridColumn('height'); col.headerText='Длина'; col.width=70; result.push(col);
			col= new GridColumn('prints'); col.headerText='Кол отпечатков'; col.width=50; result.push(col);
			col= new GridColumn('prints_done'); col.headerText='Напечатано'; col.width=50; result.push(col);
			return new ArrayList(result);
		}

		public static function printQueueStrategyColumns(strategy:int):ArrayList{
			var result:Array= [];
			var col:GridColumn;
			var fmt:NumberFormatter=new NumberFormatter();
			fmt.fractionalDigits=1;
			var dFmt:DateTimeFormatter=new DateTimeFormatter(); dFmt.dateStyle=dFmt.timeStyle=DateTimeStyle.SHORT; 
			
			col= new GridColumn('is_reprint'); col.headerText='Перепечатка'; col.labelFunction=GridUtil.booleanToLabel; col.width=50; result.push(col);
			col= new GridColumn('state_date'); col.headerText='Дата гп'; col.formatter=dFmt;  col.width=110; result.push(col);
			
			if(strategy==PrnStrategy.STRATEGY_BYPART){
				col= new GridColumn('alias'); col.headerText='Алиас'; result.push(col);
				col= new GridColumn('book_part_name'); col.headerText='Часть книги'; result.push(col);
				col= new GridColumn('sheet_num'); col.headerText='Разворотов'; result.push(col);
			}
						
			col= new GridColumn('paper_name'); col.headerText='Бумага'; col.editable=false; result.push(col);
			col= new GridColumn('width'); col.headerText='Ширина'; col.editable=false; result.push(col);

			col= new GridColumn('prints'); col.headerText='Листов'; result.push(col);
			col= new GridColumn('height'); col.headerText='Длинна (мм)'; result.push(col);
			
			col= new GridColumn('printQueueTime'); col.headerText='Время (мин)'; col.formatter=fmt; result.push(col);

			return new ArrayList(result);
		}

		public static function reprintGridColumns():ArrayList{
			var result:Array= [];
			var col:GridColumn;
			
			col= new GridColumn('id'); col.headerText='ID'; col.width=85; result.push(col);
			col= new GridColumn('path'); col.headerText='Папка'; result.push(col);
			col= new GridColumn('width'); col.headerText='Ширина'; result.push(col);
			col= new GridColumn('height'); col.headerText='Длина'; result.push(col);
			col= new GridColumn('paper_name'); col.headerText='Бумага'; result.push(col);
			col= new GridColumn('frame_name'); col.headerText='Рамка'; result.push(col);
			col= new GridColumn('correction_name'); col.headerText='Коррекция'; result.push(col);
			col= new GridColumn('cutting_name'); col.headerText='Обрезка'; result.push(col);
			col= new GridColumn('book_type_name'); col.headerText='Тип книги'; result.push(col);
			col= new GridColumn('book_part_name'); col.headerText='Часть книги'; result.push(col);
			col= new GridColumn('is_pdf'); col.headerText='PDF'; col.labelFunction=GridUtil.booleanToLabel; result.push(col);
			col= new GridColumn('book_num'); col.headerText='Кол книг'; result.push(col);
			return new ArrayList(result);
		}

		
		public var checkStatus:int=0;
		public var checkOrder:int=0;
		
		public var bookTemplate:BookPgTemplate;
		//public var butt:int=0;
		public var is_horizontal:Boolean;

		public var staffActivityCaption:String;

		private var _destinationLab:LabGeneric;
		/**
		 * runtime
		 * post to lab (used in PrintManager) 
		 */
		public function get destinationLab():LabGeneric{
			return _destinationLab;
		}
		public function set destinationLab(value:LabGeneric):void{
			_destinationLab = value;
			if(_destinationLab){
				destination=_destinationLab.id;
			}else{
				destination=0;
			}
		}

		/**
		 * runtime
		 * used in PrintManager 
		 */
		public var isAutoPrint:Boolean=false;
		public var printQueueTime:Number=0;
		
		/**
		 * runtime
		 * auto print temprorary saves choosen lab device 
		public var destinationDeviceId:int;
		 */
		

		/**
		 * runtime
		 * used in PrintManager to rotate before print 
		 */
		public var printPrepare:Boolean;

		
		public function PrintGroup(){
			super.state=OrderState.PRN_WAITE_ORDER_STATE;
			state_date= new Date();
		}
		
		public function toString():String {
			return this.id + ": " + this.path;
		}
		
		private var _prev_state:int;
		override public function set state(value:int):void{
			state_date= new Date();
			if(super.state != value){
				//save old valid state
				if(super.state>0) _prev_state=super.state;
				state_name= OrderState.getStateName(value);
			}
			super.state = value;
		}
		override public function get state():int{
			return super.state;
		}
		
		public function restoreState():void{
			if(_prev_state>0 && _prev_state!=state) state=_prev_state;
		}

		private var originalFiles:ArrayCollection;
		public function resetFiles(keep:Boolean=true):void{
			if(keep) originalFiles=files as ArrayCollection; 
			files=null;
		}
		
		public function restoreFiles():void{
			if(book_type!=0){ //only 4 books
				files=originalFiles;
				file_num=files?files.length:0;
			}
		}

		public function addFile(file:PrintGroupFile):void{
			if(!file) return;
			if(!files) files=new ArrayCollection();
			files.addItem(file);
			file_num=files.length;
		}

		public function isSheetRejected(book:int, sheet:int):Boolean{
			if(!rejects || rejects.length==0) return false;
			var reject:PrintGroupReject;
			for each(reject in rejects){
				if(reject && reject.book==book && (is_pdf || (reject.sheet==-1 || reject.sheet==sheet))) return true;
			}
			return false;
		}

		public function isBookRejected(book:int):Boolean{
			if(!rejects || rejects.length==0) return false;
			var reject:PrintGroupReject;
			for each(reject in rejects){
				if(reject && reject.book==book) return true;
			}
			return false;
		}

		public function addReject(book:int, sheet:int, unit:int, activity:int):void{
			if(book<1) return;
			var oldItem:PrintGroupReject;
			var i:int;
			var exists:Boolean;
			var compact:Boolean;
			var newItem:PrintGroupReject=new PrintGroupReject();
			newItem.print_group=this.id;
			newItem.book=book;
			newItem.sheet=sheet;
			newItem.activity=activity;
			newItem.thech_unit=unit;
			if(!rejects){
				rejects=new ArrayCollection();
				rejects.addItem(newItem);
			}else{
				//check if already added as single sheet or in block 
				for (i = 0; i < rejects.length; i++){
					oldItem=rejects.getItemAt(i) as PrintGroupReject;
					if(!oldItem){
						rejects.setItemAt(null,i);
						compact=true;
						continue;
					}
					if(oldItem.book==newItem.book){
						if(newItem.sheet==-1){
							//all sheets in block  
							if(oldItem.sheet==-1){
								exists=true;
								break;
							}else{
								//remove added vs single sheet 
								rejects.setItemAt(null,i);
								compact=true;
							}
						}else if(oldItem.sheet==newItem.sheet){
							exists=true;
							break;
						}
					}
				}
				if(compact){
					var newRejects:Array=[];
					//var newRejects:ArrayCollection= new ArrayCollection();
					for each(oldItem in rejects){
						if(oldItem) newRejects.push(oldItem);// .addItem(oldItem);
					}
					rejects=new ArrayCollection(newRejects);
				}
				if(!exists) rejects.addItem(newItem);
			}
		}
		
		public function compactRejects():void{
			var oldItems:ArrayCollection=rejects as ArrayCollection;
			if(!oldItems) return;
			rejects=null;
			var item:PrintGroupReject;
			for each(item in oldItems){
				if(item) addReject(item.book, item.sheet, item.thech_unit, item.activity);
			}
		}

		public function key(srcType:int=0,fullness:int=0):String{
			var sizeKey:String;
			switch(fullness){
				case 1:
					//no height 
					sizeKey=width.toString()+'_h'; 
					break;
				case 2:
					//no size at all 
					sizeKey='w_h'; 
					break;
				default:
					//full
					sizeKey=width.toString()+'_'+height.toString(); 
			}
			var result:String;
			switch(srcType){
				case SourceType.LAB_FUJI:
					//SourceType.LAB_FUJI - short key, exlude correction & cutting 
					result=sizeKey+'_'+paper.toString()+'_'+frame.toString(); 
					break;
				case SourceType.LAB_PLOTTER:
					//SourceType.LAB_PLOTTER - short key, exlude correction, cutting & frame 
					result=sizeKey+'_'+paper.toString(); 
					break;
				case SourceType.LAB_XEROX_LONG:
				case SourceType.LAB_XEROX:
					//SourceType.LAB_XEROX - short key, include w/h/pape/duplex
					result=sizeKey+'_'+paper.toString()+'_'+is_duplex.toString(); 
					break;
				case SourceType.LAB_NORITSU_NHF:
					//include w/h
					result=sizeKey; 
					break;
				default:
					//full key (SourceType.LAB_NORITSU or any)
					result=sizeKey+'_'+paper.toString()+'_'+frame.toString()+'_'+correction.toString()+'_'+cutting.toString(); 
					break;
			}
			return result;
		}

		public function clone():PrintGroup{
			var result:PrintGroup=new PrintGroup();
			
			var type:Type= Type.forClass(PrintGroup);
			var props:Array=type.properties;
			if(!props || props.length==0) return result;
			var prop:Field;
			for each(prop in props){
				//exclude childs
				if(this[prop.name] && !(this[prop.name] is IList)) result[prop.name]=this[prop.name];
			}
			result.id='';
			result.files=null;
			result._bookFiles=null;
			result._printFiles=null;
			result._pageNum=0;
			result._pageStart=0;

			/*
			res.order_id=order_id;
			res.sub_id=sub_id;
			
			res.width=width;
			res.height=height;
			
			res.paper=paper;
			res.paper_name=paper_name;
			
			res.frame=frame;
			res.frame_name=frame_name;
			
			res.correction=correction;
			res.correction_name=correction_name;
			
			res.cutting=cutting;
			res.cutting_name=cutting_name;
			
			res.path=path;
			res.alias=alias;
			
			res.book_type=book_type;
			res.book_type_name=book_type_name;
			
			res.book_num=book_num;
			
			res.book_part=book_part;
			res.book_part_name=book_part_name;
			
			res.is_pdf=is_pdf;
			res.is_duplex=is_duplex;
			*/
			return result;
		}

		public function toRaw():Object{
			var raw:Object= new Object;
			raw.id=id;
			raw.order_id=order_id;
			raw.state=state;
			//raw.state_date=state_date;
			raw.width=width;
			raw.height=height;
			raw.paper=paper;
			raw.frame=frame;
			raw.correction=correction;
			raw.cutting=cutting;
			raw.path=path;
			raw.file_num=file_num;
			raw.book_type=book_type;
			raw.book_part=book_part;
			raw.book_num=book_num;
			raw.is_pdf=is_pdf?1:0;
			raw.is_duplex=is_duplex?1:0;
			raw.is_horizontal=is_horizontal?1:0;
			raw.butt=butt;
			raw.pageNumber=pageNumber;
			raw.laminat=laminat;
			
			if(bookTemplate) raw.bookTemplate=bookTemplate.toRaw();
			
			var pgf:PrintGroupFile;
			var pgfRaw:Object;
			var arr:Array=[];
			if(files){
				for each(pgf in files){
					if(pgf){
						pgfRaw=pgf.toRaw();
						arr.push(pgfRaw);
					}
				}
			}
			raw.files=arr;
			
			return raw;
		}
		
		public static function fromRaw(raw:Object):PrintGroup{
			if(!raw) return null;
			var pg:PrintGroup= new PrintGroup();
			pg.id=raw.id;
			pg.order_id=raw.order_id;
			pg.state=raw.state;
			//pg.state_date=raw.state_date;
			pg.width=raw.width;
			pg.height=raw.height;
			pg.paper=raw.paper;
			pg.frame=raw.frame;
			pg.correction=raw.correction;
			pg.cutting=raw.cutting;
			pg.path=raw.path;
			pg.file_num=raw.file_num;
			pg.book_type=raw.book_type;
			pg.book_part=raw.book_part;
			pg.book_num=raw.book_num;
			pg.is_pdf=Boolean(raw.is_pdf);
			pg.is_duplex=Boolean(raw.is_duplex);
			pg.is_horizontal=Boolean(raw.is_horizontal);
			pg.butt=raw.butt;
			pg.pageNumber=raw.pageNumber;
			pg.laminat=raw.laminat;
			
			if(raw.hasOwnProperty('bookTemplate')) pg.bookTemplate=BookPgTemplate.fromRaw(raw.bookTemplate);
			
			var arr:Array=[];
			var pgfRaw:Object;
			var pgf:PrintGroupFile;
			if(raw.hasOwnProperty('files') && raw.files is Array){
				pg.files=new ArrayCollection(); 
				for each(pgfRaw in raw.files){
					pgf=PrintGroupFile.fromRaw(pgfRaw);
					if(pgf) pg.files.addItem(pgf);
				}
			}
			return pg; 
		}

		
		/*************** preprocess & print ***********************/
		private var _bookFiles:Array;
		//print
		private var _printFiles:Array;
		private var _pageNum:int;
		private var _pageStart:int;
		
		/**
		 * runtime max page number, use sheet_num if need pages number
		 * valid after preparePrint or direct set
		 * @return number of page in book 
		 */
		public function get pageNumber():int{
			return _pageNum;
		}
		public function set pageNumber(value:int):void{
			_pageNum=value;
		}
		
		/**
		 * valid after preparePrint
		 * @return prepared 4 print array of PrintGroupFile 
		 */
		public function get printFiles():Array{
			//TODO refactor, has to load from db
			if(!_printFiles) preparePrint();
			return _printFiles;
		}
		
		/**
		 *removes printed files
		 *
		 */
		public function preparePrint():void{
			if(!files) return;
			//_printFiles=files.toArray().concat();
			_printFiles=[];
			var pgf:PrintGroupFile;
			for each (pgf in files){
				if(pgf && !pgf.printed) _printFiles.push(pgf);
			}
		}
		
		//works if template set
		public function get bookFiles():Array{
			if(!_bookFiles) prepareBookFiles();
			return _bookFiles;
		}
		
		public function resetBookFiles():void{
			_bookFiles=null;
		}
		
		private function prepareBookFiles():void{
			if(!files) return;
			var fa:Array=files.toArray();
			
			if(book_type==0){
				_bookFiles=fa.concat();
				return;
			}
			if(!bookTemplate) return;
			
			if(book_part==BookSynonym.BOOK_PART_COVER){
				prepareCovers();
			}else if(book_part==BookSynonym.BOOK_PART_BLOCK || book_part==BookSynonym.BOOK_PART_BLOCKCOVER){
				prepareSheets();
			}else if(book_part==BookSynonym.BOOK_PART_INSERT){
				prepareInserts();
			}
		}
		
		private function detectPagesNumber():void{
			if(!files) return;
			var it:PrintGroupFile;
			_pageNum=0;
			_pageStart=int.MAX_VALUE;
			for each(it in files){
				if(it){
					_pageNum=Math.max(_pageNum,it.page_num);
					_pageStart=Math.min(_pageStart,it.page_num);
				}
			}
		}
		
		private function prepareSheets():void{
			if(!files || book_type==0) return; // || book_part!=BookSynonym.BOOK_PART_BLOCK) return;
			var i:int;
			var j:int;
			var it:PrintGroupFile;
			var img:PrintGroupFile;
			var len:int;
			
			//detect pages num
			detectPagesNumber();
			len=_pageNum-_pageStart+1;
			
			//get default pages
			var defPages:Array=new Array();
			for each(it in files){
				if(it && it.book_num==0) defPages.push(it);
			}
			
			//fill 
			var books:Array=new Array(book_num);
			var bookFiles:Array;
			for (i=0; i<books.length; i++){
				bookFiles=new Array(len);
				//fill vs defaults
				for each(img in defPages){
					if(img){
						it=img.clone();
						it.book_num=i+1;
						bookFiles[it.page_num-_pageStart]=it;
					}
				}
				//fill vs pages
				for (j=0; j<len; j++){
					it=getImage(i+1,j+_pageStart);
					if(it) bookFiles[j]=it;
				}
				if(is_pdf && !bookTemplate.is_sheet_ready && book_type==BookSynonym.BOOK_TYPE_BOOK && is_duplex){
					//add extra blank pages
					bookFiles.unshift(null);
					bookFiles.push(null);
				}
				
				//cover has to be last 4 BOOK_PART_BLOCKCOVER
				if(book_part==BookSynonym.BOOK_PART_BLOCKCOVER){
					//reorder
					it=bookFiles.shift() as PrintGroupFile;
					bookFiles.push(it);
				}
				
				books[i]=bookFiles;
			}
			
			//concat 
			_bookFiles=[];
			for (i=0; i<books.length; i++){
				_bookFiles=_bookFiles.concat(books[i]);
			}
		}
		
		private function prepareCovers():void{
			if(!files || book_type==0 || book_part!=BookSynonym.BOOK_PART_COVER) return;
			var it:PrintGroupFile;
			var i:int;
			var imgFront:PrintGroupFile;
			var imgBackLeft:PrintGroupFile;
			var imgBackRight:PrintGroupFile;
			if(is_pdf && book_type==BookSynonym.BOOK_TYPE_JOURNAL && bookTemplate && !bookTemplate.is_sheet_ready){
				//pdf journal 
				detectPagesNumber();
				_bookFiles=new Array(book_num*3);
				//default cover
				imgFront=getDefaultImage(0);
				//default 1st page
				imgBackLeft=getDefaultImage(1);
				//default last page
				imgBackRight=getDefaultImage(pageNumber);
				//fill vs defaults
				for (i=0; i<book_num; i++){
					if(imgFront){
						it=imgFront.clone();
						it.book_num=i+1;
						_bookFiles[i*3]=it;
					}
					if(imgBackLeft){
						it=imgBackLeft.clone();
						it.book_num=i+1;
						_bookFiles[i*3+1]=it;
					}
					if(imgBackRight){
						it=imgBackRight.clone();
						it.book_num=i+1;
						_bookFiles[i*3+2]=it;
					}
				}
				//fill
				for each(it in files){
					if(it && (it.page_num<2 || it.page_num==pageNumber) && it.book_num!=0){
						if(it.page_num<2){
							_bookFiles[(it.book_num-1)*3+it.page_num]=it;
						}else{
							_bookFiles[(it.book_num-1)*3+2]=it;
						}
					}
				}
			}else{
				//common
				_bookFiles=new Array(book_num);
				//fill vs default cover
				imgFront=getDefaultImage(0);
				if(imgFront){
					for (i=0; i<book_num; i++){
						it=imgFront.clone();
						it.book_num=i+1;
						_bookFiles[i]=it;
					}
				}
				//fill
				for each(it in files){
					if(it && it.page_num==0 && it.book_num!=0){
						_bookFiles[it.book_num-1]=it;
					}
				}
			}
		}
		
		private function prepareInserts():void{
			if(!files || book_type==0 || book_part!=BookSynonym.BOOK_PART_INSERT) return;
			var it:PrintGroupFile;
			var i:int;
			var imgFront:PrintGroupFile;
			var imgBackLeft:PrintGroupFile;
			var imgBackRight:PrintGroupFile;
			
			_bookFiles=new Array(book_num);
			//fill vs default cover
			imgFront=getDefaultImage(0);
			if(imgFront){
				for (i=0; i<book_num; i++){
					it=imgFront.clone();
					it.book_num=i+1;
					_bookFiles[i]=it;
				}
			}
			//fill
			for each(it in files){
				if(it && it.page_num==0 && it.book_num!=0){
					_bookFiles[it.book_num-1]=it;
				}
			}
		}
		
		private function getImage(book:int, page:int):PrintGroupFile{
			var img:PrintGroupFile;
			for each(var it:PrintGroupFile in files){
				if(it && it.book_num==book && it.page_num==page){
					img=it;
					break;
				}
			}
			return img;
		}
		
		private function getDefaultImage(page:int):PrintGroupFile{
			var img:PrintGroupFile;
			for each(var it:PrintGroupFile in files){
				if(it && it.book_num==0 && it.page_num==page){
					img=it;
					break;
				}
			}
			return img;
		}
		
		public function pdfFileNamePrefix(withFolder:Boolean=true):String{
			var result:String='';
			if (book_type!=0 && is_pdf){
				if(book_part==BookSynonym.BOOK_PART_COVER){
					result=humanId+'-'+PDF_FILENAME_COVERS;
				}else if(book_part==BookSynonym.BOOK_PART_BLOCK || book_part==BookSynonym.BOOK_PART_BLOCKCOVER){
					result=humanId+'-'+PDF_FILENAME_SHEETS;
				}
				if(withFolder) result=SUBFOLDER_PRINT+File.separator+result;
			}
			return result;
		}
		
		public function get humanId():String{
			var arr:Array;
			var result:String='';
			if(id){
				arr=id.split('_');
				if(arr && arr.length==3) result=arr[1]+'-'+arr[2];
			}else if(order_id){
				arr=order_id.split('_');
				if(arr && arr.length==2) result=arr[1];
			}
			return result;
		}
		
		public function get orderHumanId():String{
			var arr:Array;
			var result:String='';
			if(id){
				arr=id.split('_');
				if(arr && arr.length==3) result=arr[1];
			}else if(order_id){
				arr=order_id.split('_');
				if(arr && arr.length==2) result=arr[1];
			}
			return result;
		}

		public function get numericId():int{
			if(!id) return 0;
			var arr:Array= id.split('_');
			var result:String='';
			if(arr && arr.length==3) result=arr[2]+arr[1];
			result = result.replace('-','');
			return result?int(result):0;
		}
		
		public function annotateText(file:PrintGroupFile):String{
			if(!file) return '';
			//id
			var txt:String=humanId;
			/*
			//book
			txt=txt+' книга '+StrUtil.lPad(file.book_num.toString(),2)+'из'+StrUtil.lPad(book_num.toString(),2);
			//sheet
			txt=txt+' разворот '+StrUtil.lPad(file.page_num.toString(),2)+'из'+StrUtil.lPad(pageNumber.toString(),2);
			//butt
			if(butt){
			txt=txt+' торец-'+butt.toString()+'мм';
			}
			*/
			txt=' '+txt+' '+file.caption+' ';
			return txt;
		}
		
		public function bookBarcodeText(file:PrintGroupFile):String{
			var sourceId:int=source_id;
			var text:String='';
			if(!sourceId && id){
				var arr:Array=id.split('_');
				if(arr && arr.length>0) sourceId=arr[0];
			}
			if(!sourceId) return '';
			var src:Source=Context.getSource(sourceId);
			if(!src) return '';
			text+=(src.code?src.code:'u');
			//text+=orderHumanId;
			text+=humanId;
			if(file.book_num>0){
				text=text+':'+file.book_num.toString();
			}
			return text;
		}
		
		/**
		 * 
		 * @param file
		 * @return 
		 * getDigitId+полседние 3и символа книга
		 * 2 символа источник+idзаказа+2 символа номер группы печати+3и символа книга 
		 * old: первых 2а символа источник, id, полседние 3и символа книга 
		 */		
		public function bookBarcode(file:PrintGroupFile):String{
			if(!id || !file) return '';
			/*
			var arr:Array=id.split('_');
			if(!arr || arr.length<2) return '';
			var result:String=arr[0];
			if (result.length>2) return '';
			result=StrUtil.lPad(result,2)+arr[1]+StrUtil.lPad(file.book_num.toString(),3);
			*/
			var result:String=getDigitId();
			if (result) result+=StrUtil.lPad(file.book_num.toString(),3);
			return result;
		}

		/**
		 * 
		 * @return 
		 * getDigitId+полседние 3и символа книга (всегда 000)
		 * 2 символа источник+idзаказа+2 символа номер группы печати+3и символа книга 
		 */		
		public function orderBarcode():String{
			if(!id) return '';
			var result:String=getDigitId();
			if (result) result+='000';
			return result;
		}

		public function orderBarcodeBest():String{
			var sourceId:int=source_id;
			var text:String='';
			if(!sourceId && id){
				var arr:Array=id.split('_');
				if(arr && arr.length>0) sourceId=arr[0];
			}
			if(!sourceId) return '';
			var src:Source=Context.getSource(sourceId);
			if(!src) return '';
			text+=(src.code?src.code:'u');
			text+=orderHumanId;
			return text;
		}

		
		/**
		 * 
		 * @param file
		 * @return 
		 * книга(всегоКниг)-страница(всегоСтраниц) IdГруппыПечати
		 */		
		public function techBarcodeText(file:PrintGroupFile):String{
			//var text:String=StrUtil.lPad(file.book_num.toString(),3)+'('+StrUtil.lPad(book_num.toString(),3)+')-'+StrUtil.lPad(file.page_num.toString(),2)+'('+StrUtil.lPad(pageNumber.toString(),2)+') '+id;
			var text:String=StrUtil.lPad(file.book_num.toString(),3)+'('+StrUtil.lPad(book_num.toString(),3)+')-'+StrUtil.lPad(file.page_num.toString(),2)+'('+StrUtil.lPad(sheet_num.toString(),2)+') '+id;
			return text;
		}
		
		/**
		 * 
		 * @param file
		 * @return 
		 * книга(3символа)всегоКниг(3символа)страница(2символа)всегоСтраниц(2символа)IdГруппыПечати(первых 2а символа источник, полседние 2а символа подгруппа) 
		 */		
		public function techBarcodeByFile(file:PrintGroupFile):String{
			/*
			var text:String=StrUtil.lPad(file.book_num.toString(),3)+StrUtil.lPad(book_num.toString(),3)
			+StrUtil.lPad(file.page_num.toString(),2)+StrUtil.lPad(pageNumber.toString(),2)
			+getDigitId();*/
			//return techBarcode(file.book_num, book_num, file.page_num, pageNumber);
			return techBarcode(file.book_num, book_num, file.page_num, sheet_num);
		}
		public function techBarcode(book:int, bookTotal:int, sheet:int, sheetTotal:int):String{
			var text:String=StrUtil.lPad(book.toString(),3)+StrUtil.lPad(bookTotal.toString(),3)
				+StrUtil.lPad(sheet.toString(),2)+StrUtil.lPad(sheetTotal.toString(),2)
				+getDigitId();
			return text;
		}
		/*
			первые 2 символа источник
			idзаказа
			последние 2 символа номер группы печати 
		*/
		private function getDigitId():String{
			if(!id) return '';
			var arr:Array=id.split('_');
			if(!arr || arr.length!=3) return '';
			var tStr:String=arr[0];
			if (tStr.length>2) return '';
			var result:String=StrUtil.lPad(tStr,2)+arr[1];
			tStr=arr[2];
			if (tStr.length>2) return '';
			return result+StrUtil.lPad(tStr,2);
		}
		
		public static function tech2BookBarcode(techBarcode:String):String{
			if(!techBarcode || techBarcode.length<14) return '';
			var bookNum:int=parseInt(techBarcode.substr(0,3));
			if(isNaN(bookNum)) return '';
			var dgId:String=techBarcode.substr(10);
			return dgId+StrUtil.lPad(bookNum.toString(),3);
		}
		public static function tech2BookBarcodeCaption(techBarcode:String):String{
			if(!techBarcode || techBarcode.length<14) return '';
			var bookNum:int=parseInt(techBarcode.substr(0,3));
			if(isNaN(bookNum)) return '';
			
			var dgId:String=techBarcode.substr(10);
			//parce digit id
			if(!dgId || dgId.length<5) return '';
			
			var srcId:int= parseInt(dgId.substr(0,2));
			if(isNaN(srcId)) return '';
			var srcCode:String=Context.getSourceCodeById(srcId);
			if(!srcCode) srcCode=srcId.toString()+'_';

			var id:String=dgId.substr(2,dgId.length-4);
			
			return srcCode+id+':'+bookNum.toString();
		}

		public static function idFromDigitId(digitId:String):String{
			if(!digitId || digitId.length<5) return '';
			if(digitId.indexOf('_')!=-1) return digitId; //old barcode (x_xx_x)
			var tInt:int= parseInt(digitId.substr(0,2));
			if(isNaN(tInt)) return '';
			var result:String=tInt.toString()+'_'+digitId.substr(2,digitId.length-4);
			tInt=parseInt(digitId.substr(digitId.length-2,2));
			if(isNaN(tInt)) return '';
			return result+'_'+tInt.toString();
		}
		
		public static function getIdxFromId(id:String):int{
			if(!id) return -1;
			var arr:Array=id.split('_');
			if(!arr || arr.length!=3) return -1;
			var idx:Number= parseInt(arr[2],10);
			if(isNaN(idx)) return -1; 
			return int(idx);
		}

		public static function idFromBookBarcode(code:String):String{
			if(!code || code.length<8) return '';
			if(code.indexOf('_')!=-1) return code; //old barcode (x_xx_x)
			if(code.indexOf(':')!=-1) return ''; //old barcode (x_xx_x)
			//src id
			var src:int= parseInt(code.substr(0,2));
			if(isNaN(src)) return '';
			//order id
			var order:String=code.substr(2,code.length-7);
			//pg #
			var pg:int=parseInt(code.substr(code.length-5,2));
			if(isNaN(pg)) return '';
			/*
			//book #
			var book:int=parseInt(code.substr(code.length-3,3));
			if(isNaN(book)) return '';
			*/
			return src.toString()+'_'+order+'_'+pg.toString();
		}

		public static function orderIdFromBookBarcode(code:String):String{
			if(!code || code.length<8) return '';
			if(code.indexOf('_')!=-1) return code; //old barcode (x_xx_x)
			if(code.indexOf(':')!=-1) return ''; //old barcode (x_xx_x)
			if ((code.charAt(0) >= 'A' && code.charAt(0) <= 'Z') || (code.charAt(0) >= 'a' && code.charAt(0) <= 'z')) return ''; //old barcode (RXXXXXX)
			//src id
			var src:int= parseInt(code.substr(0,2));
			if(isNaN(src)) return '';
			//order id
			var order:String=code.substr(2,code.length-7);
			return src.toString()+'_'+order;
		}

		public static function isTechBarcode(techBarcode:String):Boolean{
			//3(book)+3(books)+2(sheet)+2(sheets)=10 +2(src)+2(pg)= 14 + 1 (at least 1 digit for order) 
			if(!techBarcode || techBarcode.length<15) return false;
			//check if book>books or sheet>sheets
			if((bookFromTechBarcode(techBarcode)>bookNumFromTechBarcode(techBarcode)) ||
			   (sheetFromTechBarcode(techBarcode)>sheetNumFromTechBarcode(techBarcode))) return false;
			//uses fact that books <199 & source id is 1 char len and is >0
			//return techBarcode.charAt(0)=='0';
			return true;
		}
		
		public static function bookFromTechBarcode(code:String):int{
			if(!code || code.length<14) return 0;
			return int(code.substr(0,3));
		}
		public static function bookNumFromTechBarcode(code:String):int{
			if(!code || code.length<14) return 0;
			return int(code.substr(3,3));
		}
		public static function sheetFromTechBarcode(code:String):int{
			if(!code || code.length<14) return 0;
			return int(code.substr(6,2));
		}
		public static function sheetNumFromTechBarcode(code:String):int{
			if(!code || code.length<14) return 0;
			return int(code.substr(8,2));
		}
		public static function digitIdFromTechBarcode(code:String):String{
			if(!code || code.length<14) return '';
			return code.substr(10);
		}
		public static function orderIdFromTechBarcode(code:String):String{
			var digitId:String=digitIdFromTechBarcode(code);
			if(!digitId || digitId.length<5) return '';
			var tInt:int= parseInt(digitId.substr(0,2));
			if(isNaN(tInt)) return '';
			var result:String=tInt.toString()+'_'+digitId.substr(2,digitId.length-4);
			return result;
		}

		public static function bookFromBookBarcode(code:String):int{
			if(!code || code.length<8) return 0;
			if(code.indexOf('_')!=-1) return 0; //old barcode (x_xx_x)
			if(code.indexOf(':')!=-1) return 0; //old barcode (x_xx_x:book)
			//book #
			var book:int=parseInt(code.substr(code.length-3,3));
			if(isNaN(book)) return 0;
			return book;
		}

		
		public function setBooks(pBooks:Array):void{
			books=null;
			if(!pBooks) return;
			var resArr:Array= new Array(book_num);
			var rjArr:Array= [];
			var bk:OrderBook;
			var rj:OrderBook;
			var added:Boolean=false;
			//get books 4 pg
			for each (bk in pBooks){
				if(bk && bk.target_pg==id){
					added=true;
					if(bk.is_reject){
						rjArr.push(bk);
					}else{
						resArr[bk.book-1]=bk;
					}
				}
			}
			if(!added) return;
			//process rejects
			for each (rj in rjArr){
				bk=resArr[rj.book-1] as OrderBook;
				if(bk) bk.addReject(rj);
			}
			books= new ArrayCollection(resArr);
		}
		
		private var _printFolder:File;
		public function get printFolder():File{
			if (_printFolder) return _printFolder;
			//look up prt folder in print & wrk folders
			var src:Source=Context.getSource(source_id);
			var srcFName:String;
			var dir:File;
			var srcFolder:File;
			if(src){
				//check print folder
				srcFName=src.getPrtFolder()+File.separator+order_folder+File.separator+path;
				if(printPrepare) srcFName=srcFName+File.separator+PreparePrint.ROTATE_FOLDER;
				try{ 
					srcFolder=new File(srcFName);
				}catch(e:Error){}
				if(srcFolder && srcFolder.exists){
					dir=srcFolder.resolvePath(PrintGroup.SUBFOLDER_PRINT);
					if(!dir.exists || !dir.isDirectory) srcFolder=null;
				}else{
					srcFolder=null;
				}
				if(!srcFolder){
					//check wrk folder
					srcFName=src.getWrkFolder()+File.separator+order_folder+File.separator+path;
					try{ 
						srcFolder=new File(srcFName);
					}catch(e:Error){}
					if(srcFolder && srcFolder.exists){
						dir=srcFolder.resolvePath(PrintGroup.SUBFOLDER_PRINT);
						if(!dir.exists || !dir.isDirectory) srcFolder=null;
					}else{
						srcFolder=null;
					}
				}
			}
			_printFolder=srcFolder;
			return srcFolder;
		}

    }
}