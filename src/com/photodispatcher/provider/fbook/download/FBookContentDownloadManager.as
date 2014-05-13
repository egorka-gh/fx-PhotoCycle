package com.photodispatcher.provider.fbook.download{
	import br.com.stimuli.loading.BulkLoader;
	import br.com.stimuli.loading.BulkProgressEvent;
	import br.com.stimuli.loading.loadingtypes.LoadingItem;
	
	import com.adobe.protocols.dict.events.ErrorEvent;
	import com.akmeful.fotakrama.canvas.content.CanvasFrameImage;
	import com.akmeful.fotakrama.canvas.content.CanvasFrameMaskedImage;
	import com.akmeful.fotakrama.canvas.content.CanvasPhotoBackgroundImage;
	import com.akmeful.fotakrama.canvas.content.CanvasText;
	import com.akmeful.fotakrama.canvas.text.CanvasTextStyle;
	import com.akmeful.fotakrama.data.ProjectBookPage;
	import com.akmeful.fotakrama.library.LibraryPath;
	import com.akmeful.fotakrama.library.data.ClipartType;
	import com.akmeful.fotakrama.project.ProjectNS;
	import com.akmeful.fotokniga.book.contentClasses.BookCoverFrameImage;
	import com.photodispatcher.event.ImageProviderEvent;
	import com.photodispatcher.model.SourceService;
	import com.photodispatcher.provider.fbook.FBookProject;
	import com.photodispatcher.provider.fbook.TripleState;
	import com.photodispatcher.provider.fbook.model.FrameData;
	import com.photodispatcher.util.JsonUtil;
	
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
		//public static const USER_MEDIA_PATH:String = 'book/photo/download/';
		public static const USER_MEDIA_PATH:String = 'projectImage/download';
		public static const CLIPART_PATH:String = 'admin/clipart/download/';
		public static const USER_CLIPART_PATH:String = 'project/user/clipart/download/';
		public static const CLIPART_FRAME_PATH:String = 'admin/frames/download/';

		public static const CONTENT_CLIPART_IMG:String = ClipartType.IMG;
		public static const CONTENT_CLIPART_BG:String = ClipartType.BG;
		public static const CONTENT_CLIPART_FILL:String =  ClipartType.FILL;
		public static const CONTENT_TEXT_TYPE:String = CanvasText.TYPE; 
		public static const CONTENT_FRAME_ELEMENT:String = 'frame_element';
		public static const CONTENT_FRAME_IMG:String = 'frame_img';
		public static const CONTENT_PHOTO_BG:String =  CanvasPhotoBackgroundImage.TYPE;
		public static const CONTENT_FRAME_MASKED_IMAGE:String =  CanvasFrameMaskedImage.TYPE;

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
		private var bytesLoaded:int=0;
		private var startTime:Date;
		private var lastItemsLoaded:int=0;
		private var fontMap:Object;

		public function FBookContentDownloadManager(service:SourceService, book:FBookProject){
			//TODO implement cache
			super(null);
			this.service=service;
			this.book=book;
		}

		private function prepare():void{
			fontMap= new Object();
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
								req=createRequest(name,clipartPath(name),pageNum);
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
							case CanvasFrameMaskedImage.TYPE:
								if(contentElement.iId){
									name=contentElement.iId;
									//req=createRequest(name,MediaPath.userImagePath(),pageNum);
									req=createRequest(name,userImagePath(),pageNum);
									if(req){
										//save to user subdir
										name=FBookProject.userSubDir+name;
										loader.add(req,{id: name, type:BulkLoader.TYPE_BINARY, content_type:CONTENT_FRAME_MASKED_IMAGE, content_id:contentElement.iId});
									}
									if(contentElement.size){
										var maskElement:Object = JsonUtil.decode(contentElement.size);
										name=maskElement.id;
										req=createRequest(name,clipartPath(name),pageNum);
										//req=createClipartRequest(name,pageNum);
										if(req){
											//save to art subdir
											name=FBookProject.artSubDir+name;
											loader.add(req,{id:name, type:BulkLoader.TYPE_BINARY, content_type:ClipartType.MASK, content_id:maskElement.id});
										}
									}
								}
								break;
							case CanvasText.TYPE: //BookText.TYPE:
								//fonts to load list 
								if (contentElement.hasOwnProperty('index') 
									&& contentElement.transform && contentElement.text 
									&& contentElement.w>0 && contentElement.h){
									//check text is not default, user made some changes or txt is calendar date
									if (!contentElement.hasOwnProperty('print') || contentElement.print!=0 || contentElement.hasOwnProperty('aid')){
										var ts:CanvasTextStyle;
										if(contentElement.hasOwnProperty('style')){
											ts = new CanvasTextStyle(contentElement.style);
										} else {
											ts = CanvasTextStyle.defaultTextStyle();
										}
										if(ts.fontFamily){
											if(!FontDownloadManager.instance.hasFont(ts.fontFamily, ts.isBold, ts.isItalic)){
												fontMap[ts.fontFamily]=ts;
												//book.log='Page# '+pageNum+'. Request font : '+ts.fontFamily;
												//trace('Page# '+pageNum+'. Request font : '+ts.fontFamily);
												req=createFontRequest(ts.fontFamily, pageNum);
												if(req){
													//save to user subdir
													//name=MakeupConfig.userSubDir+ts.fontFamily+'.swf';
													name=ts.fontFamily;
													loader.add(req,{id: name, type:BulkLoader.TYPE_BINARY, content_type:CanvasText.TYPE, content_id: name});
												}
												
											}
										}
									}
								}
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
			var itemId:String=name;
			/*
			var arr:Array=itemId.split('::');
			if(arr.length > 1 && arr[0]==ProjectNS.SUP){
				itemId=arr[1];
			}
			*/
			var ns:Array = LibraryPath.extractNamespace(itemId);
			var secure:String;
			if(ns[0]){
				secure = book.project.valueForNS(ns[0]) as String;
			}
			itemId=ns[1];
			
			itemId=name.split('.')[0];
			var param:URLVariables=new URLVariables;
			param.id=itemId;
			if(secure){
				param.secure=secure;
			}else{
				param.project_id=book.id;
			}
			if(corner){
				param.corner=corner;
			}
			result=new URLRequest();
			result.url = url;
			result.method = URLRequestMethod.POST;
			result.data = param;
			book.log='Page# '+pageNum+'. Request url: '+url+'; POST id:'+itemId+';  corner:'+corner+';  secure:'+secure;
			trace('Page# '+pageNum+'. Request url: '+url+'; POST id:'+itemId+';  corner:'+corner+';  secure:'+secure);
			return result;
		}

		private function createFontRequest(name:String, pageNum:int):URLRequest{
			if(!name){
				return null;
			}
			var result:URLRequest;
			var url:String=getBaseURL()+FontDownloadManager.instance.getPackUrl(name);
			result=new URLRequest();
			result.url = url;
			book.log='Page# '+pageNum+'. Request font url: '+url;
			trace('Page# '+pageNum+'. Request font url: '+url);
			return result;
		}

		public function userImagePath():String {
			return getBaseURL()+USER_MEDIA_PATH;
		}
		public function clipartPath(itemId:String):String {	
			var ns:Array = LibraryPath.extractNamespace(itemId);
			if(ns[0]){
				return getBaseURL()+USER_CLIPART_PATH;
			}
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
			bytesLoaded=0;
			startTime= new Date();
			book.notLoadedItems=[];
			dispatchEvent(new ProgressEvent(ProgressEvent.PROGRESS,false,false,_totalLoaded, _itemsToLoad));
			if (_itemsToLoad==0){
				allLoadCompleted(null);
			}else{
				loader.start();
			}
		}
		
		public function stop():void{
			listenLoader=false;
			bytesLoaded=0;
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
					bytesLoaded+=ba.length;
					if(item.properties['content_type']==CanvasText.TYPE){
						FontDownloadManager.instance.addPackpackBinary(item.id,ba);
						book.log='Book id:'+book.id+'. Font bynary downloaded: '+item.id;
					}else{
						var file:File=workFolder.resolvePath(item.id);
						trace('Save downloaded file: '+file.nativePath+'.');
						var fs:FileStream = new FileStream();
						fs.open(file, FileMode.WRITE);
						fs.writeBytes(ba);
						fs.close();
						book.log='Book id:'+book.id+'. File downloaded: '+file.nativePath;
					}
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
			//finalizeLoad();
			loadFonts();
		}
		
		private function loadFonts():void{
			book.log='Book id:'+book.id+'. Load fonts.';
			var ts:CanvasTextStyle;
			var fonts:Array=[];
			for each (ts in fontMap){
				if(ts) fonts.push(ts);
			}
			var fontLoader:FontDownloadManager=FontDownloadManager.instance;
			fontLoader.addEventListener(Event.COMPLETE, fontsLoaded);
			fontLoader.loadBatch(fonts);
		}
		
		private function fontsLoaded(evt:Event):void{
			var fontLoader:FontDownloadManager=FontDownloadManager.instance;
			fontLoader.removeEventListener(Event.COMPLETE, fontsLoaded);
			if (fontLoader.hasError){
				trace('font load error. font:'+fontLoader.errorFont+'; err:'+fontLoader.errorString);
				book.log='Book id:'+book.id+'. Font:"'+fontLoader.errorFont+'". Load error: '+fontLoader.errorString;
				_hasError=true;
				errType='IOError';
				errText = fontLoader.errorString;
				
				var errItm:DownloadErrorItem= new DownloadErrorItem(ProcessingErrors.DOWNLOAD_FONT_ERROR);
				errItm.path=fontLoader.errorFont;
				errItm.content_type='Text';
				errItm.id=fontLoader.errorFont;
				book.notLoadedItems.push(errItm);
			}else{
				book.log='Book id:'+book.id+'. Fonts loaded.';
			}
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
			bytesLoaded=0;
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

		public function get speed():Number{
			if (!bytesLoaded) return 0;
			var now:Date=new Date();
			var speed:Number=0;
			speed=bytesLoaded/((now.time-startTime.time)/1000);//byte /sek
			speed=Math.round(speed/1024);//Kb /sek
			return speed;
		}

	}
}