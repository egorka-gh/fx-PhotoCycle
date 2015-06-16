package com.photodispatcher.provider.preprocess{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.event.OrderBuildEvent;
	import com.photodispatcher.event.OrderBuildProgressEvent;
	import com.photodispatcher.event.OrderPreprocessEvent;
	import com.photodispatcher.model.mysql.entities.OrderState;
	import com.photodispatcher.model.mysql.entities.Source;
	import com.photodispatcher.model.mysql.entities.StateLog;
	import com.photodispatcher.util.StrUtil;
	
	import flash.events.ProgressEvent;
	import flash.filesystem.File;

	public class OrderBuilderLocal extends OrderBuilderBase{

		public function OrderBuilderLocal(logStates:Boolean=true){
			super();
			//type=OrderBuilderBase.TYPE_LOCAL;
			this.logStates=logStates;
		}

		private var preprocessTask:PreprocessTask;
		
		override protected function startBuild():void{
			if((!lastOrder.printGroups || lastOrder.printGroups.length==0) && (!lastOrder.suborders || lastOrder.suborders.length==0)){	
				if(logStates) StateLog.log(lastOrder.state,lastOrder.id,'','Пустой заказ. Не требует подготовки');
				releaseComplite();
				return;
			}
			var source:Source=Context.getSource(lastOrder.source);
			if(!source){
				builderError('Internal error. Null source.');
				return;
			}
			//var dstFolder:String=Context.getAttribute('workFolder')+File.separator+StrUtil.toFileName(source.name);
			preprocessTask=new PreprocessTask(lastOrder,source.getWrkFolder(),source.getPrtFolder(),logStates);
			preprocessTask.addEventListener(OrderPreprocessEvent.ORDER_PREPROCESSED_EVENT, onOrderResize);
			preprocessTask.addEventListener(ProgressEvent.PROGRESS, onPreprocessProgress);

			preprocessTask.run();
		}
		
		override public function stop():void{
			if(preprocessTask){
				preprocessTask.removeEventListener(OrderPreprocessEvent.ORDER_PREPROCESSED_EVENT, onOrderResize);
				preprocessTask.removeEventListener(ProgressEvent.PROGRESS, onPreprocessProgress);
				preprocessTask.stop();
			}
			preprocessTask=null;
			isBusy=false;
			dispatchEvent(new OrderBuildProgressEvent());
		}
		
		
		private function onOrderResize(e:OrderPreprocessEvent):void{
			if(!preprocessTask) return;
			preprocessTask.removeEventListener(OrderPreprocessEvent.ORDER_PREPROCESSED_EVENT, onOrderResize);
			preprocessTask.removeEventListener(ProgressEvent.PROGRESS, onPreprocessProgress);
			if(e.err==0){
				releaseComplite();
			}else{
				releaseWithError(e.err,e.err_msg);
			}
			dispatchEvent(new OrderBuildProgressEvent());
		}

		private function onPreprocessProgress(e:OrderBuildProgressEvent):void{
			dispatchEvent(e.clone());
		}

	}
}