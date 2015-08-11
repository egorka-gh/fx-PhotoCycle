package com.photodispatcher.provider.colorcorrection
{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.event.BusyEvent;
	import com.photodispatcher.event.IMRunerEvent;
	import com.photodispatcher.factory.PrintGroupBuilder;
	import com.photodispatcher.model.mysql.DbLatch;
	import com.photodispatcher.model.mysql.entities.Order;
	import com.photodispatcher.model.mysql.entities.OrderState;
	import com.photodispatcher.model.mysql.entities.Source;
	import com.photodispatcher.model.mysql.entities.SubOrder;
	import com.photodispatcher.model.mysql.services.OrderService;
	import com.photodispatcher.provider.fbook.FBookProject;
	import com.photodispatcher.shell.IMCommand;
	import com.photodispatcher.shell.IMRuner;
	import com.photodispatcher.util.IMCommandUtil;
	import com.photodispatcher.util.StrUtil;
	
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	
	import mx.collections.ArrayCollection;
	import mx.controls.Alert;
	
	import org.granite.tide.Tide;
	
	[Event(name="error", type="flash.events.ErrorEvent")]
	[Event(name="progress", type="flash.events.ProgressEvent")]
	[Event(name="busy", type="com.photodispatcher.event.BusyEvent")]
	public class ColorCorrectionManager extends EventDispatcher{
		public static const FLD_ORIGINAL:String='org';
		public static const FLD_CORRECTION:String='wrk';
		public static const FLD_DONE:String='done';
		public static const MPC_ORG_FILE:String='i.mpc';

		
		[Bindable]
		public var order:Order;
		[Bindable]
		public var currSuborder:SubOrder;
		[Bindable]
		public var lastError:String;
		[Bindable]
		public var filesAC:ArrayCollection;
		
		public var ccAdvance:int=0;
		public var ccStep:int=0;
		
		private var _currImage:CCImage;
		[Bindable]
		public function get currImage():CCImage{
			return _currImage;
		}
		public function set currImage(value:CCImage):void{
			var old:CCImage;
			_currImage = value;
			if(old==null || old!=_currImage){
				startFile(_currImage);
			}
		}

		
		[Bindable]
		public var corrFile:String;
		
		[Bindable]
		public var corrCyan:int=0;
		[Bindable]
		public var corrMagenta:int=0;
		[Bindable]
		public var corrYellow:int=0;
		[Bindable]
		public var corrBright:int=0;
		
		private var cpyIdx:int;
		private var cpyArr:Array;
		
		private var orderId:String;
		private var srcRoot:File;
		private var tmpRoot:File;

		public var initComplite:Boolean;
		
		
		public function ColorCorrectionManager(){
			super(null);
		}
		
		public function init():void{
			initComplite=false;
			srcRoot=null;
			tmpRoot=null;
			var srcPath:String=Context.getAttribute('workFolder');
			var tmpPath:String=Context.getAttribute('tmpFolder');
			var imPath:String=Context.getAttribute('imPath');
			if(!srcPath || !tmpPath || !imPath) return;
			
			var f:File= new File(srcPath);
			if(!f.exists || !f.isDirectory)  return;
			//srcRoot=f;
			f= new File(tmpPath);
			if(!f.exists || !f.isDirectory)  return;
			tmpRoot=f;
			initComplite=clearTemp();
		}
		
		private function clearTemp():Boolean{
			if(!tmpRoot || !tmpRoot.isDirectory) return false;
		 	var arr:Array=tmpRoot.getDirectoryListing();
			if(arr.length==0) return true;
			for each(var f:File in arr){
				try{
					if(f.isDirectory){
						f.deleteDirectory(true);
					}else{
						f.deleteFile();
					}
				}catch(error:Error){
					return false;
				}
			}
			return true;
		}

		private function clearWrk():Boolean{
			if(!tmpRoot || !tmpRoot.isDirectory) return false;
			var wrk:File=tmpRoot.resolvePath(FLD_CORRECTION);
			try{
				if(wrk.exists){
					if(!wrk.isDirectory){
						wrk.deleteFile();
					}else{
						var arr:Array=wrk.getDirectoryListing();
						if(arr.length==0) return true;
						for each(var f:File in arr){
							if(f.isDirectory){
								f.deleteDirectory(true);
							}else{
								f.deleteFile();
							}
						}
					}
				}else{
					wrk.createDirectory();
				}
			}catch(error:Error){
				return false;
			}
			
			return true;
		}

		public function load(orderId:String):void{
			this.orderId=orderId;
			order=null;
			currSuborder=null;
			currImage=null;
			filesAC=null;
			if(!orderId){
				return;
			}else{
				var svc:OrderService=Tide.getInstance().getContext().byType(OrderService,true) as OrderService;
				var latch:DbLatch= new DbLatch();
				latch.addEventListener(Event.COMPLETE,onOrderLoad);
				latch.addLatch(svc.loadOrderFull(orderId));
				latch.start();
			}
		}
		private function onOrderLoad(e:Event):void{
			var latch:DbLatch=e.target as DbLatch;
			if(latch){
				latch.removeEventListener(Event.COMPLETE,onOrderLoad);
				if(!latch.complite) return;
				order=latch.lastDataItem as Order;
			}
			if(!order){
				//Alert.show('Заказ "'+orderId+'" не найден');
				dispatchError('Заказ "'+orderId+'" не найден');
				return;
			}
			if(!order.hasSuborders){
				//Alert.show('Заказ "'+orderId+'" не содержит подзаказов');
				dispatchError('Заказ "'+orderId+'" не содержит подзаказов');
				return;
			}
			clearTemp();
			/*
			for each(var so:SubOrder in order.suborders ){
				if(so.color_corr){
					currSuborder=so;
					break;
				}
			}
			*/
			//if(!currSuborder) currSuborder=order.suborders.getItemAt(0) as SubOrder;
		}
		
		private function dispatchError(msg:String):void{
			lastError=msg;
			var e:ErrorEvent= new ErrorEvent(ErrorEvent.ERROR,false,false,msg);  
		}

		public function start(suborder:SubOrder):void{
			if(!suborder) return;
			currSuborder=suborder;
			filesAC=new ArrayCollection();
			clearTemp();
			copySrcFiles();
		}
		
		private function copySrcFiles():void{
			if(!order || !currSuborder) return;
			if(!tmpRoot) return;
			var src:Source=Context.getSource(order.source);
			var srcPath:String=src.getWrkFolder()+File.separator+order.ftp_folder+File.separator+currSuborder.ftp_folder+File.separator+FBookProject.SUBDIR_WRK+File.separator+FBookProject.SUBDIR_USER;
			var f:File=new File(srcPath);
			if(!f.exists || !f.isDirectory){
				dispatchError('Папка "' +srcPath+'" не доступна');
				return;
			}
			srcRoot=f;
			scanFolder(srcRoot,'');
			if(filesAC.length==0){
				dispatchError('Папка "' +srcPath+'" не содержит изображений');
				return;
			}
			//copy files
			cpyIdx=0;
			cpyArr=filesAC.source.concat();
			dispatchEvent(new BusyEvent('Копирование файлов',2));
			copyNextFile();
		}
		
		private function copyNextFile():void{
			dispatchEvent(new ProgressEvent(ProgressEvent.PROGRESS,false,false,cpyIdx,cpyArr.length));
			if(cpyIdx>=cpyArr.length){
				//complited
				cpyArr=[];
				dispatchEvent(new BusyEvent('',0));
				//set first image
				currImage= (filesAC.getItemAt(0) as CCImage);
			}
			var i:CCImage=cpyArr[cpyIdx] as CCImage;
			if(i && i.name){
				var sf:File=new File(i.srcPath);
				if(sf && sf.exists && !sf.isDirectory){
					var df:File=tmpRoot.resolvePath(FLD_ORIGINAL);
					if(i.subFolder) df=df.resolvePath(i.subFolder);
					df=df.resolvePath(i.name);
					i.orgPath=df.nativePath;
					sf.addEventListener(Event.COMPLETE,onCopyNextFile);
					sf.addEventListener(IOErrorEvent.IO_ERROR,onCopyNextFile);
					sf.copyToAsync(df,true);
				}
			}
			cpyIdx++;
		}
		
		private function onCopyNextFile(e:Event):void{
			var f:File=e.target as File;
			f.removeEventListener(Event.COMPLETE,onCopyNextFile);
			f.removeEventListener(IOErrorEvent.IO_ERROR,onCopyNextFile);
			
			if(e.type==Event.COMPLETE){
				copyNextFile();
			}else{
				if(e is ErrorEvent){
					dispatchEvent(new BusyEvent('',0));
					dispatchError((e as ErrorEvent).text);
				}
			}
		}
		
		private function scanFolder(root:File, subFolder:String):void{
			var arr:Array=root.getDirectoryListing();
			for each(var f:File in arr){
				var ext:String=f.extension;
				if (!ext || !PrintGroupBuilder.ALLOWED_EXTENSIONS[ext]){
					trace('Invalid file type "'+f.name+'". File skipped');
				}else{
					if(f.isDirectory && !subFolder){
						//cscan first sublevel
						scanFolder(f, f.name);
					}else{
						var i:CCImage= new CCImage(f.nativePath,'', subFolder, f.name);
						filesAC.addItem(i);
					}
				}
			}
		}
		
		private function startFile(image:CCImage):void{
			corrFile=null;
			runningTreads=null;
			resetAdvanceDir();
			if(!clearWrk()) return;
			if(!image) return; 
			if(!image.done) image.resetCorrection();
			
			corrBright=image.corrBright;
			corrCyan=image.corrCyan;
			corrMagenta=image.corrMagenta;
			corrYellow=image.corrYellow;
			
			//copy image to wrk
			
			var sf:File=new File(image.orgPath);
			if(!sf.exists) return;
			
			//convert to native IM format
			var cmd:IMCommand= new IMCommand(IMCommand.IM_CMD_CONVERT);
			cmd.folder=tmpRoot.resolvePath(FLD_CORRECTION).nativePath;
			cmd.add(image.orgPath);
			cmd.add(MPC_ORG_FILE);
			var im:IMRuner=new IMRuner(Context.getAttribute('imPath'),cmd.folder);
			im.addEventListener(IMRunerEvent.IM_COMPLETED, onMpcCreate);
			im.start(cmd);
		}
		
		public function resetCC():void{
			if(!currImage) return;
			corrBright=0;
			corrCyan=0;
			corrMagenta=0;
			corrYellow=0;
			currImage.resetCorrection();
			applyCorrection();
		}

		public function compliteImage():void{
			if(!currImage) return;
			currImage.corrBright=corrBright;
			currImage.corrCyan=corrCyan;
			currImage.corrMagenta=corrMagenta;
			currImage.corrYellow=corrYellow;
			currImage.done=true;
			//has correction?
			if(currImage.corrBright==0 && currImage.corrCyan==0 && currImage.corrMagenta==0 && currImage.corrYellow) return;
			var sf:File=tmpRoot.resolvePath(FLD_CORRECTION+File.separator+currImage.corrFileName);
			var df:File=tmpRoot.resolvePath(FLD_DONE);
			if(currImage.subFolder) df=df.resolvePath(currImage.subFolder);
			df=df.resolvePath(currImage.name);
			try{
				sf.copyTo(df,true);
			}catch(error:Error){
				Alert.show(error.message);
			}
		}

		private function onMpcCreate(e:IMRunerEvent):void{
			var im:IMRuner=e.target as IMRuner;
			if(im){
				im.removeEventListener(IMRunerEvent.IM_COMPLETED, onApplyCorrection);
				//ci=im.targetObject as CCImage;
			}
			
			if(currImage){
				if(e.hasError){
					lastError=e.error;
					currImage.hasErr=true;
				}else{
					lastError='';
				}
				applyCorrection(false);
			}
		}
		
		private var oldCyan:int=0;
		private var oldMagenta:int=0;
		private var oldYellow:int=0;
		private var oldBright:int=0;
		
		private function getAdvance(ci:CCImage):CCImage{
			if(!ci) return null;
			var res:CCImage;
			if(oldCyan!=corrCyan){
				res=ci.clone();
				if(oldCyan>corrCyan){
					res.corrCyan-=ccStep;
				}else{
					res.corrCyan+=ccStep;
				}
				if(Math.abs(res.corrCyan)>100) res=null;
			}else if(oldMagenta!=corrMagenta){
				res=ci.clone();
				if(oldMagenta>corrMagenta){
					res.corrMagenta-=ccStep;
				}else{
					res.corrMagenta+=ccStep;
				}
				if(Math.abs(res.corrMagenta)>100) res=null;
			}else if(oldYellow!=corrYellow){
				res=ci.clone();
				if(oldYellow>corrYellow){
					res.corrYellow-=ccStep;
				}else{
					res.corrYellow+=ccStep;
				}
				if(Math.abs(res.corrYellow)>100) res=null;
			}else if(oldBright!=corrBright){
				res=ci.clone();
				if(oldBright>corrBright){
					res.corrBright-=ccStep;
				}else{
					res.corrBright+=ccStep;
				}
				if(Math.abs(res.corrBright)>100) res=null;
			}
			return res;
		}
		private function resetAdvanceDir():void{
			oldCyan=corrCyan;
			oldMagenta=corrMagenta;
			oldYellow=corrYellow;
			oldBright=corrBright;
		}

		private var runningTreads:Object;
		
		public function applyCorrection(resetDone:Boolean=true):void{
			if(!currImage) return;
			if(!runningTreads) runningTreads= new Object;
			if(resetDone) currImage.done=false;
			corrFile=null;
			var ci:CCImage=currImage.clone();
			ci.corrBright=corrBright;
			ci.corrCyan=corrCyan;
			ci.corrMagenta=corrMagenta;
			ci.corrYellow=corrYellow;
			//check if exists
			var f:File=tmpRoot.resolvePath(FLD_CORRECTION+File.separator+ci.corrFileName);
			if(f.exists){
				//is complited
				if(!runningTreads[ci.corrFileName]) corrFile=f.nativePath;
			}else{
				runCorrection(ci);
			}
			
			if(ccAdvance<=0) return;
			//run advance
			for (var i:int = 0; i < ccAdvance; i++){
				ci=getAdvance(ci);
				if(!ci) break;
				runCorrection(ci);
			}
			resetAdvanceDir();
		}
		
		private function runCorrection(ci:CCImage):void{
			if(!ci) return;

			//check if exists or statrted
			var f:File=tmpRoot.resolvePath(FLD_CORRECTION+File.separator+ci.corrFileName);
			if(f.exists || runningTreads[ci.corrFileName]) return;

			var cmd:IMCommand= new IMCommand(IMCommand.IM_CMD_CONVERT);
			cmd.folder=tmpRoot.resolvePath(FLD_CORRECTION).nativePath;
			cmd.add(MPC_ORG_FILE);
			if(ci.corrBright!=0){
				cmd.add('-brightness-contrast');
				cmd.add(ci.corrBright.toString());
			}
			
			//cyan +vals -move red black point, -vals move red white point 
			if(ci.corrCyan!=0){
				cmd.add('-channel'); cmd.add('red'); cmd.add('-level');
				//amount
				if(ci.corrCyan>0){
					cmd.add(ci.corrCyan.toString()+'%x100%');
				}else{
					cmd.add('0x'+(100+ci.corrCyan).toString()+'%');
				}
				//reset
				cmd.add('+channel');
			}
			
			//magenta +vals -move green black point, -vals move green white point 
			if(ci.corrMagenta!=0){
				cmd.add('-channel'); cmd.add('green'); cmd.add('-level');
				//amount
				if(ci.corrMagenta>0){
					cmd.add(ci.corrMagenta.toString()+'%x100%');
				}else{
					cmd.add('0x'+(100+ci.corrMagenta).toString()+'%');
				}
				//reset
				cmd.add('+channel');
			}
			
			//Yellow +vals -move blue black point, -vals move blue white point 
			if(ci.corrYellow!=0){
				cmd.add('-channel'); cmd.add('blue'); cmd.add('-level');
				//amount
				if(ci.corrYellow>0){
					cmd.add(ci.corrYellow.toString()+'%x100%');
				}else{
					cmd.add('0x'+(100+ci.corrYellow).toString()+'%');
				}
				//reset
				cmd.add('+channel');
			}
			
			IMCommandUtil.setOutputParams(cmd);
			cmd.add(ci.corrFileName);
			//mark started
			runningTreads[ci.corrFileName]=true;
			//run
			var im:IMRuner=new IMRuner(Context.getAttribute('imPath'),cmd.folder);
			im.addEventListener(IMRunerEvent.IM_COMPLETED, onApplyCorrection);
			im.targetObject=ci;
			im.start(cmd);
		}

		private function onApplyCorrection(e:IMRunerEvent):void{
			var ci:CCImage;
			var im:IMRuner=e.target as IMRuner;
			if(im){
				im.removeEventListener(IMRunerEvent.IM_COMPLETED, onApplyCorrection);
				ci=im.targetObject as CCImage;
			}
			
			if(ci){
				//reset started mark
				delete runningTreads[ci.corrFileName];
				//show?
				if(ci.corrBright==corrBright 
					&& ci.corrCyan==corrCyan
					&& ci.corrMagenta==corrMagenta
					&& ci.corrYellow==corrYellow){
					corrFile=tmpRoot.resolvePath(FLD_CORRECTION+File.separator+ci.corrFileName).nativePath;
					if(e.hasError){
						lastError=e.error;
					}else{
						lastError='';
					}
				}
			}
		}

	}
}