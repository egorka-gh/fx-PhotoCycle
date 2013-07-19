package com.photodispatcher.provider.fbook.download{
	import br.com.stimuli.loading.BulkLoader;
	import br.com.stimuli.loading.BulkProgressEvent;
	import br.com.stimuli.loading.loadingtypes.LoadingItem;
	
	import com.adobe.protocols.dict.events.ErrorEvent;
	import com.akmeful.fotakrama.canvas.content.CanvasFrameImage;
	import com.akmeful.fotakrama.canvas.content.CanvasPhotoBackgroundImage;
	import com.akmeful.fotakrama.canvas.content.CanvasText;
	import com.akmeful.fotakrama.data.ProjectBookPage;
	import com.akmeful.fotakrama.library.data.ClipartType;
	import com.akmeful.fotokniga.book.contentClasses.BookCoverFrameImage;
	import com.photodispatcher.event.ImageProviderEvent;
	import com.photodispatcher.model.SourceService;
	import com.photodispatcher.provider.fbook.FBookProject;
	import com.photodispatcher.provider.fbook.TripleState;
	import com.photodispatcher.provider.fbook.data.FrameData;
	
	import flash.errors.IOError;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.net.URLRequest;
	import flash.net.URLRequestMethod;
	import flash.net.URLVariables;
	import flash.utils.ByteArray;
	
	[Event(name="progress", type="flash.events.ProgressEvent")]
	[Event(name="complete", type="flash.events.Event")]
	[Event(name="flowError", type="com.photodispatcher.event.ImageProviderEvent")]
	public class FBookContentDownloadManager extends EventDispatcher{
		public static const USER_MEDIA_PATH:String = 'book/photo/download/';
		public static const CLIPART_PATH:String = 'admin/clipart/download/';
		public static const CLIPART_FRAME_PATH:String = 'admin/frames/download/';

		public static const CONTENT_CLIPART_IMG:String = ClipartType.IMG;
		public static const CONTENT_CLIPART_BG:String = ClipartType.BG;
		public static const CONTENT_CLIPART_FILL:String =  ClipartType.FILL;
		public static const CONTENT_TEXT_TYPE:String = CanvasText.TYPE; 
		public static const CONTENT_FRAME_ELEMENT:String = 'frame_element';
		public static const CONTENT_FRAME_IMG:String = 'frame_img';
		public static const CONTENT_PHOTO_BG:String =  CanvasPhotoBackgroundImage.TYPE;

		private var service:SourceService;
		private var book:FBookProject;
		//private var workFolder:String;
		private var loader:BulkLoader;
		private var _itemsToLoad:int=0;
		private var _totalLoaded:int=0;
		
		//store error vars
		private var _hasError:Boolean;
		//private var _errorItems:Array=[];
		private var errType:String;
		private var errText:String;
		//private var numConnections:int;

		public function FBookContentDownloadManager(service:SourceService, book:FBookProject){
			//TODO implement cache
			super(null);
			this.service=service;
			this.book=book;
		}

		private function prepare():void{
			var pageNum:int=0;
			//chek and clear loader if exists vs same id
			var loaderId:String=service.src_id.toString()+'.'+service.srvc_id+'.'+book.id.toString()
			var l:BulkLoader=BulkLoader.getLoader(loaderId);
			if(l){
				l.clear();
				loader=l;
			}else{
				loader= new BulkLoader(loaderId,service.connections);
			}
			book.log='Book id:'+book.id+'.Prepare download.';

			for each (var bp:ProjectBookPage in book.bookPages){
				//TODO element as Class?
				for each (var contentElement:Object in bp.content){
					if(contentElement.hasOwnProperty('type')){
						var name:String;
						var req:URLRequest;
						switch(contentElement.type){
							case ClipartType.BG:
							case ClipartType.FILL:
							case ClipartType.IMG:
								//TODO refactor to addLoadingItem + implement cache
								name=contentElement.id;
								req=createRequest(name,clipartPath(),pageNum);
								if(req){
									//save to art subdir
									name=FBookProject.artSubDir+name;
									loader.add(req,{id:name, type:BulkLoader.TYPE_BINARY, content_type:contentElement.type, content_id:contentElement.id});
									//loader.add(req,{id:name, type:BulkLoader.TYPE_TEXT, content_type:contentElement.type, content_id:contentElement.id});
								}
								break;
							case CanvasPhotoBackgroundImage.TYPE: //BookPhotoBackgroundImage.TYPE:
								name=contentElement.id;
								req=createRequest(name,userImagePath(),pageNum);
								if(req){
									//save to user subdir
									name=FBookProject.userSubDir+name;
									loader.add(req,{id: name, type:BulkLoader.TYPE_BINARY, content_type:CONTENT_PHOTO_BG, content_id:contentElement.id});
								}
								break;
							case BookCoverFrameImage.TYPE:
								//cover frame (sliced cover)
								//process as BookFrameImage 
							case CanvasFrameImage.TYPE: 
								//TODO id==0 no frame images?
								if(contentElement.id && contentElement.id!='0'){
									name=contentElement.id;
									for each(var el:String in FrameData.FRAME_ELEMENTS){
										req=createRequest(name,framePath(),pageNum,el);
										if(req){
											//save to art subdir
											var sub_name:String= FBookProject.artSubDir+name+FrameData.getFileNameSufix(el);
											//var fileSufix:String=FrameData.getFileNameSufix(el);
											loader.add(req, {id: sub_name, type:BulkLoader.TYPE_BINARY, content_type:CONTENT_FRAME_ELEMENT, content_id:contentElement.id});
											//loader.add(req, {id: name, type:BulkLoader.TYPE_TEXT});
										}
									}
								}
								//load frame photo
								if(contentElement.iId){
									name=contentElement.iId;
									req=createRequest(name,userImagePath(),pageNum);
									if(req){
										//save to user subdir
										name=FBookProject.userSubDir+name;
										loader.add(req,{id: name, type:BulkLoader.TYPE_BINARY, content_type:CONTENT_FRAME_IMG, content_id:contentElement.iId});
									}
								}
								break;
							case CanvasText.TYPE: //BookText.TYPE:
								break;
							default:
								trace('unrecognized contentElement: '+contentElement.type);
						}
					}
				}
				pageNum++;
			}
			_itemsToLoad=loader.itemsTotal;
			trace('ContentDownloadManager itemsToLoad: ' +_itemsToLoad.toString());
			_totalLoaded=0;
		}
		
		private function createRequest(name:String, url:String, pageNum:int, corner:String=''):URLRequest{
			var result:URLRequest;
			if(!name){
				return null;
			}
			var itemId:String=name.split('.')[0];
			var param:URLVariables=new URLVariables;
			param.id=itemId;
			param.project_id=book.id;
			if(corner){
				param.corner=corner;
			}
			result=new URLRequest();
			result.url = url;
			result.method = URLRequestMethod.POST;
			result.data = param;
			book.log='Page# '+pageNum+'. Request url: '+url+'. POST id:'+itemId+'  corner:'+corner;
			trace('Page# '+pageNum+'. Request url: '+url+'. POST id:'+itemId+'  corner:'+corner);
			return result;
		}


		public function userImagePath():String {
			return getBaseURL()+USER_MEDIA_PATH;
		}
		public function clipartPath():String {			
			return getBaseURL()+CLIPART_PATH;
		}
		public function framePath():String {			
			return getBaseURL()+CLIPART_FRAME_PATH;
		}
		private function getBaseURL():String {
			return service.url;
		}

		private var workFolder:File;
		public function start(workFolder:File):void{
			if (!service || !book || !workFolder || service.connections<=0){
				dispatchEvent(new ImageProviderEvent(ImageProviderEvent.FLOW_ERROR_EVENT,null,'Ошибка инициализации FBookContentDownloadManager.start'));
				return;
			}
			this.workFolder=workFolder;
			prepare();
			book.log='Book id:'+book.id+'.Start download.';
			listenLoader=true;
			lastItemsLoaded=0;
			_totalLoaded=0;
			book.notLoadedItems=[];
			dispatchEvent(new ProgressEvent(ProgressEvent.PROGRESS,false,false,_totalLoaded, _itemsToLoad));
			loader.start();
		}
		
		public function stop():void{
			listenLoader=false;
			loader.pauseAll();
			loader.clear();
			dispatchEvent(new ProgressEvent(ProgressEvent.PROGRESS,false,false,0, 0));
		}
		
		private function set listenLoader(listen:Boolean):void{
			if (listen){
				loader.addEventListener(BulkLoader.COMPLETE,allLoadCompleted);
				loader.addEventListener(ErrorEvent.ERROR,onLoadError);
				loader.addEventListener(BulkProgressEvent.PROGRESS,onLoadProgress);
			}else{
				loader.removeEventListener(BulkLoader.COMPLETE,allLoadCompleted);
				loader.removeEventListener(ErrorEvent.ERROR,onLoadError);
				loader.removeEventListener(BulkProgressEvent.PROGRESS,onLoadProgress);
			}
		}
		
		
		private function onLoadError(event:flash.events.ErrorEvent):void{
			var l:BulkLoader=event.target as BulkLoader;
			
			book.log='Book id:'+book.id+'. Error download url:'+event.text;
			trace (event); // outputs more information
			errType='Download Error';
			errText=event.text;

			//don't stop on load err 16.04.2012
			//_hasError=true;
			//look up items vs error
			var item:LoadingItem;
			var allItms:Array=loader.items;
			var errItms:Array=[];
			for each (item in allItms){
				if (!item) continue;
				if(item.status == LoadingItem.STATUS_ERROR){
					errItms.push(item);
				}
			}
			
			if (errItms.length>0){
				//save err item & remove from loader
				for each (item in errItms){
					if (!item) continue;
					var errItm:DownloadErrorItem= new DownloadErrorItem(ProcessingErrors.DOWNLOAD_DOWNLOAD_ERROR);
					var p:Object=item.properties;
					errItm.path=p['id'];
					errItm.content_type=p['content_type'];
					errItm.id=p['content_id'];
					book.notLoadedItems.push(errItm);
					loader.remove(item);
				}
				_totalLoaded+=errItms.length;
				//dispatch events
				dispatchEvent(new ProgressEvent(ProgressEvent.PROGRESS,false,false,_totalLoaded, _itemsToLoad));
				//dispatchEvent(new ItemDownloadedEvent(errItms.length));
			}
			
			return;
		}
		
		private var lastItemsLoaded:int=0;
		private function onLoadProgress(event:BulkProgressEvent):void{
			var itmsLoaded:int= loader.itemsLoaded;
			var item:LoadingItem;
			if (itmsLoaded>0){
				//get downloaded
				var allItms:Array=loader.items;
				var loadedItms:Array=[];
				for each (item in allItms){
					if (!item) continue;
					if(item.status == LoadingItem.STATUS_FINISHED){
						loadedItms.push(item);
					}
				}
				itmsLoaded=loadedItms.length;
				if (itmsLoaded>0){
					//save
					for each (item in loadedItms){
						if (!item) continue;
						saveDownloadedItem(item);
					}
					//check err
					if (_hasError){
						listenLoader=false;
						if (loader.isRunning){
							loader.pauseAll();
						}
						finalizeLoad();
					}else{
						if(loader.items.length==loadedItms.length){
							//stop listen
							//loader.remove - will dispatch allComplete 4 each removed item
							listenLoader=false;
						}
						//kill loaded
						for each (item in loadedItms){
							if (!item) continue;
							loader.remove(item);
						}
						_totalLoaded+=itmsLoaded;
						//dispatch events
						dispatchEvent(new ProgressEvent(ProgressEvent.PROGRESS,false,false,_totalLoaded, _itemsToLoad));
						//dispatchEvent(new ItemDownloadedEvent(itmsLoaded));
						//if loader empty - complete
						if(!loader.items || loader.items.length==0){
							//completed
							allLoadCompleted(null);
						}
					}
				}
			}
		}
		
		private function saveDownloadedItem(item:LoadingItem):Boolean{
			//TODO check 4 zero lenth item.content -> DOWNLOAD_EMPTY_RESPONCE_ERROR
			var result:Boolean=true;
			var errItm:DownloadErrorItem;
			var p:Object;
			try{
				var ba:ByteArray=item.content;
				if(ba.length>0){
					var file:File=workFolder.resolvePath(item.id);
					trace('Save downloaded file: '+file.nativePath+'.');
					var fs:FileStream = new FileStream();
					fs.open(file, FileMode.WRITE);
					fs.writeBytes(ba);
					fs.close();
					book.log='Book id:'+book.id+'. File downloaded: '+file.nativePath;
				}else{
					result=false;
					trace('ContentDownloadManager empty response: '+item.id);
					book.log='Book id:'+book.id+'. item:'+item.id+'. Save downloaded file error: empty response.';
					_hasError=true;
					errType='IOError';
					errText = 'empty response';
					
					errItm=new DownloadErrorItem(ProcessingErrors.DOWNLOAD_EMPTY_RESPONCE_ERROR);
					p=item.properties;
					errItm.path=p['id'];
					errItm.content_type=p['content_type'];
					errItm.id=p['content_id'];
					book.notLoadedItems.push(errItm);
					
				}
			}catch (err:IOError){
				result=false;
				trace('file write error. file:'+file.nativePath+'; err:'+err.message);
				book.log='Book id:'+book.id+'. File:'+file.nativePath+'. Save downloaded file error:'+err.message;
				_hasError=true;
				errType='IOError';
				errText = err.message;
				
				errItm= new DownloadErrorItem(ProcessingErrors.DOWNLOAD_FILESYSTEM_ERROR);
				p=item.properties;
				errItm.path=p['id'];
				errItm.content_type=p['content_type'];
				errItm.id=p['content_id'];
				book.notLoadedItems.push(errItm);
			}
			return result;
		}
		
		private function allLoadCompleted(event:Event):void{
			book.log='Book id:'+book.id+'. Download complited.';
			trace('Book id:'+book.id+'. Download complited.');
			finalizeLoad();
		}
		
		private function finalizeLoad():void{
			if (!hasError){
				book.downloadState=TripleState.TRIPLE_STATE_OK;
			}else if(!hasFatalError()){
				book.downloadState=TripleState.TRIPLE_STATE_WARNING;
			}else{
				book.downloadState=TripleState.TRIPLE_STATE_ERR;
			}
			listenLoader=false;
			loader.clear();
			dispatchEvent(new ProgressEvent(ProgressEvent.PROGRESS,false,false,0, 0));
			dispatchEvent(new Event(Event.COMPLETE));
		}
		
		public function get itemsToLoad():int{
			return _itemsToLoad;
		}
		
		public function get hasError():Boolean{
			return book.notLoadedItems.length>0;
		}
		public function get errorItems():Array{
			return book.notLoadedItems;
		}

		public function hasFatalError():Boolean{
			if(!errorItems || errorItems.length==0){
				return false;
			}
			if(_itemsToLoad>0 && errorItems.length==_itemsToLoad) return true;
			
			var errItm:DownloadErrorItem;
			for each(errItm in errorItems){
				//if (!errItm) continue;
				if (errItm && ProcessingErrors.isFatalError(errItm.err)){
					return true;
				}
			}
			return false;
		}
		public function get errorText():String{
			if (!errType && !errText) return '';
			return errType+':'+errText;
		}

	}
}