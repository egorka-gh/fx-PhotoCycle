package com.photodispatcher.view.menu{
	import com.photodispatcher.model.mysql.DbLatch;
	import com.photodispatcher.model.mysql.entities.Order;
	import com.photodispatcher.model.mysql.entities.OrderState;
	import com.photodispatcher.model.mysql.entities.PrintGroup;
	import com.photodispatcher.model.mysql.entities.StateLog;
	import com.photodispatcher.model.mysql.services.OrderService;
	import com.photodispatcher.view.OrderInfoPopup;
	
	import flash.events.Event;
	
	import org.granite.tide.Tide;

	public class MenuCommonActions{
		
		public static function showOrder(item:Object):void{
			if(!item) return;
			var orderId:String;
			if(item is Order){
				orderId=(item as Order).id;
			}else if(item is PrintGroup){
				orderId=(item as PrintGroup).order_id;
			}else if(item is StateLog){
				orderId=(item as StateLog).order_id;
			}
			if(orderId){
				var pop:OrderInfoPopup=new OrderInfoPopup();
				pop.show(orderId);
			}
		}

		public static function cleanUpOrder(item:Object, state:int):DbLatch{
			var order:Order=item as Order;
			if(!order || state<100) return null;
			var orderId:String=order.id;
			if(!orderId) return null;

			var o:Object=new Object;
			o.order=order;
			o.oldState=order.state;
			order.state=state;

			var svc:OrderService=Tide.getInstance().getContext().byType(OrderService,true) as OrderService;
			var latch:DbLatch= new DbLatch();
			latch.callContext=o;
			latch.addEventListener(Event.COMPLETE,onOrderClean);
			latch.addLatch(svc.cleanUpOrder(orderId, state));
			latch.start();
			return latch;
		}
		private static function onOrderClean(e:Event):void{
			var latch:DbLatch=e.target as DbLatch;
			if(latch){
				latch.removeEventListener(Event.COMPLETE,onOrderClean);
				if(!latch.complite){
					var o:Object=latch.callContext;
					if(o){
						var order:Order=o.order as Order;
						var oldState:int=o.oldState;
						if(order && oldState) order.state=oldState;
					}
				}
			}
		}

		public static function setOrderState(item:Object, newState:int):DbLatch{
			var order:Order=item as Order;
			if(!order || newState<=0) return null;
			var o:Object=new Object;
			o.order=order;
			o.oldState=order.state;
			order.state=newState;
			
			var svc:OrderService=Tide.getInstance().getContext().byType(OrderService,true) as OrderService;
			var latch:DbLatch= new DbLatch();
			latch.callContext=o;
			latch.addEventListener(Event.COMPLETE,onsetOrderState);
			latch.addLatch(svc.setState(order));
			latch.start();
			return latch;
		}
		private static function onsetOrderState(e:Event):void{
			var latch:DbLatch=e.target as DbLatch;
			if(latch){
				latch.removeEventListener(Event.COMPLETE,onsetOrderState);
				if(!latch.complite){
					var o:Object=latch.callContext;
					if(o){
						var order:Order=o.order as Order;
						var oldState:int=o.oldState;
						if(order && oldState){
							order.state=oldState;
						}
					}
				}
			}
		}

		public static function cancelOrders(items:Array):void{
			if(!items || items.length==0) return;
			
			var orderIds:Array=[];
			var canceled:Array=[];
			var o:Object;
			var order:Order;
			var pg:PrintGroup;
			var orderMap:Object=new Object;

			for each(o in items){
				if(o is Order){
					order=o as Order;
					if(order && order.state<OrderState.CANCELED_SYNC){
						canceled.push(order);
						//orderIds.push(order.id);
						orderMap[order.id]=order.id;
					}
				}else if(o is PrintGroup){
					pg=o as PrintGroup;
					if(pg && pg.state<OrderState.CANCELED_SYNC){
						canceled.push(pg);
						orderMap[pg.order_id]=pg.order_id;
					}
				}
			}
			for (o in orderMap) orderIds.push(o);

			if(canceled.length>0){
				var svc:OrderService=Tide.getInstance().getContext().byType(OrderService,true) as OrderService;
				var latch:DbLatch= new DbLatch();
				latch.callContext=canceled;
				latch.addEventListener(Event.COMPLETE,onOrdersCancel);
				latch.addLatch(svc.cancelOrders(orderIds, OrderState.CANCELED));
				latch.start();
			}
		}
		private static function onOrdersCancel(e:Event):void{
			var latch:DbLatch=e.target as DbLatch;
			if(latch){
				latch.removeEventListener(Event.COMPLETE,onOrdersCancel);
				if(latch.complite){
					var canceled:Array=latch.callContext as Array;
					if(!canceled) return;
					var order:Order; 
					var pg:PrintGroup;
					for each(var o:Object in canceled){
						if(o is Order){
							order=o as Order;
							order.state=OrderState.CANCELED;
						}else if(o is PrintGroup){
							pg=o as PrintGroup;
							pg.state=OrderState.CANCELED;
						}
					}
				}
			}
		}


	}
}