package com.photodispatcher.provider.preprocess{
	import com.jxl.chat.vo.InstructionConstants;
	import com.jxl.chat.vo.messages.ChatMessageVO;
	import com.jxl.chatserver.events.ServiceEvent;
	import com.jxl.chatserver.mvcs.services.ChatServerService;
	import com.jxl.chatserver.vo.ClientVO;
	import com.photodispatcher.context.Context;
	import com.photodispatcher.event.OrderBuildEvent;
	import com.photodispatcher.event.OrderBuildProgressEvent;
	import com.photodispatcher.model.mysql.entities.Order;
	import com.photodispatcher.model.mysql.entities.OrderState;
	import com.photodispatcher.util.ArrayUtil;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.ProgressEvent;
	import flash.sampler.NewObjectSample;
	import flash.utils.Dictionary;
	
	import mx.collections.ArrayCollection;
	import mx.controls.Alert;

	[Event(name="orderPreprocessed", type="com.photodispatcher.event.OrderBuildEvent")]
	public class PreprocessManager extends EventDispatcher{

		[Bindable(event="queueLenthChange")]
		public function get queueLenth():int{
			return queue.length;
		}

		[Bindable(event="queueLenthChange")]
		public function get errorOrdersLenth():int{
			return errOrders.length;
		}

		[Bindable(event="remoteBuildersCountChange")]
		public function get remoteBuildersCount():int{
			var result:int=0;
			if(buildesMap){
				var b:OrderBuilderBase;
				for each(b in buildesMap){
					if(b && b.type!=OrderBuilderBase.TYPE_LOCAL) result++;
				}
			}
			return result;
		}

		[Bindable]
		public  var orderList:ArrayCollection=new ArrayCollection();
		
		private function refreshOrderList(e:Event):void{
			orderList.source=queue.concat(errOrders);
			orderList.refresh();
			
		}
		
		[Bindable]
		public var lastError:String='';
		[Bindable]
		public var progressCaption:String='';

		private var buildesMap:Dictionary;
		private var queue:Array=[];
		private var errOrders:Array=[];
		
		public function PreprocessManager(){
			super();
			addEventListener('queueLenthChange',refreshOrderList);
		}
		
		public function resync(orders:Array):void{
			if(!orders) return;
			
			var a:Array=[];
			var wOrder:Order;
			var idx:int;

			//resync resize orders
			if(queue.length>0) a=a.concat(queue);
			if(a.length>0){
				for each(wOrder in a){
					if(wOrder){
						idx=ArrayUtil.searchItemIdx('id',wOrder.id,orders);
						if(idx!=-1){
							//replace in sync array
							orders[idx]=wOrder;
						}else{
							//add to sync array
							orders.unshift(wOrder);
						}
					}
				}
			}
			
			//restart resizeErrOrders
			if(errOrders.length>0){
				for each(wOrder in errOrders){
					if(wOrder){
						idx=ArrayUtil.searchItemIdx('id',wOrder.id,orders);
						if(idx!=-1){
							//reset ??
							//replace in sync array
							orders[idx]=wOrder;
						}
					}
				}
				errOrders=[];
			}
			dispatchEvent(new Event('queueLenthChange'));
			//wake up
			startNext();
		}
		
		public function build(order:Order):void{
			if(!order) return;
			order.state=OrderState.PREPROCESS_WAITE;
			queue.push(order);
			dispatchEvent(new Event('queueLenthChange'));
			startNext();
		}
		
		public function init():void{
			var chatServer:ChatServerService=ChatServerService.instance;
			/*
			//TODO implement process allready connected
			if(!chatServer.isOnline) chatServer.startServer();
			*/
			chatServer.addEventListener(ServiceEvent.CHAT_SERVER_SERVICE_ERROR,onServerError);
			chatServer.addEventListener(ServiceEvent.CHAT_SERVER_SERVICE_USER_ONLINE,onNewBuilder);
			chatServer.addEventListener(ServiceEvent.CHAT_SERVER_SERVICE_USER_OFFLINE,onBuilderDisconnect);
			chatServer.addEventListener(ServiceEvent.CHAT_SERVER_SERVICE_USER_MESSAGE,onChatMessage);
			
			if(!chatServer.isOnline){
				var servIp:String;
				servIp=Context.getAttribute("serverIP");
				if(servIp){
					chatServer.startServer(servIp);
				}
			}
			buildesMap=new Dictionary();
			var lb:OrderBuilderLocal= new OrderBuilderLocal();
			listenBuilder(lb);
			buildesMap['local']=lb;
		}
		
		public function destroy():void{
			//TODO implement
		}
		
		private function onServerError(evt:ServiceEvent):void{
			Alert.show('Ошибка chatServer: '+evt.lastError);
		}
		private function onNewBuilder(evt:ServiceEvent):void{
			var client:ClientVO=evt.user;
			if(client && (client.userType==ClientVO.TYPE_BUILDER || client.userType==ClientVO.TYPE_HELPER)){
				if(!buildesMap[client]){
					var builder:OrderBuilderBase=new OrderBuilderRemote(client);
					listenBuilder(builder);
					buildesMap[client]=builder;
					dispatchEvent(new Event('remoteBuildersCountChange'));
					startNext();
				}
			}
		}
		private function onBuilderDisconnect(evt:ServiceEvent):void{
			var builder:OrderBuilderRemote=buildesMap[evt.user] as OrderBuilderRemote;
			if(builder){
				if(builder.isBusy ){
					//release order
					//TODO order can be still processed
					resetOrder(builder.lastOrder);
				}
				destroyBuilder(builder);
				delete buildesMap[evt.user];
			}
			dispatchEvent(new Event('remoteBuildersCountChange'));
			startNext();
		}
		private function resetOrder(order:Order):void{
			if(order && order.state!=OrderState.PREPROCESS_WAITE){
				order.state=OrderState.PREPROCESS_WAITE;
			}
		}
		private function onChatMessage(evt:ServiceEvent):void{
			var msg:ChatMessageVO= evt.message;
			if(!msg) return;
			switch(msg.instructions){
				case InstructionConstants.CLIENT_SET_USERTYPE:
					//add if new
					checkUserMode(evt);
					break;
			}
			var builder:OrderBuilderRemote=buildesMap[evt.user] as OrderBuilderRemote;
			if(builder) builder.processMessage(evt.message);
		}
		
		private function checkUserMode(evt:ServiceEvent):void{
			var client:ClientVO=evt.user;
			var builder:OrderBuilderRemote;
			if(client){
				builder=buildesMap[client] as OrderBuilderRemote;
				if(builder){
					if(!builder.isBusy && client.userType!=ClientVO.TYPE_BUILDER && client.userType!=ClientVO.TYPE_HELPER){
						destroyBuilder(builder);
						delete buildesMap[client];
						dispatchEvent(new Event('remoteBuildersCountChange'));
					}
				}else{
					onNewBuilder(evt);
				}
			}
		}

		private function listenBuilder(builder:OrderBuilderBase):void{
			if(!builder) return;
			builder.addEventListener(OrderBuildEvent.BUILDER_ERROR_EVENT,onBuilderError);
			builder.addEventListener(OrderBuildEvent.ORDER_PREPROCESSED_EVENT, onOrderPreprocessed);
			builder.addEventListener(ProgressEvent.PROGRESS, onPreprocessProgress);
		}
		private function destroyBuilder(builder:OrderBuilderBase):void{
			if(!builder) return;
			builder.removeEventListener(OrderBuildEvent.BUILDER_ERROR_EVENT,onBuilderError);
			builder.removeEventListener(OrderBuildEvent.ORDER_PREPROCESSED_EVENT, onOrderPreprocessed);
			builder.removeEventListener(ProgressEvent.PROGRESS, onPreprocessProgress);
		}
		
		private function onPreprocessProgress(e:OrderBuildProgressEvent):void{
			progressCaption=e.caption;
			dispatchEvent(e.clone());
		}

		private function onBuilderError(evt:OrderBuildEvent):void{
			//builder internal error
			resetOrder(evt.order);
			var builder:OrderBuilderBase=evt.target as OrderBuilderBase;
			var msg:String='';
			if(builder){
				if(builder.type==OrderBuilderBase.TYPE_LOCAL){
					msg='Local builder: ';
				}else if(builder is OrderBuilderRemote){
					msg=(builder as OrderBuilderRemote).client.username+': ';
				}
			}
			lastError=msg+evt.err_msg;
			//TODO do something vs builder
			startNext();
		}
		private function onOrderPreprocessed(evt:OrderBuildEvent):void{
			//order complited
			//remove from queue
			var idx:int=-1;
			if(evt.order) idx=queue.indexOf(evt.order);
			if(idx!=-1) queue.splice(idx,1);
			if(evt.err<0){
				//completed vs error
				if(evt.order){
					//evt.order.resetPreprocess();
					errOrders.push(evt.order);
				}
			}else{
				dispatchEvent(evt.clone());
			}
			dispatchEvent(new Event('queueLenthChange'));
			startNext();
		}
		
		private function startNext():void{
			if(queue.length==0) return;

			//get order
			var o:Order;
			var order:Order;
			for each(o in queue){
				if(o && o.state==OrderState.PREPROCESS_WAITE){
					order=o;
					break;
				}
			}
			if(!order) return;

			var toKill:Array=[];
			//get builder
			var b:OrderBuilderBase;
			var builder:OrderBuilderBase;
			for each(b in buildesMap){
				if(b && !b.isBusy){
					if(isBuilderValid(b)){ //chek if remote is still builder
						if(b.skipOnReject){
							b.skipOnReject=false;
						}else{
							if(!builder){
								builder=b;
							}else{
								if(builder.type==OrderBuilderBase.TYPE_LOCAL){
									builder=b;
								}else if(b.type!=OrderBuilderBase.TYPE_LOCAL && b.lastBuildDate.time<builder.lastBuildDate.time){
									builder=b;
								}
							}
						}
					}else{
						toKill.push(b);
					}
				}
			}
			if(toKill.length){
				var rb:OrderBuilderRemote;
				for each (rb in toKill){
					if(rb){
						destroyBuilder(rb);
						delete buildesMap[rb.client];
					}
				}
				dispatchEvent(new Event('remoteBuildersCountChange'));
			}
			
			if(!builder) return;

			builder.build(order);
		}

		private function isBuilderValid(builder:OrderBuilderBase):Boolean{
			if (!builder) return false;
			if(builder.type==OrderBuilderBase.TYPE_LOCAL) return true;
			var rb:OrderBuilderRemote= builder as OrderBuilderRemote;
			if (!rb) return false;
			return  rb.client.userType==ClientVO.TYPE_BUILDER || rb.client.userType==ClientVO.TYPE_HELPER;
		}
	}
} 