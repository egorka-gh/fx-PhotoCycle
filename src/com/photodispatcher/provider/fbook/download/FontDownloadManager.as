package com.photodispatcher.provider.fbook.download{
	import com.akmeful.fotakrama.canvas.text.CanvasTextStyle;
	import com.valichek.font.flex.FontManagerCommon;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.ProgressEvent;
	import flash.system.ApplicationDomain;
	import flash.system.LoaderContext;
	import flash.utils.ByteArray;
	
	import mx.events.ModuleEvent;
	import mx.utils.StringUtil;
	
	import spark.modules.ModuleLoader;
	
	[Event(name="complete", type="flash.events.Event")]
	public class FontDownloadManager extends FontManagerCommon{
		
		private static var _instance:FontDownloadManager;
		public static function get instance():FontDownloadManager {
			return _instance;
		}
		
		public var urlMask:String = 'flash/font/f{0}.swf';
		
		private var packBinarys:Object;
		
		/*
		private var queueUrls:Array=[];
		private var queueFonts:Object= new Object;
		//private var downloadConnections:int;
		public var currUrl:String='';
		*/
		public var hasError:Boolean;
		public var errorString:String;
		public var errorFont:String;
		private var currFonts:Array;
		private var nextFontIdx:int=0;
		
		public function FontDownloadManager(){
			super();
			//downloadConnections=MakeupConfig.config.downloadConnections;
			//if(downloadConnections<=0) downloadConnections=1;
			//addEventListener(ModuleEvent.ERROR, loadError);
			//addEventListener(ModuleEvent.READY, fontLoaded);
			_instance = this;
			packBinarys= new Object;
		}
		
		override protected function getUrlForPackName(packName:String):String {
			return StringUtil.substitute(urlMask, packName);
		}
		
		public function getPackUrl(packName:String):String {
			return getUrlForPackName(packName);
		}
		
		public function addPackpackBinary(name:String, bytes:ByteArray):void{
			if(!name || !bytes || bytes.length==0) return;
			packBinarys[name]=bytes;
		}
		
		/*
		public function loadBinary(name:String, bytes:ByteArray):void{
		//var lc:LoaderContext = new LoaderContext(false, null);
		//lc.allowLoadBytesCodeExecution = true;
		var ml:ModuleLoader = new ModuleLoader;
		ml.applicationDomain=ApplicationDomain.currentDomain;
		ml.addEventListener(ModuleEvent.READY, moduleHandler);
		ml.addEventListener(ModuleEvent.ERROR, moduleHandler);
		ml.loadModule(name, bytes);
		}
		*/
		
		override public function loadPack(packName:String, version:String = null):ModuleLoader{
			//if(loaders[packName]) return loaders[packName];
			var ba:ByteArray=packBinarys[packName] as ByteArray;
			if(!ba){
				dispatchEvent(new ModuleEvent(ModuleEvent.ERROR,false,false,0,0,'No binary found for '+packName));
				return null;
			}
			var ml:ModuleLoader = new ModuleLoader;
			ml.applicationDomain=ApplicationDomain.currentDomain;
			
			loaders[packName] = ml;
			fontPacks[packName] = packName;
			
			ml.addEventListener(ModuleEvent.READY, moduleHandler);
			ml.addEventListener(ModuleEvent.ERROR, moduleHandler);
			
			ml.loadModule(packName, ba);
			return ml;
			
		}
		
		
		override protected function moduleHandler(event:ModuleEvent):void {
			var ml:ModuleLoader = event.currentTarget as ModuleLoader;
			switch(event.type){
				case ModuleEvent.READY:
					ml.removeEventListener(ModuleEvent.ERROR, moduleHandler);
					ml.removeEventListener(event.type, moduleHandler);
					moduleInfos[ml.url] = event.module;
					embeddedFonts[ml.url] = getEmbeddedFonts(event.module);
					if(loadTryings[ml.url]) delete loadTryings[ml.url];
					break;
				case ModuleEvent.UNLOAD:
					ml.removeEventListener(event.type, moduleHandler);
					break;
				case ModuleEvent.ERROR:
					if(loadTryings[ml.url]) delete loadTryings[ml.url];
					delete loaders[ml.url];
					ml.removeEventListener(ModuleEvent.READY, moduleHandler);
					ml.removeEventListener(event.type, moduleHandler);
					break;
			}
			dispatchEvent(event.clone());
			if(event.type == ModuleEvent.ERROR){
				// delete fontPack name after dispatching error event to give chance to get it when handling error
				// удаляем имя пакета после отправки события об ошибке, чтобы дать возможность определить имя пакета в обработчике события
				delete fontPacks[ml.url];
			}
		}
		
		public function loadBatch(fonts:Array):void{
			if(!fonts) return;
			if (currFonts){
				//is loading
				currFonts=currFonts.concat(fonts); 
			}else{
				//start load
				currFonts=fonts;
				hasError=false;
				errorString='';
				errorFont='';
				nextFontIdx=0;
				if(currFonts.length==0){
					currFonts=null;
					dispatchEvent(new Event(Event.COMPLETE));
					return;
				}
				addEventListener(ModuleEvent.ERROR, loadError);
				addEventListener(ModuleEvent.READY, fontLoaded);
				loadNext();
			}
		}
		
		private function loadNext():void{
			if(nextFontIdx<currFonts.length){
				var style:CanvasTextStyle=currFonts[nextFontIdx] as CanvasTextStyle;
				if(style && !hasFont(style.fontFamily, style.isBold, style.isItalic)){
					loadPack(style.fontFamily);
				}else{
					nextFontIdx++;
					loadNext();
					return;
				}
				nextFontIdx++;
			}else{
				//complited
				currFonts=null;
				dispatchEvent(new Event(Event.COMPLETE));
			}
		}
		
		public function get lastLoadedFont():String{
			if(!currFonts || currFonts.length==0 || nextFontIdx==0 || nextFontIdx>currFonts.length) return '';
			var style:CanvasTextStyle=currFonts[nextFontIdx-1] as CanvasTextStyle;
			return style?style.fontFamily:''; 
		}
		
		private function fontLoaded(event:ModuleEvent):void {
			loadNext();
		}
		
		private function loadError(event:ModuleEvent):void {
			hasError=true;
			errorString=event.errorText;
			var style:CanvasTextStyle=currFonts[nextFontIdx-1] as CanvasTextStyle;
			if(style) errorFont=style.fontFamily;
			trace('font load error '+style.fontFamily+'; err: '+event.errorText);
			currFonts=null;
			dispatchEvent(new Event(Event.COMPLETE));
		}
		
	}
}