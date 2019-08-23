package com.photodispatcher.provider.ftp
{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.event.ImageProviderEvent;
	import com.photodispatcher.model.mysql.entities.Order;
	import com.photodispatcher.model.mysql.entities.Source;
	import com.photodispatcher.provider.fbook.download.FBookDownloadManager;
	import com.photodispatcher.util.StrUtil;
	
	import flash.events.Event;
	import flash.filesystem.File;
	
	public class DownloadQueueManagerPixelPark extends DownloadQueueManager{
		
		public function DownloadQueueManagerPixelPark(source:Source=null){
			super(source);
		}
		
		override public function clearCache():void{
			// do nothing
		}
		
		override public function destroy():void{
			// TODO implement
			if(isStarted) stop();
		}
		
		override public function get fbDownloadManager():FBookDownloadManager{
			return null;
		}
		
		override protected function fetch(forceReset:Boolean=false):Order{
			// do nothing
			return null;
		}
		
		override protected function getOrderById(orderId:String, pop:Boolean=false):Order{
			// do nothing
			return null;
		}
		
		override protected function onDownloadFault(event:ImageProviderEvent):void {
			// do nothing
			return;
		}
		
		override public function reSync(orders:Array):void{
			// do nothing
			return;
		}
		
		override protected function removeOrder(order:Order):void{
			// do nothing
			return;
		}
		
		override public function resetErrLimit():void{
			// do nothing
			return;
		}
		
		override protected function resetOrder(order:Order):void{
			// TODO implement
			
		}
		
		override protected function resetOrderState(order:Order):void{
			// TODO implement
		}
		
		/* TODO implement
		override public function get speed():Number
		{
			// TODO Auto Generated method stub
			return super.speed;
		}
		*/
		
		override public function start():void{
			// TODO implement

			//reset
			lastError='';
			downloadCaption='Тут будет какая то инфа';

			//check
			if(!source){
				flowError('Ошибка инициализации');
				return;
			}

			/*
			//check config production
			if(source.type==SourceType.SRC_FOTOKNIGA && Context.getProduction()==0){
				flowError('Не назначено производство');
				return;
			}
			*/
			
			//detect lockal folder
			var dstFolder:String=Context.getAttribute('workFolder');
			if(!dstFolder){
				flowError('Не задана рабочая папка');
				return;
			}
			var file:File=new File(dstFolder);
			if(!file.exists || !file.isDirectory){
				flowError('Не задана рабочая папка');
				return;
			}
			//check create source folder
			file=file.resolvePath(StrUtil.toFileName(source.name));
			try{
				if(!file.exists) file.createDirectory();
			}catch(e:Error){
				flowError('Ошибка доступа. Папка: '+file.nativePath);
				return;
			}
			localFolder=file.nativePath;
			
			//prt folder
			dstFolder=Context.getAttribute('prtPath');
			if(!dstFolder){
				Context.setAttribute('prtPath',Context.getAttribute('workFolder'));
			}else{
				file=new File(dstFolder);
				if(!file.exists || !file.isDirectory){
					flowError('Не задана папка подготовленных заказов');
					return;
				}
				//check create source folder
				file=file.resolvePath(StrUtil.toFileName(source.name));
				try{
					if(!file.exists) file.createDirectory();
				}catch(e:Error){
					flowError('Ошибка доступа. Папка: '+file.nativePath);
					return;
				}
			}
			
			_isStarted=true;
			forceStop=false;
			dispatchEvent(new Event('isStartedChange'));
		}
		
		override public function stop():void{
			// TODO implement
			_isStarted=false;
			forceStop=true;
			speed=0;
			dispatchEvent(new Event('queueLenthChange'));
			dispatchEvent(new Event('isStartedChange'));
		}
		
		override protected function unCaptureOrder(orderId:String):void{
			// do nothing
		}
		
		
	}
}