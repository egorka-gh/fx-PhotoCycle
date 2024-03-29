package com.photodispatcher.view.menu{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.event.AsyncSQLEvent;
	import com.photodispatcher.model.mysql.DbLatch;
	import com.photodispatcher.model.mysql.entities.Order;
	import com.photodispatcher.model.mysql.entities.OrderState;
	import com.photodispatcher.model.mysql.entities.PrintGroup;
	import com.photodispatcher.model.mysql.entities.StateLog;
	import com.photodispatcher.model.mysql.services.OrderService;
	import com.photodispatcher.model.mysql.services.OrderStateService;
	import com.photodispatcher.printer.Printer;
	import com.photodispatcher.view.OrderInfoPopup;
	import com.photodispatcher.view.PasswPopup;
	
	import flash.events.Event;
	import flash.events.MouseEvent;
	
	import mx.collections.ArrayCollection;
	import mx.controls.Alert;
	import mx.controls.FlexNativeMenu;
	import mx.events.FlexEvent;
	import mx.events.FlexNativeMenuEvent;
	
	import org.granite.tide.Tide;
	
	import spark.components.DataGrid;
	import spark.components.gridClasses.GridSelectionMode;
	import spark.events.GridSelectionEvent;
	import spark.events.PopUpEvent;
	
	public class GridContexMenu extends FlexNativeMenu{
		public static const SEPARATOR:int=0;
		public static const CANCEL_ORDER:int=1;
		public static const FORVARD_FTP:int=2;
		public static const SHOW_ORDER:int=3;
		public static const RESET_ERRLIMIT:int=4;
		public static const PRINT_TICKET:int=5;
		public static const CANCEL_PRINT_STATE:int=6;
		
		private var grid:DataGrid;
		[Bindable]
		private var menuItems:ArrayCollection;
		
		public function GridContexMenu(dataGrid:DataGrid, actions:Array=null){
			super();
			grid=dataGrid;
			if(!grid) return;
			setContextMenu(grid);
			menuItems=new ArrayCollection();
			dataProvider=menuItems;
			addEventListener(FlexNativeMenuEvent.ITEM_CLICK,onclick);
			grid.addEventListener(FlexEvent.VALUE_COMMIT,onSelection);
			if(actions){
				var item:Object;
				for each(var o:Object in actions){
					switch(o){
						case SEPARATOR:
							item={label:'',type:'separator'};
							menuItems.addItem(item);
							break;
						case CANCEL_ORDER:
							item={label:'Отменить заказ',enabled:false,callBack:null,newState:0, action:CANCEL_ORDER};
							menuItems.addItem(item);
							break;
						case FORVARD_FTP:
							item={label:'Загузить внеочереди',enabled:false,callBack:null,newState:0, action:FORVARD_FTP};
							menuItems.addItem(item);
							break;
						case SHOW_ORDER:
							item={label:'Окрыть заказ',enabled:false,callBack:null,newState:0, action:SHOW_ORDER};
							menuItems.addItem(item);
							break;
						case RESET_ERRLIMIT:
							item={label:'Сбросить ошибку',enabled:false,callBack:null,newState:0, action:RESET_ERRLIMIT};
							menuItems.addItem(item);
							break;
						case PRINT_TICKET:
							item={label:'Печать квитка',enabled:false,callBack:null,newState:0, action:PRINT_TICKET};
							menuItems.addItem(item);
							break;
						case CANCEL_PRINT_STATE:
							item={label:'Сброс статуса печати',enabled:false,callBack:null,newState:0, action:CANCEL_PRINT_STATE};
							menuItems.addItem(item);
							break;
					}
					
				}
			}
			if(menuItems.length>0){
				item={label:'',type:'separator'};
				menuItems.addItem(item);
				addItem();
				item={label:'Выделить все',enabled:(grid.selectionMode==GridSelectionMode.MULTIPLE_ROWS),callBack:null,newState:0, action:-1};
				menuItems.addItem(item);
				item={label:'Снять выделение',enabled:true,callBack:null,newState:0, action:-2};
				menuItems.addItem(item);
			}
		}
		
		private function onSelection(e:FlexEvent):void{
			//check enabled
			var enabled:Boolean=grid.selectedItems && grid.selectedItems.length>0;
			for each (var item:Object in menuItems){
				if(item.label && item.action>=0) item.enabled=enabled;
			}
			menuItems.refresh();
		}
		private function onclick(e:FlexNativeMenuEvent):void{
			var item:Object=e.item;
			//check action
			switch(item.action){
				case -1:
					if(grid){
						grid.selectAll();
						grid.dispatchEvent(new FlexEvent(FlexEvent.VALUE_COMMIT));
					}
					break;
				case -2:
					if(grid){
						grid.clearSelection();
						grid.dispatchEvent(new FlexEvent(FlexEvent.VALUE_COMMIT));
					}
					break;
				case CANCEL_ORDER:
					cancelOrders();
					break;
				case FORVARD_FTP:
					forvardOrders();
					break;
				case SHOW_ORDER:
					showOrder();
					break;
				case RESET_ERRLIMIT:
					resetOrdersErrLimit();
					break;
				case PRINT_TICKET:
					printTickets();
					break;
				case CANCEL_PRINT_STATE:
					cancelPrintState();
					break;
				
				default:
					//check external callBack
					if(item.callBack!=null) item.callBack(grid,item.param);
					break;
			}
		}
		
		public function addItem(itemLabel:String='',itemCallBack:Function=null, parameter:int=0):void{
			var item:Object;
			if(!itemLabel){
				item={label:'',type:'separator'};
				menuItems.addItemAt(item,0);
			}else{
				item={label:itemLabel,enabled:false,callBack:itemCallBack,param:parameter, action:0};
				menuItems.addItemAt(item,0);
			}
		}
		
		public function removeByParameter(preserveParam:int):void{
			var newItems:Array=[];
			var item:Object;
			for each (item in menuItems){
				if(!item.hasOwnProperty('param') || item.param==0 || item.param==preserveParam) newItems.push(item);
			}
			menuItems.source=newItems;
			menuItems.refresh();
		}

		public function showOrder():void{
			MenuCommonActions.showOrder(grid.selectedItem);
			/*
			var orderId:String;
			if(grid.selectedItem is Order){
				orderId=(grid.selectedItem as Order).id;
			}else if(grid.selectedItem is PrintGroup){
				orderId=(grid.selectedItem as PrintGroup).order_id;
			}else if(grid.selectedItem is StateLog){
				orderId=(grid.selectedItem as StateLog).order_id;
			}
			if(orderId){
				var pop:OrderInfoPopup=new OrderInfoPopup();
				pop.show(orderId);
			}
			*/
		}
		
		public function forvardOrders():void{
			var order:Order; 
			for each(var o:Object in grid.selectedItems){
				order=o as Order;
				if(order && order.state==OrderState.FTP_WAITE){
					order.state=OrderState.FTP_FORWARD;
					order.ftpForwarded=true;
				}
			}
		}

		public function printTickets():void{
			var ticketPass:String=Context.getAttribute('ticketPass');
			if(!ticketPass){
				_printTickets();
			}else{
				var passPop:PasswPopup= new PasswPopup();
				passPop.addEventListener(PopUpEvent.CLOSE, onTicketPassPass);
				passPop.show(ticketPass);
			}
		}
		protected function onTicketPassPass(event:PopUpEvent):void{
			var passPop:PasswPopup=event.target as PasswPopup;
			if(passPop) passPop.removeEventListener(PopUpEvent.CLOSE, onTicketPassPass);
			if(event.commit){
				_printTickets();
			}
		}

		private function _printTickets():void{
			var pg:PrintGroup;
			for each(var o:Object in grid.selectedItems){
				pg=o as PrintGroup;
				if(pg && pg.id){
					Printer.instance.printOrderTicket(pg);
				}
			}
		}

		public function cancelPrintState():void{
			var pg:PrintGroup;
			var ids:Array=[];
			for each(var o:Object in grid.selectedItems){
				pg=o as PrintGroup;
				if(pg && pg.id && pg.state>OrderState.PRN_WAITE && pg.state<OrderState.PRN_PRINT){
					pg.state=OrderState.PRN_WAITE;
					ids.push(pg.id);
				}
			}
			if(ids.length==0) return;
			var svc:OrderStateService=Tide.getInstance().getContext().byType(OrderStateService,true) as OrderStateService;
			var latch:DbLatch= new DbLatch();
			//latch.addEventListener(Event.COMPLETE,onCancelPost);
			latch.addLatch(svc.printCancel(ids));
			latch.start();
		}

		public function resetOrdersErrLimit():void{
			var order:Order; 
			for each(var o:Object in grid.selectedItems){
				order=o as Order;
				if(order && order.exceedErrLimit){
					order.resetErrCounter();
					if(order.state<0 && order.state!=OrderState.ERR_WRITE_LOCK) order.state=OrderState.FTP_WAITE;
				}
			}
		}

		public function cancelOrders():void{
			if(grid.selectedIndex==-1) return;
			var toCancel:Array=[];
			for each(var o:Object in grid.selectedItems){
				toCancel.push(o);
			}
			MenuCommonActions.cancelOrders(toCancel);
		}
		
		/*
		private var canceled:Array;
		public function cancelOrders():void{
			var orderIds:Array=[];
			canceled=[];
			var o:Object;
			var order:Order;
			var pg:PrintGroup;
			var orderMap:Object;
			if(grid.selectedIndex==-1) return;
			if(grid.selectedItem is Order){
				//orders grid
				for each(o in grid.selectedItems){
					order=o as Order;
					if(order && order.state<OrderState.CANCELED_SYNC){
						canceled.push(order);
						orderIds.push(order.id);
					}
				}
			}else if(grid.selectedItem is PrintGroup){
				//print groups grid
				orderMap= new Object;
				for each(o in grid.selectedItems){
					pg=o as PrintGroup;
					if(pg && pg.state<OrderState.CANCELED_SYNC){
						canceled.push(pg);
						orderMap[pg.order_id]=pg.order_id;
					}
				}
				for (o in orderMap) orderIds.push(o);
			}
			if(canceled.length>0){
				var svc:OrderService=Tide.getInstance().getContext().byType(OrderService,true) as OrderService;
				var latch:DbLatch= new DbLatch();
				latch.addEventListener(Event.COMPLETE,onOrdersCancel);
				latch.addLatch(svc.cancelOrders(orderIds, OrderState.CANCELED));
				latch.start();
			}
		}
		private function onOrdersCancel(e:Event):void{
			var latch:DbLatch=e.target as DbLatch;
			if(latch){
				latch.removeEventListener(Event.COMPLETE,onOrdersCancel);
				if(latch.complite){
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
			canceled=null;
		}
		*/

		
	}
}