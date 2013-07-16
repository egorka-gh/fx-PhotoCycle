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
	
	import flash.filesystem.File;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	
	import mx.collections.ArrayCollection;
	import mx.formatters.DateFormatter;

	public class FBookProject{
		/*
		public static const STATE_NEW:int=0;
		public static const STATE_PREPARE:int=1;
		public static const STATE_PREPARE_COMLPETED:int=2;
		public static const STATE_PREPARE_ERROR:int=-2;
		public static const STATE_MAKEUP:int=3;
		public static const STATE_MAKEUP_COMLPETED:int=4;
		public static const STATE_MAKEUP_ERROR:int=-4;
		public static const STATE_PREVIEW_CHECK:int=5;
		public static const STATE_COMPLETED:int=7;
		*/
		
		public static const SUBDIR_WRK:String='wrk';
		public static const SUBDIR_ART:String='art';
		public static const SUBDIR_USER:String='usr';

		/*
		public var stateCaption:String;
		public var actionCaption:String;
		public var actionEnabled:Boolean;
		*/
		/*
		public var formatCaption:String;
		public var templateCaption:String;
		*/
		
		//public var pagesList:ArrayCollection= new ArrayCollection;
		//public var outFolder:String;
		//public var workFolder:String;
		
		public var notLoadedItems:Array; //DownloadErrorItem

		
		private var _log:String;
		private var _project:ProjectBook;
		public function get project():ProjectBook{
			return _project;
		}
		
		public var downloadState:int=TripleState.TRIPLE_STATE_NON;
		
		//private static var dummyId:int=1;
		//private var _scriptState:int=TripleState.TRIPLE_STATE_NON;
		//private var _textState:int=TripleState.TRIPLE_STATE_NON;
		//private var _makeState:int;
		//private var _state:int=-1;
		//private var _pagesData:Array;
		
		public function FBookProject(raw:Object){
			//super(raw);
			projectFromRaw(raw);
			//state=STATE_NEW;
		}
		
		private function projectFromRaw(raw:Object):void{
			var p:Project=new Project(raw);
			var bp:ProjectBookPage;

			if(!p) return;
			switch(p.type){
				case Book.PROJECT_TYPE:
					var b:Book= new Book(raw);
					_project=b;
					//formatCaption=b.template.format.realWidth.toString()+'x'+b.template.format.realHeight.toString();
					//templateCaption=b.template.format.name;
					break;
				case FotocalendarProject.PROJECT_TYPE:
					var c:FotocalendarProject= new FotocalendarProject(raw);
					_project=c;
					//formatCaption=c.template.format.realWidth.toString()+'x'+c.template.format.realHeight.toString();
					//templateCaption=c.template.format.name;
					//uncompres content
					for each (bp in c.pages){
						if(bp && bp.content){
							bp.content=CanvasUtil.extractImportedContent(bp.content);
						}
					}
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
				default:
					return 'Неопределен';
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
		
		public function get pages():ArrayCollection{
			if(!project) return null;
			switch(type){
				case Book.PROJECT_TYPE:
					return (project as Book).pages;
					break;
				case FotocalendarProject.PROJECT_TYPE:
					return (project as FotocalendarProject).pages;
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
			}
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

		/*
		[Bindable]
		public function get scriptState():int{
			return _scriptState;
		}
		public function set scriptState(value:int):void{
			_scriptState = value;
			validateState();
		}
		
		[Bindable]
		public function get downloadState():int{
			return _downloadState;
		}
		public function set downloadState(value:int):void{
			_downloadState = value;
			validateState();
		}
		
		[Bindable]
		public function get makeState():int{
			return _makeState;
		}
		public function set makeState(value:int):void{
			_makeState = value;
			validateState();
		}
		
		private function validateState():void{
			var newState:int=_state;
			var s:int;
			s=TripleState.getMinState([_downloadState,_scriptState,_textState]);
			if (s==TripleState.TRIPLE_STATE_ERR){
				newState=STATE_PREPARE_ERROR;
			}
			s=TripleState.getMinState([_downloadState,_scriptState,_textState]);
			if (s==TripleState.TRIPLE_STATE_OK 	|| s==TripleState.TRIPLE_STATE_WARNING){
				newState=STATE_PREPARE_COMLPETED;
			}
			if (_makeState==TripleState.TRIPLE_STATE_OK ){
				newState=STATE_MAKEUP_COMLPETED;
			}else if (_makeState==TripleState.TRIPLE_STATE_ERR ){
				newState=STATE_MAKEUP_ERROR;
			}
			
			state=newState;
		}
		*/
		
		/*
		[Bindable]
		public function get state():int{
			return _state;
		}
		public function set state(value:int):void{
			_state = value;
			//TODO refactor set state caption
			actionEnabled=false;
			switch(_state){
				case STATE_NEW:
					stateCaption='Новая книга';
					actionCaption='Подготовить';
					actionEnabled=true;
					break;
				case STATE_PREPARE:
					stateCaption='Подготовка книги';
					break;
				case STATE_PREPARE_COMLPETED:
					stateCaption='Подготовка книги завершена';
					actionCaption='Сформировать';
					actionEnabled=true;
					break;
				case STATE_PREPARE_ERROR:
					stateCaption='Ошибка подготовки книги';
					break;
				case STATE_MAKEUP:
					stateCaption='Формирование книги';
					break;
				case STATE_MAKEUP_COMLPETED:
					stateCaption='Формирование книги завершено';
					actionEnabled=true;
					makeState = TripleState.TRIPLE_STATE_OK;
					break;
				case STATE_MAKEUP_ERROR:
					stateCaption='Ошибка формирования книги';
					makeState = TripleState.TRIPLE_STATE_ERR;
					break;
			}
		}
		*/
		
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
		
		/*
		public function get pagesData():Array{
			return _pagesData;
		}
		public function set pagesData(value:Array):void{
			_pagesData = value;
			pagesList.source=_pagesData;
			//completedPagesList.source=_pagesData;
		}
		*/
		/*
		[Bindable]
		public function get textState():int{
			return _textState;
		}
		
		public function set textState(value:int):void{
			_textState = value;
			validateState();
		}
		*/

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

	}
}