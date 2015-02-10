package com.photodispatcher.provider.preprocess{
	import com.photodispatcher.event.OrderBuildProgressEvent;
	import com.photodispatcher.model.mysql.entities.Order;
	import com.photodispatcher.model.mysql.entities.OrderState;
	import com.photodispatcher.model.mysql.entities.PrintGroup;
	import com.photodispatcher.model.mysql.entities.PrintGroupFile;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.filesystem.File;
	
	[Event(name="complete", type="flash.events.Event")]
	[Event(name="progress", type="com.photodispatcher.event.OrderBuildProgressEvent")]
	public class PostProcessTask extends EventDispatcher{
		public var order:Order;
		public var rootFolder:String;
		public var prtFolder:String;
		
		public var hasErr:Boolean=false;
		public var errMsg:String='';
		
		private var postCopyFiles:Array; 
		private var killFolders:Array; 

		public function PostProcessTask(order:Order, rootFolder:String, prtFolder:String){
			super(null);
			this.order=order;
			this.rootFolder=rootFolder;
			this.prtFolder=prtFolder;
		}
		
		public function run():void{
			var printGroup:PrintGroup;
			var pgf:PrintGroupFile;
			//var a:Array;
			var printFile:File;
			var srcFile:File;
			var filePath:String;
			postCopyFiles=[];
			killFolders=[];
			var notInPrint:Boolean;

			if(!order || !order.printGroups || order.printGroups.length==0){
				dispatchEvent(new Event(Event.COMPLETE));
				return;
			}

			for each(printGroup in order.printGroups){
				if(printGroup && printGroup.state<OrderState.CANCELED){
					if(printGroup.book_type==0 || !printGroup.is_pdf){
						//TODO kill wrk dirs
						if(printGroup.files && printGroup.files.length>0){
							for each (pgf in printGroup.files){
								if(pgf){
									notInPrint=false;
									if(rootFolder==prtFolder){//same folder, check by parent folder 
										filePath=rootFolder+File.separator+order.ftp_folder+File.separator+printGroup.path+File.separator+pgf.file_name;
										try{
											printFile=new File(filePath);
										}catch(err:Error){
											hasErr=true;
											errMsg=err.message;
											dispatchEvent(new Event(Event.COMPLETE));
											return;
										}
										notInPrint=printFile.parent.name!=PrintGroup.SUBFOLDER_PRINT;
									}else{//diferent folders
										//lookup in prt
										filePath=prtFolder+File.separator+order.ftp_folder+File.separator+printGroup.path+File.separator+pgf.file_name;
										try{
											printFile=new File(filePath);
										}catch(err:Error){
											notInPrint=true; //????
										}
										if(notInPrint || !printFile.exists){
											notInPrint=true;
										}
										if(notInPrint){
											//detect source file
											filePath=rootFolder+File.separator+order.ftp_folder+File.separator+printGroup.path+File.separator+pgf.file_name;
											try{
												printFile=new File(filePath);
											}catch(err:Error){
												hasErr=true;
												errMsg=err.message;
												dispatchEvent(new Event(Event.COMPLETE));
												return;
											}
										}
										if(!printFile.exists){
											hasErr=true;
											errMsg='Не найден исходный файл '+printFile.nativePath;
											dispatchEvent(new Event(Event.COMPLETE));
											return;
										}
									}
									
									if(notInPrint || pgf.isBroken){
										filePath=prtFolder+File.separator+order.ftp_folder+File.separator+printGroup.path+File.separator+PrintGroup.SUBFOLDER_PRINT+File.separator+printFile.name;
										postCopyFiles.push(new PostProcessItem(pgf,printFile,filePath));
									}
								}
							}
						}
					}else if(printGroup.is_pdf){
						//kill wrk files (keep fbook)
						filePath=rootFolder+File.separator+order.ftp_folder+File.separator+printGroup.path+File.separator+PDFmakeupGroup.TEMP_FOLDER;
						printFile=null;
						try{
							printFile=new File(filePath);
						}catch(err:Error){}
						if(printFile && printFile.exists && printFile.isDirectory) killFolders.push(printFile);
					}
				}
			}
			progressTotal=postCopyFiles.length+killFolders.length;
			copyNext();
		}
		
		private var progressTotal:int=0;
		private function reportProgress(caption:String=''):void{
			dispatchEvent(new OrderBuildProgressEvent(order.id+' '+ caption,progressTotal-postCopyFiles.length-killFolders.length,progressTotal));
		}

		private var currPostProcessItem:PostProcessItem;
		private function copyNext():void{
			var pi:PostProcessItem;
			reportProgress('Коприрование в print');
			if(postCopyFiles.length==0){
				//completed
				//dispatchEvent(new Event(Event.COMPLETE));
				currPostProcessItem=null;
				deleteNext();
				return;
			}
			pi=postCopyFiles.pop() as PostProcessItem;
			if(pi && pi.printGroupFile && pi.file && pi.file.exists){
				currPostProcessItem=pi;
				//var dstFile:File=pi.file.parent.resolvePath(PrintGroup.SUBFOLDER_PRINT+File.separator+pi.file.name);
				var dstFile:File;
				try{
					dstFile=new File(pi.copyToPath);
				}catch(err:Error){
					hasErr=true;
					errMsg=err.message;
					dispatchEvent(new Event(Event.COMPLETE));
					return;
				}
				pi.file.addEventListener(Event.COMPLETE,copyComplete);
				pi.file.addEventListener(IOErrorEvent.IO_ERROR,copyIOFault);
				pi.file.addEventListener(SecurityErrorEvent.SECURITY_ERROR,copySecurityFault);
				pi.file.copyToAsync(dstFile,true);
			}else{
				copyNext();
			}
		}
		
		private function copyComplete(e:Event):void{
			stopListen();
			currPostProcessItem.printGroupFile.file_name=PrintGroup.SUBFOLDER_PRINT+File.separator+currPostProcessItem.file.name
			copyNext();
		}
		
		private function copyIOFault(e:IOErrorEvent):void{
			hasErr=true;
			errMsg=e.text+'; '+currPostProcessItem.printGroupFile.file_name;
			stopListen();
			dispatchEvent(new Event(Event.COMPLETE));
		}
		
		private function copySecurityFault(e:SecurityErrorEvent):void{
			hasErr=true;
			errMsg=e.text+'; '+currPostProcessItem.printGroupFile.file_name;
			stopListen();
			dispatchEvent(new Event(Event.COMPLETE));
		}
		
		private function stopListen():void{
			if(currPostProcessItem){
				currPostProcessItem.file.removeEventListener(Event.COMPLETE,copyComplete);
				currPostProcessItem.file.removeEventListener(IOErrorEvent.IO_ERROR,copyIOFault);
				currPostProcessItem.file.removeEventListener(SecurityErrorEvent.SECURITY_ERROR,copySecurityFault);
			}
		}

		private var currDelFolder:File;
		private function deleteNext():void{
			var fld:File;
			if(killFolders.length==0){
				//completed
				currDelFolder=null;
				reportProgress('');
				dispatchEvent(new Event(Event.COMPLETE));
				return;
			}
			reportProgress('Удаление временных папок');
			fld=killFolders.pop() as File;
			if(fld && fld.exists){
				currDelFolder=fld;
				fld.addEventListener(Event.COMPLETE,delComplete);
				fld.addEventListener(IOErrorEvent.IO_ERROR,delComplete);
				fld.addEventListener(SecurityErrorEvent.SECURITY_ERROR,delComplete);
				fld.deleteDirectoryAsync(true);
			}else{
				deleteNext();
			}
		}

		private function delComplete(e:Event):void{
			stopListenDel();
			deleteNext();
		}

		private function stopListenDel():void{
			if(currDelFolder){
				currDelFolder.removeEventListener(Event.COMPLETE,delComplete);
				currDelFolder.removeEventListener(IOErrorEvent.IO_ERROR,delComplete);
				currDelFolder.removeEventListener(SecurityErrorEvent.SECURITY_ERROR,delComplete);
			}
		}

	}
}