package com.photodispatcher.provider.fbook.makeup{
	import com.akmeful.fotakrama.canvas.content.CanvasText;
	import com.akmeful.fotakrama.data.ProjectBookPage;
	import com.photodispatcher.event.ImageProviderEvent;
	import com.photodispatcher.model.OrderState;
	import com.photodispatcher.provider.fbook.FBookProject;
	
	import flash.display.BitmapData;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.utils.ByteArray;
	
	import mx.core.FlexGlobals;
	import mx.events.FlexEvent;
	import mx.graphics.codec.PNGEncoder;
	
	import spark.components.Group;
	import spark.components.WindowedApplication;
	
	[Event(name="complete", type="flash.events.Event")]
	[Event(name="flowError", type="com.photodispatcher.event.ImageProviderEvent")]
	[Event(name="progress", type="flash.events.ProgressEvent")]
	public class TextImageBuilder extends EventDispatcher{
		
		private var renderContainer:Group;

		public function get hasError():Boolean{
			return errNum<0;
		}

		public function get error():int{
			return errNum;
		}
		public function get errorMesage():String{
			if(errNum>=0){
				return '';
			}
			return errText; 
		}

		private var book:FBookProject;
		private var workFolder:File;
		private var errNum:int=0;
		private var errText:String;
		private var textItems:Array;
		private var rendered:int;
		private var filesSaved:int=0;
		private var rendererHolder:Group;

		public function TextImageBuilder(book:FBookProject,renderContainer:Group=null){
			super(null);
			this.book=book;
			this.renderContainer=renderContainer;
		}
		
		public function build(workFolder:File):Boolean{
			//TODO check if top level app is visible

			//if(!book || !book.pages || !renderContainer || !workFolder){
			if(!book || !book.pages  || !workFolder){
				dispatchEvent(new ImageProviderEvent(ImageProviderEvent.FLOW_ERROR_EVENT,null,'Ошибка инициализации TextImageBuilder.build'));
				return false;
			}
			
			// create renderContainer & add to top level app
			createRender();
			
			if(!renderContainer){
				dispatchEvent(new ImageProviderEvent(ImageProviderEvent.FLOW_ERROR_EVENT,null,'Ошибка инициализации TextImageBuilder.build'));
				return false;
			}

			this.workFolder=workFolder;

			errNum=0;
			prepare();
			if (!textItems || !textItems.length){
				destroyRender();
				dispatchEvent(new Event(Event.COMPLETE));
				return true;
			}
			book.log='Book id:'+book.id+'. Text render started. Items to proccess:'+textItems.length;
			startRender();
			return true;
		}
		
		private function createRender():void{
			/*
			<s:Group width="3" height="3" clipAndEnableScrolling="true">
				<s:Group id="textRender" minWidth="22" minHeight="22" >
				</s:Group>
			</s:Group>
			*/
			if(!renderContainer){
				rendererHolder=new Group();
				rendererHolder.width=3;
				rendererHolder.height=3;
				rendererHolder.clipAndEnableScrolling=true;
				var app:WindowedApplication=FlexGlobals.topLevelApplication as WindowedApplication;
				if(app){
					app.addElement(rendererHolder);
					renderContainer=new Group();
					renderContainer.minWidth=22;
					renderContainer.minHeight=22;
					rendererHolder.addElement(renderContainer);
				}else{
					rendererHolder=null;
				}
			}
		}

		private function destroyRender():void{
			if(rendererHolder){
				var app:WindowedApplication=FlexGlobals.topLevelApplication as WindowedApplication;
				if(app){
					app.removeElement(rendererHolder);
					rendererHolder.removeAllElements();
				}
				rendererHolder=null;
				renderContainer=null;
			}
		}

		private function prepare():void{
			textItems=[];
			var pageNum:int=0;
			
			for each (var page:ProjectBookPage in book.pages){
				for each (var contentElement:Object in page.content){
					if (contentElement.type==CanvasText.TYPE){
						if (contentElement.hasOwnProperty('index') 
							&& contentElement.transform && contentElement.text 
							&& contentElement.w>0 && contentElement.h){
							//check text is not default, user made some changes or txt is calendar date
							if (!contentElement.hasOwnProperty('print') || contentElement.print!=0 || contentElement.hasOwnProperty('aid')){
								var bt:CanvasText= new CanvasText();
								bt.importRaw(contentElement);
								//TODO hardcoded t_[pageNum]_[index].png
								bt.fileName='t_'+pageNum.toString()+'_'+contentElement.index+'.png';
								bt.x=0; bt.y=0; 
								textItems.push(bt);
							}
						}
					}
				}
				pageNum++;
			}
			book.log='Book id:'+book.id+' has '+textItems.length+' texts.';
		}
		
		private function startRender():void{
			rendered=0;
			filesSaved=0;
			if (!textItems || textItems.length==0){
				dispatchEvent(new Event(Event.COMPLETE));
				return;
			}
			dispatchEvent(new ProgressEvent(ProgressEvent.PROGRESS,false,false,filesSaved, textItems.length));
			renderNext();
		}

		private var currentBookText:CanvasText;
		
		private function renderNext():void{
			renderContainer.removeAllElements();
			currentBookText=textItems[rendered] as CanvasText;
			
			//add top offset 4 Й & gorizontal offset 4 italic (=fontsize)
			currentBookText.x=currentBookText.getStyle('fontSize');;
			currentBookText.y=currentBookText.getStyle('fontSize');
			
			renderContainer.addEventListener(FlexEvent.UPDATE_COMPLETE,textRenderHandler);
			renderContainer.addElement(currentBookText);
		}
		
		private function textRenderHandler(event:FlexEvent):void{
			renderContainer.removeEventListener(FlexEvent.UPDATE_COMPLETE,textRenderHandler);
			rendered++;
			var bd:BitmapData= new BitmapData(renderContainer.contentWidth+currentBookText.getStyle('fontSize'), renderContainer.contentHeight,true,0x00ffffff);
			try{
				bd.draw(renderContainer);
			}catch (e:Error){
				book.log='Book id:'+book.id+'. Draw text bitmap error:'+e.message;
				errNum=OrderState.ERR_PREPROCESS;
				errText = 'Draw text bitmap error:'+e.message;
				destroyRender();
				dispatchEvent(new Event(Event.COMPLETE));
				return;
			}
			var encoder:PNGEncoder= new PNGEncoder();
			var imgByteArr:ByteArray = encoder.encode(bd);
			var file:File= workFolder.resolvePath(currentBookText.fileName); 
			book.log='Book id:'+book.id+'. Save text bitmap "'+currentBookText.text+'". File:'+file.nativePath;
			var fs:FileStream = new FileStream();
			fs.addEventListener(Event.CLOSE,fileSaved);
			fs.addEventListener(IOErrorEvent.IO_ERROR,fileSaveError);
			fs.openAsync(file, FileMode.WRITE);
			fs.writeBytes(imgByteArr);
			fs.close();
			
			if(rendered == textItems.length){
				book.log='Book id:'+book.id+'. All texts rendered.';
			}else{
				renderNext();
			}
			
		}
		
		private function fileSaved(event:Event):void{
			var fs:FileStream= (event.target as FileStream);
			fs.removeEventListener(Event.CLOSE,fileSaved);
			fs.removeEventListener(IOErrorEvent.IO_ERROR,fileSaveError);
			filesSaved++;
			if(filesSaved==textItems.length){
				//complited
				book.log='Book id:'+book.id+'. All text bitmaps saved.';
				destroyRender();
				dispatchEvent(new Event(Event.COMPLETE));
				dispatchEvent(new ProgressEvent(ProgressEvent.PROGRESS,false,false,0,0));
			}else{
				dispatchEvent(new ProgressEvent(ProgressEvent.PROGRESS,false,false,filesSaved, textItems.length));
			}
		}
		
		private function fileSaveError(event:IOErrorEvent):void{
			var fs:FileStream= (event.target as FileStream);
			fs.removeEventListener(Event.CLOSE,fileSaved);
			fs.removeEventListener(IOErrorEvent.IO_ERROR,fileSaveError);
			filesSaved++;
			trace (event); 	
			book.log='Book id:'+book.id+'. Save text bitmap error:'+event.text;
			errNum=OrderState.ERR_FILE_SYSTEM;
			errText = event.text;
			destroyRender();
			dispatchEvent(new Event(Event.COMPLETE));
		}
		
		/*
		private function bookTextRenderHandler(event:Event):void{
		var bt:CanvasText; //BookText;
		if (event.target is CanvasText){ // BookText){
		rendered++;
		bt=event.target as CanvasText; //BookText);
		bt.removeEventListener(Event.RENDER,bookTextRenderHandler);
		var bd:BitmapData= new BitmapData(bt.width, bt.height,true,0x00ffffff);
		bd.draw(bt);
		var encoder:PNGEncoder= new PNGEncoder();
		var imgByteArr:ByteArray = encoder.encode(bd);
		var file:File= new File(book.workFolder);
		file=file.resolvePath(bt.fileName);
		book.log='Book id:'+book.id+'. Save text bitmap "'+bt.text+'". File:'+file.nativePath;
		var fs:FileStream = new FileStream();
		fs.addEventListener(Event.CLOSE,fileSaved);
		fs.addEventListener(IOErrorEvent.IO_ERROR,fileSaveError);
		fs.openAsync(file, FileMode.WRITE);
		fs.writeBytes(imgByteArr);
		fs.close();
		
		}
		if(rendered == textItems.length){
		book.log='Book id:'+book.id+'. All texts rendered.';
		}
		}
		*/

	}
}