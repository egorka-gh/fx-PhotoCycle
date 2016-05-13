package com.photodispatcher.service.messenger{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.model.mysql.entities.Order;
	
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	
	import mx.controls.Alert;
	import mx.messaging.ChannelSet;
	import mx.messaging.events.MessageEvent;
	import mx.messaging.messages.AsyncMessage;
	
	import org.granite.gravity.Consumer;
	import org.granite.gravity.Producer;
	import org.granite.gravity.channels.GravityChannel;
	
	public class MessengerGeneric extends EventDispatcher{
		public static const DESTINATION:String='cycle';

		public static const TOPIC_PREPARATION:String='/preparation';
		
		public function MessengerGeneric(){
			super(null);
		}
		
		protected var consumer:Consumer;
		protected var producer:Producer;
		
		public function connect():void{
			var url:String=Context.getServerRootUrl();
			if(!url) return;
			
			url=url+'/gravityamf/amf';
			consumer = new Consumer();
			consumer.destination = DESTINATION;
			consumer.topic = "discussion";
			consumer.channelSet=new ChannelSet();
			consumer.channelSet.addChannel(new GravityChannel("gravityamf", url));
			consumer.subscribe();
			consumer.addEventListener(MessageEvent.MESSAGE, messageHandler);
			
			producer = new Producer();
			producer.destination = DESTINATION;
			producer.channelSet=new ChannelSet();
			producer.channelSet.addChannel(new GravityChannel("gravityamf", url));
			producer.topic = "discussion";	
		}
		
		public function disconnect():void {
			consumer.unsubscribe();
			consumer.disconnect();
			consumer = null;
			
			producer.disconnect();
			producer = null;
		}
		
		protected function messageHandler(event:MessageEvent):void {
			var msg:AsyncMessage = event.message as AsyncMessage;
			var o:Order= msg.body as Order;
			Alert.show("Received message: " + o.id);
		}
		
		public function send(message:String):void {
			var msg:AsyncMessage = new AsyncMessage();
			var o:Order= new Order();
			o.id=message;
			msg.body = o;
			producer.send(msg);
		}

	}
}