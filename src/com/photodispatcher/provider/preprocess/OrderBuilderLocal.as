package com.photodispatcher.provider.preprocess{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.event.OrderBuildEvent;
	import com.photodispatcher.event.OrderBuildProgressEvent;
	import com.photodispatcher.event.OrderPreprocessEvent;
	import com.photodispatcher.model.OrderState;
	import com.photodispatcher.model.Source;
	import com.photodispatcher.model.dao.StateLogDAO;
	import com.photodispatcher.util.StrUtil;
	
	import flash.events.ProgressEvent;
	import flash.filesystem.File;

	public class OrderBuilderLocal extends OrderBuilderBase{

		public function OrderBuilderLocal(logStates:Boolean=true){
			super();
			type=OrderBuilderBase.TYPE_LOCAL;
			this.logStates=logStates;
		}

		override protected function startBuild():void{
			if((!lastOrder.printGroups || lastOrder.printGroups.length==0) && (!lastOrder.suborders || lastOrder.suborders.length==0)){	
				if(logStates) StateLogDAO.logState(lastOrder.state,lastOrder.id,'','Пустой заказ. Не требует подготовки');
				releaseComplite();
				return;
			}
			var source:Source=Context.getSource(lastOrder.source);
			if(!source){
				builderError('Internal error. Null source.');
				return;
			}
			//var dstFolder:String=Context.getAttribute('workFolder')+File.separator+StrUtil.toFileName(source.name);
			var preprocessTask:PreprocessTask=new PreprocessTask(lastOrder,source.getWrkFolder(),source.getPrtFolder(),logStates);
			preprocessTask.addEventListener(OrderPreprocessEvent.ORDER_PREPROCESSED_EVENT, onOrderResize);
			preprocessTask.addEventListener(ProgressEvent.PROGRESS, onPreprocessProgress);

			preprocessTask.run();
		}
		
		override public function stop():void{
			// TODO implement
		}
		
		
		private function onOrderResize(e:OrderPreprocessEvent):void{
			var preprocessTask:PreprocessTask=e.target as PreprocessTask;
			if(preprocessTask){
				preprocessTask.removeEventListener(OrderPreprocessEvent.ORDER_PREPROCESSED_EVENT, onOrderResize);
				preprocessTask.removeEventListener(ProgressEvent.PROGRESS, onPreprocessProgress);
			}
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