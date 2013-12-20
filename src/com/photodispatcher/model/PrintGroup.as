package com.photodispatcher.model{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.model.dao.OrderStateDAO;
	import com.photodispatcher.model.dao.PrintGroupFileDAO;
	import com.photodispatcher.print.LabBase;
	import com.photodispatcher.util.StrUtil;
	
	import flash.filesystem.File;

	public class PrintGroup extends DBRecord{
		public static const PDF_FILENAME_COVERS:String='oblogka';
		public static const PDF_FILENAME_SHEETS:String='blok';
		public static const SUBFOLDER_PRINT:String='print';

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
		
		//database props
		[Bindable]
		public var id:String;
		[Bindable]
		public var order_id:String;

		private var _prev_state:int;
		private var _state:int=OrderState.PRN_WAITE_ORDER_STATE;
		[Bindable]
		public function get state():int{
			return _state;
		}
		public function set state(value:int):void{
			state_date= new Date();
			if(_state != value){
				//save old valid state
				if(_state>0) _prev_state=_state;
				state_name= OrderStateDAO.getStateName(value);
			}
			_state = value;
		}
		/*
		*restore state after err state
		*/
		public function restoreState():void{
			if(_prev_state>0 && _prev_state!=_state) state=_prev_state;
		}

		[Bindable]
		public var state_date:Date= new Date();
		/*
		[Bindable]
		public var format:int=0;
		*/
		[Bindable]
		public var width:int;
		[Bindable]
		public var height:int;
		[Bindable]
		public var paper:int=0;
		[Bindable]
		public var frame:int=0;
		[Bindable]
		public var correction:int=0;
		[Bindable]
		public var cutting:int=0;
		[Bindable]
		public var path:String;
		[Bindable]
		public var file_num:int=0;
		[Bindable]
		public var destination:int=0;
		[Bindable]
		public var book_type:int=0;
		[Bindable]
		public var book_part:int=0;
		[Bindable]
		public var book_num:int=0;
		/**
		 *количество печатных листов в книге
		 */		
		[Bindable]
		public var sheet_num:int=0;
		[Bindable]
		public var is_pdf:Boolean=false;
		[Bindable]
		public var is_duplex:Boolean=false;
		public var is_reprint:Boolean=false;
		//prints number
		public var prints:int;

		//runtime
		public var bookTemplate:BookPgTemplate;
		public var butt:int=0;
		public var is_horizontal:Boolean;
		public var prints_done:int;
		
		//ref
		public var source_id:int;
		public var order_folder:String;
		[Bindable]
		public var source_name:String;
		[Bindable]
		public var state_name:String;
		[Bindable]
		public var paper_name:String;
		[Bindable]
		public var frame_name:String;
		[Bindable]
		public var correction_name:String;
		[Bindable]
		public var cutting_name:String;
		[Bindable]
		public var lab_name:String;
		[Bindable]
		public var book_type_name:String;
		[Bindable]
		public var book_part_name:String;

		//drived
		
		// Lazy loading files
		private var _files:Array;
		public function loadFiles():void{
			var fDAO:PrintGroupFileDAO= new PrintGroupFileDAO();
			_files=fDAO.getByPrintGroup(this.id);
		}

		/**
		 * 
		 * @return array of PrintGroupFile 
		 * Lazy loading files
		 */
		public function get files():Array{
			if(!_files) loadFiles();
			return _files;
		}

		/*
		*get vsout Lazy loading
		*/
		public function getFiles():Array{
			return _files;
		}

		private var originalFiles:Array;
		public function resetFiles(keep:Boolean=true):void{
			if(keep) originalFiles=_files; 
			_files=null;
		}

		public function restoreFiles():void{
			if(book_type!=0){ //only 4 books
				_files=originalFiles;
				file_num=_files?_files.length:0;
			}
		}

		public function addFile(file:PrintGroupFile):void{
			if(!file) return;
			if(!_files) _files=[];
			_files.push(file);
			file_num=_files.length;
		}
		
		/**
		 * runtime
		 * post to lab (used in PrintManager) 
		 */
		public var destinationLab:LabBase;

		public function key(srcType:int=SourceType.LAB_NORITSU,fullness:int=0):String{
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
			var res:PrintGroup=new PrintGroup();
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
			
			res.book_type=book_type;
			res.book_type_name=book_type_name;

			res.book_num=book_num;
			
			res.book_part=book_part;
			res.book_part_name=book_part_name;
			
			res.is_pdf=is_pdf;
			res.is_duplex=is_duplex;
			return res;
		}
		
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
			if(!_printFiles) preparePrint();
			return _printFiles;
		}
		
		/**
		 *
		 * load PrintGroupFiles, create copies (if required)
		 *
		 */
		public function preparePrint():void{
			var fa:Array=files;
			if(!fa) return;
			if (book_type!=0 && is_pdf){
				_printFiles=fa.concat();
				return;
			}
			if(book_type==0 || is_reprint){
				//common print 
				_printFiles=fa.concat();
				return;
			}
			//common book
			prepareBookFiles();
		}

		public function preparePDF():void{
			if(book_type==0 || !is_pdf) return;
			prepareBookFiles(true);
		}

		private function prepareBookFiles(forPdf:Boolean=false):void{
			if(book_type==0) return;
			var it:PrintGroupFile;
			
			if(book_part==BookSynonym.BOOK_PART_COVER){
				prepareCovers(forPdf);
			}else if(book_part==BookSynonym.BOOK_PART_BLOCK){
				prepareSheets(forPdf);
			}else if(book_part==BookSynonym.BOOK_PART_INSERT){
				prepareInserts();
			}
		}

		private function detectPagesNumber():void{
			var it:PrintGroupFile;
			_pageNum=0;
			_pageStart=int.MAX_VALUE;
			for each(it in getFiles()){
				if(it){
					_pageNum=Math.max(_pageNum,it.page_num);
					_pageStart=Math.min(_pageStart,it.page_num);
				}
			}
		}

		private function prepareSheets(forPdf:Boolean=false):void{
			if(book_type==0 || book_part!=BookSynonym.BOOK_PART_BLOCK) return;
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
			for each(it in getFiles()){
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
				if(forPdf && is_pdf && book_type==BookSynonym.BOOK_TYPE_BOOK){
					//add extra blank pages
					bookFiles.unshift(null);
					bookFiles.push(null);
				}
				books[i]=bookFiles;
			}
			
			//concat 
			_printFiles=[];
			for (i=0; i<books.length; i++){
				_printFiles=_printFiles.concat(books[i]);
			}
		}

		private function prepareCovers(forPdf:Boolean=false):void{
			if(book_type==0 || book_part!=BookSynonym.BOOK_PART_COVER) return;
			var it:PrintGroupFile;
			var i:int;
			var imgFront:PrintGroupFile;
			var imgBackLeft:PrintGroupFile;
			var imgBackRight:PrintGroupFile;
			if(is_pdf && book_type==BookSynonym.BOOK_TYPE_JOURNAL){
				//pdf journal 
				detectPagesNumber();
				_printFiles=new Array(book_num*3);
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
						_printFiles[i*3]=it;
					}
					if(imgBackLeft){
						it=imgBackLeft.clone();
						it.book_num=i+1;
						_printFiles[i*3+1]=it;
					}
					if(imgBackRight){
						it=imgBackRight.clone();
						it.book_num=i+1;
						_printFiles[i*3+2]=it;
					}
				}
				//fill
				for each(it in getFiles()){
					if(it && (it.page_num<2 || it.page_num==pageNumber) && it.book_num!=0){
						if(it.page_num<2){
							_printFiles[(it.book_num-1)*3+it.page_num]=it;
						}else{
							_printFiles[(it.book_num-1)*3+2]=it;
						}
					}
				}
			}else{
				//common
				_printFiles=new Array(book_num);
				//fill vs default cover
				imgFront=getDefaultImage(0);
				if(imgFront){
					for (i=0; i<book_num; i++){
						it=imgFront.clone();
						it.book_num=i+1;
						_printFiles[i]=it;
					}
				}
				//fill
				for each(it in getFiles()){
					if(it && it.page_num==0 && it.book_num!=0){
						_printFiles[it.book_num-1]=it;
					}
				}
			}
		}

		private function prepareInserts():void{
			if(book_type==0 || book_part!=BookSynonym.BOOK_PART_INSERT) return;
			var it:PrintGroupFile;
			var i:int;
			var imgFront:PrintGroupFile;
			var imgBackLeft:PrintGroupFile;
			var imgBackRight:PrintGroupFile;

			_printFiles=new Array(book_num);
			//fill vs default cover
			imgFront=getDefaultImage(0);
			if(imgFront){
				for (i=0; i<book_num; i++){
					it=imgFront.clone();
					it.book_num=i+1;
					_printFiles[i]=it;
				}
			}
			//fill
			for each(it in getFiles()){
				if(it && it.page_num==0 && it.book_num!=0){
					_printFiles[it.book_num-1]=it;
				}
			}
		}

		private function getImage(book:int, page:int):PrintGroupFile{
			var img:PrintGroupFile;
			for each(var it:PrintGroupFile in getFiles()){
				if(it && it.book_num==book && it.page_num==page){
					img=it;
					break;
				}
			}
			return img;
		}
		
		private function getDefaultImage(page:int):PrintGroupFile{
			var img:PrintGroupFile;
			for each(var it:PrintGroupFile in getFiles()){
				if(it && it.book_num==0 && it.page_num==page){
					img=it;
					break;
				}
			}
			return img;
		}
		
		public function get pdfFileNamePrefix():String{
			var result:String='';
			if (book_type!=0 && is_pdf){
				if(book_part==BookSynonym.BOOK_PART_COVER){
					result=humanId+'-'+PDF_FILENAME_COVERS;
				}else if(book_part==BookSynonym.BOOK_PART_BLOCK){
					result=humanId+'-'+PDF_FILENAME_SHEETS;
				}
				result=SUBFOLDER_PRINT+File.separator+result;
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

		public function barcodeText(file:PrintGroupFile):String{
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
			if(file.book_num>0){
				text=text+':'+file.book_num.toString();
			}
			return text;
		}

		/**
		 * 
		 * @param file
		 * @return 
		 * книга(всегоКниг)-страница(всегоСтраниц) IdГруппыПечати
		 */		
		public function techBarcodeText(file:PrintGroupFile):String{
			var text:String=StrUtil.lPad(file.book_num.toString(),3)+'('+StrUtil.lPad(book_num.toString(),3)+')-'+StrUtil.lPad(file.page_num.toString(),2)+'('+StrUtil.lPad(pageNumber.toString(),2)+') '+id;
			return text;
		}

		/**
		 * 
		 * @param file
		 * @return 
		 * книга(3символа)всегоКниг(3символа)страница(2символа)всегоСтраниц(2символа)IdГруппыПечати
		 */		
		public function techBarcode(file:PrintGroupFile):String{
			var text:String=StrUtil.lPad(file.book_num.toString(),3)+StrUtil.lPad(book_num.toString(),3)+StrUtil.lPad(file.page_num.toString(),2)+StrUtil.lPad(pageNumber.toString(),2)+id;
			return text;
		}

		public function toRaw():Object{
			var raw:Object= new Object;
			raw.id=id;
			raw.order_id=order_id;
			raw.state=_state;
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

			if(bookTemplate) raw.bookTemplate=bookTemplate.toRaw();
			
			var pgf:PrintGroupFile;
			var pgfRaw:Object;
			var arr:Array=[];
			if(_files){
				for each(pgf in _files){
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
			pg._state=raw.state;
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
			
			if(raw.hasOwnProperty('bookTemplate')) pg.bookTemplate=BookPgTemplate.fromRaw(raw.bookTemplate);
			
			var arr:Array=[];
			var pgfRaw:Object;
			var pgf:PrintGroupFile;
			if(raw.hasOwnProperty('files') && raw.files is Array){
				pg._files=[]; 
				for each(pgfRaw in raw.files){
					pgf=PrintGroupFile.fromRaw(pgfRaw);
					if(pgf) pg._files.push(pgf);
				}
			}
			
			return pg; 
		}

	}
}