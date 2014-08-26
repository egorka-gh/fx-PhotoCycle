package com.photodispatcher.provider.preprocess{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.event.IMRunerEvent;
	import com.photodispatcher.event.OrderBuildProgressEvent;
	import com.photodispatcher.model.mysql.entities.LabResize;
	import com.photodispatcher.model.mysql.entities.Order;
	import com.photodispatcher.model.mysql.entities.OrderState;
	import com.photodispatcher.model.mysql.entities.PrintGroup;
	import com.photodispatcher.model.mysql.entities.PrintGroupFile;
	import com.photodispatcher.model.mysql.entities.StateLog;
	import com.photodispatcher.shell.IMCommand;
	import com.photodispatcher.shell.IMRuner;
	import com.photodispatcher.util.StrUtil;
	
	import flash.display.Loader;
	import flash.events.AsyncErrorEvent;
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.UncaughtErrorEvent;
	import flash.filesystem.File;
	import flash.net.URLRequest;
	
	[Event(name="complete", type="flash.events.Event")]
	[Event(name="progress", type="com.photodispatcher.event.OrderBuildProgressEvent")]
	public class ResizeTask extends EventDispatcher{
		private var order:Order;
		private var orderFolder:String;
		private var prtFolder:String;
		private var maxThreads:int=0;
		
		public var hasErr:Boolean=false;
		public var error:String;

		private var logStates:Boolean;

		public function ResizeTask(order:Order, orderFolder:String, prtFolder:String, logStates:Boolean=true){
			super(null);
			this.order=order;
			this.orderFolder=orderFolder;
			this.prtFolder=prtFolder;
			this.logStates=logStates;
		}

		public function run():void{
			hasErr=false;
			error='';
			maxThreads=Context.getAttribute('imThreads');
			if (maxThreads<=0){
				dispatchEvent(new Event(Event.COMPLETE));
				return;
			}
			if(!order.printGroups || order.printGroups.length==0){
				//has non printGroups
				dispatchEvent(new Event(Event.COMPLETE));
				return;
			}
			trace('ResizeTask. start order: '+order.id);
			prepare();
		}
		
		private var progressTotal:int=0;
		private function reportProgress(caption:String='',ready:Number=0, total:Number=0):void{
			dispatchEvent(new OrderBuildProgressEvent(order.id+' '+ caption,ready,total));
		}

		private var prepareItems:Array;
		private var resizeItems:Array;

		private function prepare():void{
			var pg:PrintGroup;
			var pgf:PrintGroupFile;
			var ri:ResizeItem
			prepareItems=[];
			resizeItems=[];
			for each(pg in order.printGroups){
				if(pg && pg.book_type==0 && pg.state<OrderState.CANCELED){
					if(pg.files && pg.files.length>0){
						for each(pgf in pg.files){
							if(pgf){
								ri= new ResizeItem(pgf);
								ri.order_id=order.id;
								//size limit
								try{
									ri.fitSize.x=LabResize.getSizeLimit(Math.min(pg.width,pg.height));
									ri.fitSize.y=LabResize.getSizeLimit(Math.max(pg.width,pg.height));
								}catch(err:Error){
									ri.fitSize.x=0;
									ri.fitSize.y=0;
								}
								//check format
								var ext:String=StrUtil.getFileExtension(pgf.file_name);
								ri.isNotJPG=ext!='jpg' && ext!='jpeg';
								//file path
								ri.fileFolder=orderFolder+File.separator+order.ftp_folder+File.separator+pg.path;
								ri.outFolder   =prtFolder+File.separator+order.ftp_folder+File.separator+pg.path;
								//processed file name
								ri.resultFileName=PrintGroup.SUBFOLDER_PRINT+File.separator+pgf.file_name;
								if(ri.isNotJPG) ri.resultFileName=StrUtil.setFileExtension(ri.resultFileName,'jpg');
								if(ri.fitSize.x>0 && ri.fitSize.y>0 && pg.cutting!=0){
									//get image size
									prepareItems.push(ri);									
								}else if(ri.isNotJPG){
									resizeItems.push(ri);
								}

							}
						}
					}
				}
			}
			if(prepareItems.length==0 && resizeItems.length==0){
				dispatchEvent(new Event(Event.COMPLETE));
				return;
			}
			progressTotal=prepareItems.length;
			//TODO remove
			//StateLogDAO.logState(order.state,order.id,'','Определение размеров изображений'); 
			preLoadNext();
		}
	
		private var loader:Loader;
		private var currResizeItem:ResizeItem;
		private var resizeIdx:int;
		
		private function preLoadNext():void{
			var msg:String;
			reportProgress('Определение размера',progressTotal-prepareItems.length,progressTotal);
			if(prepareItems.length==0){
				//completed
				trace('ResizeTask. prepare completed order: '+order.id+' resize items: '+resizeItems.length.toString());
				//start resize threads
				trace('ResizeTask. start resize threads order: '+order.id);
				//TODO remove
				//StateLogDAO.logState(order.state,order.id,'','Ресайз'); 
				if(resizeItems.length==0){
					dispatchEvent(new Event(Event.COMPLETE));
					return;
				}
				progressTotal=resizeItems.length;
				reportProgress('Ресайз',0,progressTotal);
				resizeIdx=0;
				for (var i:int=0; i<maxThreads; i++){
					resizeNext();
					if(i>=resizeItems.length) break;
				}
			}else{
				currResizeItem=prepareItems.pop() as ResizeItem;
				if(!currResizeItem){
					preLoadNext();
					return;
				}
				loader=new Loader();
				loader.addEventListener(AsyncErrorEvent.ASYNC_ERROR, onLoaderErr);
				loader.addEventListener(IOErrorEvent.IO_ERROR, onLoaderErr);
				loader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onLoaderErr);
				//loader.contentLoaderInfo.addEventListener(Event.INIT,onContentLoaderInfo);
				loader.contentLoaderInfo.addEventListener(Event.COMPLETE,onContentLoaderInfo);
				loader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, onLoaderErr);
				loader.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onLoaderErrUn)
				loader.contentLoaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onLoaderErrUn)
				try{
					//TODO remove
					//StateLogDAO.logState(order.state,order.id,'','Определение размера: '+currResizeItem.printGroupFile.file_name); 
					loader.load(new URLRequest(currResizeItem.fileFolder+File.separator+currResizeItem.printGroupFile.file_name));
				}catch(err:Error) {
					loader.removeEventListener(AsyncErrorEvent.ASYNC_ERROR, onLoaderErr);
					loader.removeEventListener(IOErrorEvent.IO_ERROR, onLoaderErr);
					loader.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onLoaderErr);
					//loader.contentLoaderInfo.removeEventListener(Event.INIT,onContentLoaderInfo);
					loader.contentLoaderInfo.removeEventListener(Event.COMPLETE,onContentLoaderInfo);
					loader.contentLoaderInfo.removeEventListener(IOErrorEvent.IO_ERROR, onLoaderErr);
					loader.uncaughtErrorEvents.removeEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onLoaderErrUn)
					loader.contentLoaderInfo.uncaughtErrorEvents.removeEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onLoaderErrUn)
					msg='Ошибка определения размера (loader.load): '+err.message+'; '+currResizeItem.fileFolder+File.separator+currResizeItem.printGroupFile.file_name;
					trace('ResizeTask. '+msg);
					if(logStates) StateLog.log(OrderState.ERR_FILE_SYSTEM,currResizeItem.order_id,'',msg); 
					if (currResizeItem.isNotJPG){
						resizeItems.push(currResizeItem);
					}
					loader=null;
					preLoadNext();
					return;
				}
			}
		}
		
		private function onLoaderErrUn(event:UncaughtErrorEvent):void{
			if(loader){
				loader.removeEventListener(AsyncErrorEvent.ASYNC_ERROR, onLoaderErr);
				loader.removeEventListener(IOErrorEvent.IO_ERROR, onLoaderErr);
				loader.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onLoaderErr);
				loader.contentLoaderInfo.removeEventListener(Event.COMPLETE,onContentLoaderInfo);
				loader.contentLoaderInfo.removeEventListener(IOErrorEvent.IO_ERROR, onLoaderErr);
				loader.uncaughtErrorEvents.removeEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onLoaderErrUn)
				loader.contentLoaderInfo.uncaughtErrorEvents.removeEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onLoaderErrUn)
			}
			var msg:String='';
			if(event.error is Error){
				var error:Error = event.error as Error;
				msg=error.message;
			}else if(event.error is ErrorEvent){
				var errorEvent:ErrorEvent = event.error as ErrorEvent;
				msg=errorEvent.text;
			}else{
				trace('?????');
			}
			trace('ResizeTask. Ошибка определения размера: '+msg);
			//TODO remove
			//StateLogDAO.logState(order.state,order.id,'','Ошибка определения размера(un) : '+msg); 
			if(currResizeItem){
				if(logStates) StateLog.log(OrderState.ERR_FILE_SYSTEM,currResizeItem.order_id,'','Ошибка определения размера(un) : '+msg+'; '+ currResizeItem.printGroupFile.file_name); 
				if (currResizeItem.isNotJPG){
					resizeItems.push(currResizeItem);
				}
			}
			loader=null;
			preLoadNext();
		}

		private function onLoaderErr(e:ErrorEvent):void{
			if(loader){
				loader.removeEventListener(AsyncErrorEvent.ASYNC_ERROR, onLoaderErr);
				loader.removeEventListener(IOErrorEvent.IO_ERROR, onLoaderErr);
				loader.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onLoaderErr);
				loader.contentLoaderInfo.removeEventListener(Event.COMPLETE,onContentLoaderInfo);
				loader.contentLoaderInfo.removeEventListener(IOErrorEvent.IO_ERROR, onLoaderErr);
				loader.uncaughtErrorEvents.removeEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onLoaderErrUn)
				loader.contentLoaderInfo.uncaughtErrorEvents.removeEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onLoaderErrUn)
			}
			trace('ResizeTask. Ошибка определения размера: '+e.type+'; '+e.text);
			//TODO remove
			//StateLogDAO.logState(OrderState.ERR_FILE_SYSTEM,currResizeItem.order_id,'','Ошибка определения размера: '+e.type+'; '+e.text+'; '); 
			if(currResizeItem){
				if(logStates) StateLog.log(OrderState.ERR_FILE_SYSTEM,currResizeItem.order_id,'','Ошибка определения размера: '+e.type+'; '+e.text+'; '+ currResizeItem.printGroupFile.file_name); 
				if (currResizeItem.isNotJPG){
					resizeItems.push(currResizeItem);
				}
			}
			loader=null;
			preLoadNext();
		}
		private function onContentLoaderInfo(e:Event):void{
			if(loader){
				try{
					currResizeItem.size.x=Math.min(loader.contentLoaderInfo.width,loader.contentLoaderInfo.height);
					currResizeItem.size.y=Math.max(loader.contentLoaderInfo.width,loader.contentLoaderInfo.height);
				}catch(err:Error){
					currResizeItem.size.x=0;
					currResizeItem.size.y=0;
					//if(e.type==Event.INIT) return;//waite for complite event?
				}
				loader.removeEventListener(AsyncErrorEvent.ASYNC_ERROR, onLoaderErr);
				loader.removeEventListener(IOErrorEvent.IO_ERROR, onLoaderErr);
				loader.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onLoaderErr);
				loader.contentLoaderInfo.removeEventListener(Event.COMPLETE,onContentLoaderInfo);
				loader.contentLoaderInfo.removeEventListener(IOErrorEvent.IO_ERROR, onLoaderErr);
				loader.uncaughtErrorEvents.removeEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onLoaderErrUn)
				loader.contentLoaderInfo.uncaughtErrorEvents.removeEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onLoaderErrUn)
				try{
					loader.unload();
				}catch(err:Error){}
				loader=null;
			}
			if (currResizeItem && (currResizeItem.mustToResize() || currResizeItem.isNotJPG)){
				resizeItems.push(currResizeItem);
			}
			preLoadNext();
		}
		
		private function resizeNext():void{
			if(resizeIdx>=resizeItems.length){
				//all started
				return;
			}
			var ri:ResizeItem=resizeItems[resizeIdx] as ResizeItem;
			//create im command
			//convert 1CY_0000.jpg -resize "1000x1000^" -depth 8 -quality "100%" D:\Egorka\Folders\flex\im\r.jpg
			var cmd:IMCommand= new IMCommand(IMCommand.IM_CMD_CONVERT);
			cmd.add(ri.printGroupFile.file_name);
			//resize options
			if(ri.resizeType!=ResizeItem.RESIZE_NON){
				cmd.add('-resize');
				var frame:String=ri.resizeSize.toString()+'x'+ri.resizeSize.toString();
				if(ri.resizeType==ResizeItem.RESIZE_BY_SHORT) frame=frame+'^';
				cmd.add(frame);
			}
			//save
			cmd.add('-depth'); cmd.add(PreprocessTask.OUT_FILE_DEPTH);
			cmd.add('-quality'); cmd.add(PreprocessTask.OUT_FILE_QUALITY);
			var path:String=ri.resultFileName;
			if(ri.fileFolder!=ri.outFolder) path=ri.outFolder+File.separator+path;
			cmd.add(path);
			//run
			//trace('ResizeTask. start IM command:' cmd.toString());
			var im:IMRuner=new IMRuner(Context.getAttribute('imPath'),ri.fileFolder);
			im.addEventListener(IMRunerEvent.IM_COMPLETED, onResize);
			im.targetObject=ri;
			im.start(cmd);
			resizeIdx++;
		}
		
		private function onResize(e:IMRunerEvent):void{
			var ri:ResizeItem;
			var im:IMRuner=e.target as IMRuner;
			if(im){
				im.removeEventListener(IMRunerEvent.IM_COMPLETED, onResize);
				ri=im.targetObject as ResizeItem;
			}
			/*
			if(e.hasError){ // || true){ //4 debug
				hasErr=true;
				error='Ошибка ресайза: '+e.error;
				order.state=OrderState.ERR_PREPROCESS;
				IMRuner.stopAll();
				dispatchEvent(new Event(Event.COMPLETE));
			}
			*/
			if(ri){
				ri.isComplete=true;
				if(e.hasError){
					ri.printGroupFile.isBroken=true;
					if(logStates) StateLog.log(OrderState.ERR_PREPROCESS,ri.order_id,'','Ошибка ресайза: '+e.error);
				}else{
					if (ri.isNotJPG){
						trace('ResizeTask. Image converted to JPG: '+ri.fileFolder+File.separator+ri.printGroupFile.file_name);
						if(logStates) StateLog.log(order.state,ri.order_id,'','Файл перекодирован в jpg: '+ri.printGroupFile.file_name);
					}
					ri.printGroupFile.file_name=ri.resultFileName;
				}
			}
			//check if complited
			var isComplite:Boolean=true;
			var complited:int=0;
			for each(ri in resizeItems){
				if(!ri.isComplete){
					isComplite=false;
					//break;
				}else{
					complited++;
				}
			}
			reportProgress('Ресайз',complited,progressTotal);
			if(isComplite){
				trace('ResizeTask. order complited '+order.id);
				resizeItems=[];
				dispatchEvent(new Event(Event.COMPLETE));
				return;
			}
			resizeNext();
		}

	}
}