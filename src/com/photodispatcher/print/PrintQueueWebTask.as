package com.photodispatcher.print
{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.factory.WebServiceBuilder;
	import com.photodispatcher.model.mysql.DbLatch;
	import com.photodispatcher.model.mysql.entities.AbstractEntity;
	import com.photodispatcher.model.mysql.entities.Order;
	import com.photodispatcher.model.mysql.entities.OrderExtraInfo;
	import com.photodispatcher.model.mysql.entities.OrderState;
	import com.photodispatcher.model.mysql.entities.PrintGroup;
	import com.photodispatcher.model.mysql.entities.SourceType;
	import com.photodispatcher.model.mysql.entities.StateLog;
	import com.photodispatcher.model.mysql.services.OrderService;
	import com.photodispatcher.service.web.BaseWeb;
	
	import flash.events.Event;
	
	import mx.collections.ArrayCollection;
	
	import org.granite.tide.Tide;

	public class PrintQueueWebTask extends PrintQueueTask
	{
		
		protected var ordersMap:Object;
		
		public function PrintQueueWebTask(printGroups:Array)
		{
			super(printGroups);
		}
		
		override protected function prepareQueueItems():void {
			
			ordersMap = {};
			
			var order:Order;
			var orders:Array = [];
			
			for each (var pg:PrintGroup in items) {
				
				order = ordersMap[pg.order_id];
				
				if(order){
					
					order.printGroups.addItem(pg);
					
				} else {
					
					order = ordersMap[pg.order_id] = createQueueOrder(pg);
					order.printGroups = new ArrayCollection([pg]);
					orders.push(order);
					
				}
				
				
			}
			
			queue = orders;
			
			
		}
		
		protected function createQueueOrder(pg:PrintGroup):Order {
			
			
			var order:Order = new Order();
			order.id = pg.order_id;
			order.source = pg.source_id;
			order.ftp_folder = pg.order_folder;
			order.state = OrderState.PRN_QUEUE;
			
			return order;
			
		}
		
		protected var currentService:BaseWeb;
		override protected function startCurrent():void {
			
			var order:Order = currentItem as Order;
			order.state = OrderState.PRN_WEB_CHECK;
			for each (var pg:PrintGroup in order.printGroups){
				pg.state = OrderState.PRN_WEB_CHECK;
			}
			
			currentService = WebServiceBuilder.build(Context.getSource(order.source));
			currentService.addEventListener(Event.COMPLETE,serviceCompleteHandler);
			currentService.getOrder(order);
			
		}
		
		protected function serviceCompleteHandler(event:Event):void
		{
			
			currentService.removeEventListener(Event.COMPLETE,serviceCompleteHandler);
			
			var order:Order = currentItem as Order;
			var pg:PrintGroup;
			
			if(currentService.hasError){
				
				for each (pg in order.printGroups){
					
					pg.state = OrderState.ERR_WEB;
					StateLog.logByPGroup(OrderState.ERR_WEB, pg.id,'Ошибка проверки на сайте: ' + currentService.errMesage);
					
				}
				
			} else {
				
				if(currentService.isValidLastOrder()){
					
					for each (pg in order.printGroups){
						
						if(pg){
							
							if(pg.state == OrderState.PRN_WEB_CHECK){
								
								pg.state = OrderState.PRN_WEB_OK;
								
								// проверка статуса на сайте прошла успешно, нужно положить в ready
								itemsReady.push(pg);
								
								
							} else {
								
								StateLog.logByPGroup(OrderState.ERR_WEB,pg.id,'Ошибка статуса при проверке на сайте ('+pg.state.toString()+')');
								
							}
							
						}
						
					}
					
					
					if(currentService.source.type == SourceType.SRC_FOTOKNIGA && currentService.getLastOrder()){
						
						var ei:OrderExtraInfo = currentService.getLastOrder().extraInfo;
						
						if(ei){
							
							ei.persistState=AbstractEntity.PERSIST_CHANGED;
							var osvc:OrderService = Tide.getInstance().getContext().byType(OrderService,true) as OrderService;
							var latch:DbLatch= new DbLatch(true);
							latch.addEventListener(Event.COMPLETE, extraInfoHandler);
							latch.addLatch(osvc.persistExtraInfo(ei));
							latch.start();
							
							return;
							
						}
						
					}
					
					
				} else {
					
					for each (pg in order.printGroups){
						pg.state = OrderState.CANCELED_SYNC;
					}
					
				}
				
			}
			
			currentService = null;
			startNext();
			
			
		}
		
		protected function extraInfoHandler(event:Event):void
		{
			
			var latch:DbLatch= event.target as DbLatch;
			
			if(latch){
				latch.removeEventListener(Event.COMPLETE, extraInfoHandler);
			}
			
			currentService = null;
			startNext();
			
		}
		
	}
}