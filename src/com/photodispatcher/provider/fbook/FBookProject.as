package com.photodispatcher.provider.fbook{
	import com.akmeful.card.data.CardProject;
	import com.akmeful.fotakrama.canvas.CanvasUtil;
	import com.akmeful.fotakrama.data.Project;
	import com.akmeful.fotakrama.data.ProjectBook;
	import com.akmeful.fotakrama.data.ProjectBookPage;
	import com.akmeful.fotocalendar.data.FotocalendarProject;
	import com.akmeful.fotocanvas.data.FotocanvasProject;
	import com.akmeful.fotocup.data.FotocupProject;
	import com.akmeful.fotokniga.book.BookEditorInfo;
	import com.akmeful.fotokniga.book.data.Book;
	import com.akmeful.fotokniga.book.data.BookCoverPrintType;
	import com.akmeful.fotokniga.book.data.BookPage;
	import com.akmeful.fotokniga.book.layout.BookLayout;
	import com.akmeful.magnet.data.MagnetProject;
	import com.photodispatcher.model.mysql.entities.BookSynonym;
	import com.photodispatcher.model.mysql.entities.LayersetSynonym;
	import com.photodispatcher.provider.fbook.download.DownloadErrorItem;
	import com.photodispatcher.provider.fbook.model.PageData;
	import com.photodispatcher.util.ArrayUtil;
	
	import flash.filesystem.File;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	
	import mx.collections.ArrayCollection;
	import mx.formatters.DateFormatter;

	public class FBookProject{
		public static const SUBDIR_WRK:String='wrk';
		public static const SUBDIR_ART:String='art';
		public static const SUBDIR_USER:String='usr';

		public static const PROJECT_TYPE_BCARD:int=4;

		public var notLoadedItems:Array; //DownloadErrorItem
		public var projectPages:Array=[]; //PageData, has data after IMScrip.build 

		public var bookNumber:int=0; 
		
		private var _log:String;
		private var _project:ProjectBook;
		private var projectRaw:Object;
		public function get project():ProjectBook{
			return _project;
		}
		
		public var downloadState:int=TripleState.TRIPLE_STATE_NON;
		
		public function FBookProject(raw:Object=null){
			if(raw) projectFromRaw(raw);
		}
		
		private function projectFromRaw(raw:Object):void{
			projectRaw=raw;
			var p:Project=new Project('','', raw);
			var bp:ProjectBookPage;

			if(!p) return;
			switch(p.type){
				case Book.PROJECT_TYPE:
					var b:Book= new Book(raw);
					b.fixBeforePrint();
					_project=b;
					break;
				case FotocalendarProject.PROJECT_TYPE:
					var c:FotocalendarProject= new FotocalendarProject(raw);
					c.fixBeforePrint();
					_project=c;
					//uncompres content
					for each (bp in c.pages){
						if(bp && bp.content){
							bp.content=CanvasUtil.extractImportedContent(bp.content);
						}
					}
					break;
				case FotocanvasProject.PROJECT_TYPE:
					var cc:FotocanvasProject= new FotocanvasProject('','',raw);
					cc.fixBeforePrint();
					_project=cc;
					break;
				case MagnetProject.PROJECT_TYPE:
					//magnet = createItem(rawData) as MagnetProject;
					var mp:MagnetProject= new MagnetProject(raw);
					mp.fixBeforePrint();
					_project=mp;
					break;
				case PROJECT_TYPE_BCARD:
					var bcp:CardProject= new CardProject('','',raw);
					bcp.fixBeforePrint();
					_project=bcp;
					break;
				case FotocupProject.PROJECT_TYPE:
					//magnet = createItem(rawData) as MagnetProject;
					var fc:FotocupProject= new FotocupProject('','',raw);
					fc.fixBeforePrint();
					_project=fc;
					break;
			}
			//reindex content elements
			var idx:int;
			var element:Object;
			if(_project && _project.pages){
				for each (bp in _project.pages){
					if(bp && bp.content){
						idx=0;
						for each (element in bp.content){
							element.index=idx;
							idx++;
						}
					}
				}
			}
		}
		
		public function get id():int{
			return project?project.id:-1;
		}
		
		public function get type():int{
			return project?project.type:-1;
		}
		
		public function get typeCaption():String{
			if(!project) return 'Неопределен';
			switch(type){
				case Book.PROJECT_TYPE:
					return 'Фотокнига';
					break;
				case FotocalendarProject.PROJECT_TYPE:
					return 'Календарь';
					break;
				case MagnetProject.PROJECT_TYPE:
					return 'Магнит';
					break;
				case FotocanvasProject.PROJECT_TYPE:
					return 'Холст';
					break;
				case PROJECT_TYPE_BCARD:
					return 'Визитка';
					break;
				case FotocupProject.PROJECT_TYPE:
					return 'Кружка';
					break;
				default:
					return 'Неопределен';
			}
		}

		public function get bookType():int{
			if(!project) return 0;
			switch(type){
				case Book.PROJECT_TYPE:
					switch((project as Book).template.cover.printType){
						case BookCoverPrintType.PHOTO_EXTENDED:
							//return BookSynonym.BOOK_TYPE_JOURNAL;
							return BookSynonym.BOOK_TYPE_BOOK;
							break;
						case BookCoverPrintType.EMPTY:
						case BookCoverPrintType.PARTIAL:
							return BookSynonym.BOOK_TYPE_LEATHER;
							break;
						default: //case BookCoverPrintType.PHOTO:
							return BookSynonym.BOOK_TYPE_JOURNAL;
							//return BookSynonym.BOOK_TYPE_BOOK;
							break;
					}
				case FotocalendarProject.PROJECT_TYPE:
					return BookSynonym.BOOK_TYPE_CALENDAR;
					break;
				case FotocanvasProject.PROJECT_TYPE:
					return BookSynonym.BOOK_TYPE_CANVAS;
					break;
				case MagnetProject.PROJECT_TYPE:
					return BookSynonym.BOOK_TYPE_MAGNET;
					break;
				case PROJECT_TYPE_BCARD:
					return BookSynonym.BOOK_TYPE_BCARD;
					break;
				case FotocupProject.PROJECT_TYPE:
					return BookSynonym.BOOK_TYPE_CUP;
					break;
				default:
					return 0;
			}
		}

		public function get paperId():String{
			if(!project) return '1';//matovaya
			switch(type){
				case Book.PROJECT_TYPE:
					return (project as Book).template.paper.id.toString();
					break;
				/*
				case FotocalendarProject.PROJECT_TYPE:
					return '1';
					break;
				*/
				case MagnetProject.PROJECT_TYPE:
					return (project as MagnetProject).template.paperType.printId;
					break;
				case PROJECT_TYPE_BCARD:
					return (project as CardProject).getTemplate().paperType.printId;
					break;
				case FotocanvasProject.PROJECT_TYPE:
					return (project as FotocanvasProject).template.paperType.printId;
					break;
				default:
					return '1';
			}
		}

		public function get printAlias():String{
			if(!project) return '';
			switch(type){
				case Book.PROJECT_TYPE:
					return (project as Book).template.printAlias;
					break;
				case FotocalendarProject.PROJECT_TYPE:
					return (project as FotocalendarProject).template.printAlias;
					break;
				case MagnetProject.PROJECT_TYPE:
					return (project as MagnetProject).template.printAlias;
					break;
				case PROJECT_TYPE_BCARD:
					return (project as CardProject).getTemplate().printAlias;
					break;
				case FotocanvasProject.PROJECT_TYPE:
					return (project as FotocanvasProject).template.printAlias;
					break;
				case FotocupProject.PROJECT_TYPE:
					return (project as FotocupProject).template.printAlias;
					break;
				default:
					return '';
			}
		}

		public function bookInfo():String{
			if(!project) return null;
			switch(type){
				case Book.PROJECT_TYPE:
					return (project as Book).bookInfo().export();
					break;
				case FotocalendarProject.PROJECT_TYPE:
					//return (project as FotocalendarProject).pages;
					return '';
					break;
				default:
					return '';
			}
		}
		
		public function get bookPages():ArrayCollection{
			if(!project) return null;
			return (project as ProjectBook).pages;
			/*
			switch(type){
				case Book.PROJECT_TYPE:
				case FotocalendarProject.PROJECT_TYPE:
				case MagnetProject.PROJECT_TYPE:
				case FotocanvasProject.PROJECT_TYPE:
				case PROJECT_TYPE_BCARD:
					return (project as ProjectBook).pages;
					break;
				default:
					return null;
			}
			*/
		}
		
		
		public function adjustPageSizes(pageNum:int,pageSize:Point,pageOffset:Point):void{
			if(!project) return;
			switch(type){
				case Book.PROJECT_TYPE:
					var bp:Book=(project as Book);
					pageSize.x=bp.template.format.realWidth;
					pageSize.y=bp.template.format.realHeight;
					pageOffset.x=BookLayout.CUT_PADDING;
					pageOffset.y=BookLayout.CUT_PADDING;
					var bookPage:BookPage=bp.pages[pageNum] as BookPage;
					if(!bookPage) return; 
					var r:Rectangle;
					if (bookPage && bookPage.isCover){
						//get cover size & offset
						r=BookPage.getBackgroundRectByFormat(bp.template.format, bp.editorInfo as BookEditorInfo, bp.template.cover, bp.bindingWidth);
					}else{
						//block
						r=BookPage.getBackgroundRectByFormat(bp.template.format, bp.editorInfo as BookEditorInfo);
					}
					pageSize.x=r.size.x;
					pageSize.y=r.size.y;
					pageOffset.x=-r.x;
					pageOffset.y=-r.y;
					/*
					if (bookPage && bookPage.isCover){
						//get cover size & offset
						var r:Rectangle=BookPage.getBackgroundRectByFormat(bp.template.format,bp.template.cover, bp.bindingWidth);
						pageSize.x=r.size.x;
						pageSize.y=r.size.y;
						pageOffset.x=-r.x;
						pageOffset.y=-r.y;
					}
					*/
					break;
				case FotocalendarProject.PROJECT_TYPE:
					var cp:FotocalendarProject=(project as FotocalendarProject);
					pageSize.x=cp.template.format.realWidth;
					pageSize.y=cp.template.format.realHeight;
					pageOffset.x=0;
					pageOffset.y=0;
					break;
				case FotocanvasProject.PROJECT_TYPE:
					var ccp:FotocanvasProject=(project as FotocanvasProject);
					pageSize.x=ccp.template.format.realWidth;
					pageSize.y=ccp.template.format.realHeight;
					pageOffset.x=0;
					pageOffset.y=0;
					break;
				case MagnetProject.PROJECT_TYPE:
					var mp:MagnetProject=(project as MagnetProject);
					pageSize.x=mp.template.format.cellWidth;
					pageSize.y=mp.template.format.cellHeight;
					pageOffset.x=0;
					pageOffset.y=0;
					break;
				case PROJECT_TYPE_BCARD:
					var bcp:CardProject=(project as CardProject);
					pageSize.x=bcp.getTemplate().getFormat().cellWidth;
					pageSize.y=bcp.getTemplate().getFormat().cellHeight;
					pageOffset.x=0;
					pageOffset.y=0;
					break;
				case FotocupProject.PROJECT_TYPE:
					var fc:FotocupProject=(project as FotocupProject);
					pageSize.x=fc.template.format.realWidth;
					pageSize.y=fc.template.format.realHeight;
					pageOffset.x=0;
					pageOffset.y=0;
					break;
			}
		}
		
		public function isPageCover(pageNum:int):Boolean{
			if(!project || type!=Book.PROJECT_TYPE) return false;
			var bp:Book=(project as Book);
			var bookPage:BookPage=bp.pages[pageNum] as BookPage;
			if(!bookPage) return false;
			return bookPage.isCover;
		}
		
		public function isPageSliced(pageNum:int):Boolean{
			if(!project || type!=Book.PROJECT_TYPE) return false;
			var bp:Book=(project as Book);
			var bookPage:BookPage=bp.pages[pageNum] as BookPage;
			if(!bookPage) return false;
			return bookPage.isCover && bp.template.cover.printType==BookCoverPrintType.PARTIAL;
		}
		
		public function isPageEndPaper(pageNum:int):Boolean{
			if(!project || type!=Book.PROJECT_TYPE) return false;
			var bp:Book=(project as Book);
			var bookPage:BookPage=bp.pages[pageNum] as BookPage;
			if(!bookPage) return false;
			return pageNum==1 && bp.template.endpaper &&  bp.template.endpaper.inBook;
		}

		public function buttWidth():int{
			if(!project || type!=Book.PROJECT_TYPE) return 0;
			var bp:Book=(project as Book);
			return bp.bindingWidth;
		}

		public function getPixelSise(bookPart:int=0):Point{
			var result:Point;
			var page:PageData;
			if(bookType==BookSynonym.BOOK_TYPE_BOOK || bookType==BookSynonym.BOOK_TYPE_JOURNAL || bookType==BookSynonym.BOOK_TYPE_LEATHER){
				page=getCoverPage();
				if(bookPart==BookSynonym.BOOK_PART_BLOCK){
					page=projectPages[1] as PageData;
				}else if(bookPart==BookSynonym.BOOK_PART_COVER){
					if(isPageSliced(0) || bookType==BookSynonym.BOOK_TYPE_LEATHER) page= null;
				}else if(bookPart==BookSynonym.BOOK_PART_INSERT){
					if(page && isPageSliced(0)) return page.getSliceSize();
					page=null;
				}
			}else if(bookPart==BookSynonym.BOOK_PART_BLOCK){
				//set by first page in array
				page=projectPages[0] as PageData;
			}
			if(page){
				result= new Point(page.pageSize.x,page.pageSize.y);
			}
			return result;
		}
		
		private function getCoverPage():PageData{
			var result:PageData=null;
			var bp:Book=(project as Book);
			if(isPageCover(0) && bp.template.cover.printType!=BookCoverPrintType.EMPTY) result=ArrayUtil.searchItem('pageNum',0,projectPages) as PageData;
			return result; 
		}

		public function get log():String{
			return _log;
		} 
		public function set log(value:String):void{
			var dt:Date= new Date();
			var df:DateFormatter = new DateFormatter();
			df.formatString='DD.MM.YY J:NN:SS';
			if(_log){
				_log=_log +'\n'+ df.format(dt)+': '+value;
			}else{
				_log =df.format(dt)+': '+value;
			}
		}
		public function resetlog():void{
			_log ='';
		}

		public static function getWorkSubDirs():Array{
			return [SUBDIR_ART,SUBDIR_USER];
		}
		
		public static function get artSubDir():String{
			if (SUBDIR_ART){
				return SUBDIR_ART+File.separator;
			}
			return '';
		}
		
		public static function get userSubDir():String{
			if (SUBDIR_USER){
				return SUBDIR_USER+File.separator;
			}
			return '';
		}
		
		public function get formatName():String{
			if(!project) return '';
			var result:String='';
			switch(type){
				case Book.PROJECT_TYPE:
					result=(project as Book).template.format.name;
					break;
				case FotocalendarProject.PROJECT_TYPE:
					result=(project as FotocalendarProject).template.format.name;
					break;
				case MagnetProject.PROJECT_TYPE:
					result=(project as MagnetProject).template.format.name;
					break;
				case PROJECT_TYPE_BCARD:
					result=(project as CardProject).getTemplate().getFormat().name;
					break;
				case FotocanvasProject.PROJECT_TYPE:
					result=(project as FotocanvasProject).template.format.name;
					break;
				case FotocupProject.PROJECT_TYPE:
					result=(project as FotocupProject).template.format.name;
					break;
			}
			return result?result:'';
		}

		public function get coverName():String{
			if(!project) return '';
			var result:String='';
			switch(type){
				case Book.PROJECT_TYPE:
					var b:Book=(project as Book);
					if(b){
						result=b.template.cover.name;
						/*
						if(BookCoverPrintType.hasFabric(b.template.cover.printType)){
							result= result+' '+b.template.fabric.name;
						}
						*/
					}
					break;
			}
			return result?result:'';
		}
		public function get coverMaterial():String{
			if(!project) return '';
			var result:String='';
			switch(type){
				case Book.PROJECT_TYPE:
					var b:Book=(project as Book);
					if(b){
						if(BookCoverPrintType.hasFabric(b.template.cover.printType)){
							result= b.template.fabric.name;
						}
					}
					break;
			}
			return result?result:'';
		}

		public function get interlayerName():String{
			if(!project) return '';
			var result:String='';
			switch(type){
				case Book.PROJECT_TYPE:
					if((project as Book).template.interlayer){
						result=(project as Book).template.interlayer.alias;
						if(!result) result=(project as Book).template.interlayer.name;
						result=LayersetSynonym.translateInterlayer(result);
					}
					break;
			}
			return result?result:'';
		}

		public function get endpaperName():String{
			if(!project) return '';
			var result:String='';
			switch(type){
				case Book.PROJECT_TYPE:
					if((project as Book).template.endpaper){
						result=(project as Book).template.endpaper.alias;
						if(!result) result=(project as Book).template.endpaper.name;
						result=LayersetSynonym.translateEndPaper(result);
					}
					break;
			}
			return result?result:'';
		}

		public function get cornerTypeName():String{
			if(!project) return '';
			var result:String='';
			switch(type){
				case Book.PROJECT_TYPE:
					if((project as Book).template.corner){
						result=(project as Book).template.corner.name;
					}
					break;
			}
			return result?result:'';
		}

		public function toRaw():Object{
			var raw:Object= new Object;
			var arr:Array=[];
			var errItem:DownloadErrorItem;
			if(notLoadedItems){
				for each(errItem in notLoadedItems){
					arr.push(errItem.toRaw());
				}
			}
			raw.notLoadedItems=arr;
			raw.project=projectRaw;
			raw.downloadState=downloadState;//??
			
			return raw;
		}
		
		public static function fromRaw(raw:Object):FBookProject{
			if(!raw) return null;
			var fbp:FBookProject= new FBookProject();

			var errRaw:Object;
			var errItem:DownloadErrorItem;
			if(raw.hasOwnProperty('notLoadedItems') && raw.notLoadedItems is Array){
				fbp.notLoadedItems=[];
				for each(errRaw in raw.notLoadedItems){
					errItem=DownloadErrorItem.fromRaw(errRaw);
					if(errItem) fbp.notLoadedItems.push(errItem);
				}
			}

			if(raw.project) fbp.projectFromRaw(raw.project);
			fbp.downloadState=raw.downloadState;//??
			return fbp;
		}

	}
}