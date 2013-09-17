package com.photodispatcher.provider.fbook{
	import com.akmeful.fotakrama.canvas.CanvasUtil;
	import com.akmeful.fotakrama.data.Project;
	import com.akmeful.fotakrama.data.ProjectBook;
	import com.akmeful.fotakrama.data.ProjectBookPage;
	import com.akmeful.fotocalendar.data.FotocalendarProject;
	import com.akmeful.fotokniga.book.data.Book;
	import com.akmeful.fotokniga.book.data.BookCoverPrintType;
	import com.akmeful.fotokniga.book.data.BookPage;
	import com.akmeful.fotokniga.book.layout.BookLayout;
	import com.akmeful.magnet.data.MagnetProject;
	import com.photodispatcher.model.BookSynonym;
	import com.photodispatcher.provider.fbook.download.DownloadErrorItem;
	
	import flash.filesystem.File;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	
	import mx.collections.ArrayCollection;
	import mx.formatters.DateFormatter;

	public class FBookProject{
		public static const SUBDIR_WRK:String='wrk';
		public static const SUBDIR_ART:String='art';
		public static const SUBDIR_USER:String='usr';

		public var notLoadedItems:Array; //DownloadErrorItem
		public var projectPages:Array=[]; //PageData, has data after IMScrip.build 

		
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
			var p:Project=new Project(raw);
			var bp:ProjectBookPage;

			if(!p) return;
			switch(p.type){
				case Book.PROJECT_TYPE:
					var b:Book= new Book(raw);
					_project=b;
					break;
				case FotocalendarProject.PROJECT_TYPE:
					var c:FotocalendarProject= new FotocalendarProject(raw);
					_project=c;
					//uncompres content
					for each (bp in c.pages){
						if(bp && bp.content){
							bp.content=CanvasUtil.extractImportedContent(bp.content);
						}
					}
					break;
				case MagnetProject.PROJECT_TYPE:
					//magnet = createItem(rawData) as MagnetProject;
					var mp:MagnetProject= new MagnetProject(raw);
					_project=mp;
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
				default:
					return 'Неопределен';
			}
		}

		public function get bookType():int{
			if(!project) return 0;
			switch(type){
				case Book.PROJECT_TYPE:
					return BookSynonym.BOOK_TYPE_BOOK;
					break;
				case FotocalendarProject.PROJECT_TYPE:
					return BookSynonym.BOOK_TYPE_CALENDAR;
					break;
				case MagnetProject.PROJECT_TYPE:
					return BookSynonym.BOOK_TYPE_MAGNET;
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
				case FotocalendarProject.PROJECT_TYPE:
					return '1';
					break;
				case MagnetProject.PROJECT_TYPE:
					return (project as MagnetProject).template.paperType.printId;
					break;
				default:
					return '1';
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
			switch(type){
				case Book.PROJECT_TYPE:
					return (project as Book).pages;
					break;
				case FotocalendarProject.PROJECT_TYPE:
					return (project as FotocalendarProject).pages;
					break;
				case MagnetProject.PROJECT_TYPE:
					return (project as MagnetProject).pages;
					break;
				default:
					return null;
			}
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
					if (bookPage && bookPage.isCover){
						//get cover size & offset
						var r:Rectangle=BookPage.getBackgroundRectByFormat(bp.template.format,bp.template.cover, bp.bindingWidth);
						pageSize.x=r.size.x;
						pageSize.y=r.size.y;
						pageOffset.x=-r.x;
						pageOffset.y=-r.y;
					}
					break;
				case FotocalendarProject.PROJECT_TYPE:
					var cp:FotocalendarProject=(project as FotocalendarProject);
					pageSize.x=cp.template.format.realWidth;
					pageSize.y=cp.template.format.realHeight;
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

		[Bindable]
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