package com.photodispatcher.service.messenger{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.event.CycleMessageEvent;
	import com.photodispatcher.interfaces.IMessageRecipient;
	import com.photodispatcher.model.mysql.entities.Order;
	import com.photodispatcher.model.mysql.entities.messenger.CycleMessage;
	import com.photodispatcher.model.mysql.entities.messenger.CycleStation;
	import com.photodispatcher.util.ArrayUtil;
	
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.TimerEvent;
	import flash.utils.Timer;
	
	import mx.collections.ArrayCollection;
	import mx.controls.Alert;
	import mx.messaging.ChannelSet;
	import mx.messaging.events.ChannelEvent;
	import mx.messaging.events.ChannelFaultEvent;
	import mx.messaging.events.MessageEvent;
	import mx.messaging.events.MessageFaultEvent;
	import mx.messaging.messages.AsyncMessage;
	
	import org.granite.gravity.Consumer;
	import org.granite.gravity.Producer;
	import org.granite.gravity.channels.GravityChannel;
	import org.granite.tide.service.ChannelType;
	import org.granite.tide.spring.Spring;

	[Event(name="cyclemessage", type="com.photodispatcher.event.CycleMessageEvent")]
	public class MessengerGeneric extends EventDispatcher implements IMessageRecipient{
		public static const PING_INTERVAL:int=5*60*1000;
		public static const DESTINATION:String='cycle';
		
		public static const TOPIC_BROADCAST:String='/broadcast';
		public static const TOPIC_STATUS:String='/status';
		public static const TOPIC_PREPARATION:String='/preparation';
		public static const TOPIC_PRNQUEUE:String='/prnqueue';

		public static const CMD_PING:int=1;
		public static const CMD_STATUS:int=2;
		
		public static const CMD_PRNQUEUE_REFRESH:int=3;

		public static const CMD_PREPARATION_START:int=4;
		public static const CMD_PREPARATION_STOP:int=5;
		
		[Bindable]
		public static var stations:ArrayCollection=new ArrayCollection(); //CycleStation
		
		protected static var consumerMap:Object;
		protected static var recipientMap:Object;
		protected static var producer:Producer;
		
		public static function get connected():Boolean{
			if(isConnecting) return false;
			if(producer && producer.connected) return true;
			return false;
		}
		
		private static var pingListener:MessengerGeneric;
		private static var stationsListener:MessengerGeneric;
		private static var isConnecting:Boolean;
		public static function connect(listenPing:Boolean=true):void{
			if(!stationsListener){
				stationsListener= new MessengerGeneric();
				subscribe(TOPIC_STATUS,stationsListener);
			}
			if(!pingListener && listenPing){
				pingListener= new MessengerGeneric();
				pingListener.addEventListener(CycleMessageEvent.CYCLE_MESSAGE, onBroadcast);
				subscribe(TOPIC_BROADCAST,pingListener);
			}
			if(isConnecting) return;
			//producer.connected ??
			if(producer) return;
			createProducer();
			startPingTimer();
		}
		private static function onBroadcast(event:CycleMessageEvent):void{
			if(event.message.command==CMD_PING && isMessage4Me(event.message)){
				sendPing();
			}
		}
		
		public static function isMessage4Me(message:CycleMessage):Boolean{
			if(!message) return false;
			if(message.recipient=='*') return true;
			return Context.station && Context.station.id==message.recipient;
		}

		private static function createProducer(topic:String=TOPIC_STATUS):void{
			//if(!channelUrl) return;
			
			//trun off messaging 
			//return;
			
			//isConnecting=true;
			trace('Messenger Producer create');
			
			if(!producer){
				//destroyProducer();
				producer=Spring.getInstance().mainServerSession.getProducer(DESTINATION,topic,ChannelType.LONG_POLLING);
				//producer= new Producer();
				producer.addEventListener(ChannelEvent.CONNECT, onProducerConnect);
				producer.addEventListener(ChannelEvent.DISCONNECT, onProducerDisconnect);
				producer.addEventListener(ChannelFaultEvent.FAULT, onProducerChannelFault);
				producer.addEventListener(MessageFaultEvent.FAULT, onProducerMessageFault);
			}
			/*
			producer.destination = DESTINATION;
			producer.channelSet=new ChannelSet();
			producer.channelSet.addChannel(new GravityChannel("gravityamf", channelUrl));
			producer.topic = topic;
			*/
			sendPing();
		}
		private static function onProducerConnect(event:ChannelEvent):void{
			trace('ProducerConnect');
			isConnecting=false;
			//TODO resubscribe recipients
			var topic:String;
			for (topic in recipientMap){
				//get create consumer
				if(!consumerMap) consumerMap= new Object();
				var consumer:Consumer=consumerMap[topic] as Consumer;
				if(!consumer){
					consumer=createConsumer(topic);
					if(consumer) consumerMap[topic]=consumer;
				}
			}
		}
		private static function onProducerDisconnect(event:ChannelEvent):void{
			if(forceDisconnect) return;
			trace('ProducerDisconnect');
			//destroy & reconnect
			destroyConsumers();
			destroyProducer();
			//reconnect();
		}
		private static function onProducerChannelFault(event:ChannelFaultEvent):void{
			if(forceDisconnect) return;
			trace('ProducerChannelFault '+ event.faultDetail);
			//destroy & reconnect
			destroyConsumers();
			destroyProducer();
			//reconnect();
		}
		private static function onProducerMessageFault(event:MessageFaultEvent):void{
			if(forceDisconnect) return;
			trace('ProducerMessageFault '+ event.faultString);
			if(producer && producer.connected){
				Alert.show(event.faultString +'. '+event.message);
			}else{
				//destroy & reconnect
				destroyConsumers();
				destroyProducer();
				//reconnect();
			}
		}
		private static function destroyProducer():void{
			/*
			if(producer){
				//if(producer.connected) producer.disconnect();
				producer.removeEventListener(ChannelEvent.CONNECT, onProducerConnect);
				producer.removeEventListener(ChannelEvent.DISCONNECT, onProducerDisconnect);
				producer.removeEventListener(ChannelFaultEvent.FAULT, onProducerChannelFault);
				producer.removeEventListener(MessageFaultEvent.FAULT, onProducerMessageFault);
				producer=null;
			}
			*/
		}
		
		private static var timer:Timer; 
		private static function reconnect():void{
			trace('Messenger Producer reconnect statrt timer');
			return;
			if(timer){
				timer.reset();
				timer.removeEventListener(TimerEvent.TIMER, onReconnectTimer);
			}
			timer= new Timer(PING_INTERVAL,1);
			timer.addEventListener(TimerEvent.TIMER, onReconnectTimer);
		}
		private static function onReconnectTimer(e:TimerEvent):void{
			if(timer){
				timer.reset();
				timer.removeEventListener(TimerEvent.TIMER, onReconnectTimer);
				timer=null;
			}
			createProducer();
		}

		private static var pingTimer:Timer; 
		private static function startPingTimer():void{
			if(!pingTimer){
				pingTimer= new Timer(PING_INTERVAL,0);
				pingTimer.addEventListener(TimerEvent.TIMER, onPingTimer);
			}else{
				pingTimer.reset();
			}
			pingTimer.start();
		}
		private static function onPingTimer(e:TimerEvent):void{
			sendPing();
		}
		private static function sendPing():void{
			/*
			var msg:CycleMessage= new CycleMessage();
			msg.sender=Context.station;
			msg.recipient='*';
			msg.command=CMD_PING;
			msg.topic=TOPIC_STATUS;
			*/
			sendMessage(CycleMessage.createMessage());
		}
		
		
		private static var forceDisconnect:Boolean;
		public static function disconnect():void{
			if(connected) sendMessage(CycleMessage.createStatusMessage(CycleStation.SATE_OFF,'Выход'));
			forceDisconnect=true;
			//stop listen & destroy all
			recipientMap=null;
			destroyConsumers();
			destroyProducer();
			forceDisconnect=false;
		}

		
		public static function sendMessage(message:CycleMessage):void{
			if(!message || !message.topic) return;
			trace('Messenger producer send message topic:'+message.topic);
			//if(!producer || (!connected && !(isConnecting && message.topic==TOPIC_STATUS))) return;
			if(!producer){
				trace('No producer, send canceled')
				return;
			}

			var msg:AsyncMessage = new AsyncMessage();
			msg.body = message;
			
			producer.topic=message.topic;
			producer.send(msg);
		}
		
		public static function unsubscribe(topic:String, recipient:IMessageRecipient):void{
			if(!topic || !recipient) return;
			if(recipientMap){
				var recipients:Array=recipientMap[topic] as Array;
				var idx:int=recipients.indexOf(recipient);
				if(idx>-1) recipients.splice(idx,1);
				if(recipients.length==0){
					delete recipientMap[topic];
					//remove consumer
					if(consumerMap){
						var consumer:Consumer=consumerMap[topic] as Consumer;
						if(consumer) destroyConsumer(consumer);
					}
				}
			}
		}
		
		public static function subscribe(topic:String, recipient:IMessageRecipient):void{
			if(!topic || !recipient) return;
			if(!recipientMap) recipientMap= new Object;
			var recipients:Array=recipientMap[topic] as Array;
			if(!recipients){
				recipients=[];
				recipientMap[topic]=recipients;
				recipients.push(recipient);
			}else if (recipients.indexOf(recipient)==-1){
				recipients.push(recipient);
			}
			if(connected){
				//get create consumer
				if(!consumerMap) consumerMap= new Object();
				var consumer:Consumer=consumerMap[topic] as Consumer;
				if(!consumer){
					consumer=createConsumer(topic);
					if(consumer) consumerMap[topic]=consumer;
				}
			}
		}
		private static function createConsumer(topic:String):Consumer{
			//if(!connected || !topic || !channelUrl) return null;
			if(!connected || !topic) return null;
			trace('Messenger Consumer create topic:'+topic);

			/*
			var consumer:Consumer= new Consumer();
			consumer.destination = DESTINATION;
			consumer.topic = topic;
			consumer.channelSet=new ChannelSet();
			consumer.channelSet.addChannel(new GravityChannel("gravityamf", channelUrl));
			*/
			var consumer:Consumer=Spring.getInstance().mainServerSession.getConsumer(DESTINATION,topic,ChannelType.LONG_POLLING);
			consumer.addEventListener(ChannelEvent.DISCONNECT,onConsumerDisconnect);
			consumer.addEventListener(ChannelFaultEvent.FAULT,onConsumerChannelFault);
			consumer.addEventListener(MessageFaultEvent.FAULT,onConsumerFault);
			consumer.addEventListener(MessageEvent.MESSAGE, onConsumerMessage);
			
			consumer.subscribe();
			return consumer;
		}
		private static function onConsumerDisconnect(event:ChannelEvent):void{
			if(forceDisconnect) return;
			var consumer:Consumer=event.target as Consumer;
			//destroy & reconnect?
			destroyConsumer(consumer);
		}
		private static function onConsumerChannelFault(event:ChannelFaultEvent):void{
			if(forceDisconnect) return;
			var consumer:Consumer=event.target as Consumer;
			//destroy & reconnect?
			destroyConsumer(consumer);
		}
		private static function onConsumerFault(event:MessageFaultEvent):void{
			if(forceDisconnect) return;
			var consumer:Consumer=event.target as Consumer;
			if(consumer && consumer.connected){
				Alert.show(event.faultString +'. '+event.message);
			}else{
				//destroy & reconnect?
				destroyConsumer(consumer);
			}
		}
		private static function onConsumerMessage(event:MessageEvent):void{
			if(forceDisconnect) return;
			trace('Messenger Consumer get message');
			var consumer:Consumer=event.target as Consumer;
			if(consumer && consumer.topic){
				trace('Messenger Consumer message topic:'+consumer.topic);
				//notify recipients 
				var recipients:Array;
				if(recipientMap) recipients=recipientMap[consumer.topic] as Array;
				var msg:CycleMessage=event.message.body as CycleMessage;
				if(msg){
					trace('Messenger Consumer message notify recipients');
					if(recipients){
						var recipient:IMessageRecipient;
						for each(recipient in recipients) recipient.getMessage(msg);
					}
					//refresh station
					trace('Messenger Consumer message refresh station');
					if(msg.sender){
						var st:CycleStation=getStation(msg.sender.id);
						if(!st){
							st=msg.sender;
							stations.addItem(st);
						}
						st.lastPing=new Date();
						if(msg.command==CMD_STATUS){
							st.state=msg.sender.state;
							st.stateComment=msg.message;
						}
					}
				}
			}
			trace('Messenger Consumer message processed');
		}
		
		private static function getStation(id:String):CycleStation{
			return ArrayUtil.searchItem('id',id,stations.source) as CycleStation; 
		}
		
		private static function destroyConsumers():void{
			if(!consumerMap) return;
			var topic:String;
			var topics:Array=[];
			for (topic in consumerMap) topics.push(topic);
			for each(topic in topics) destroyConsumer(consumerMap[topic] as Consumer);
			consumerMap=null;
		}
		
		private static function destroyConsumer(consumer:Consumer):void{
			if(consumer){
				consumer.removeEventListener(ChannelEvent.DISCONNECT,onConsumerDisconnect);
				consumer.removeEventListener(ChannelFaultEvent.FAULT,onConsumerChannelFault);
				consumer.removeEventListener(MessageFaultEvent.FAULT,onConsumerFault);
				consumer.removeEventListener(MessageEvent.MESSAGE, onConsumerMessage);
				if(consumerMap){
					delete consumerMap[consumer.topic];
				}
				if(consumer.connected){
					consumer.unsubscribe();
					//consumer.disconnect();
				}
			}
		}
		
		/*
		private static var _channelUrl:String;
		private static function get channelUrl():String{
			if(!_channelUrl){
				_channelUrl=Context.getServerRootUrl();//Context.getChatRootUrl();
				if(_channelUrl) _channelUrl=_channelUrl+'/gravityamf/amf';
			}
			return _channelUrl;
		}
		*/

		
		public function MessengerGeneric():void{
			super(null);
		}
		
		public function getMessage(message:CycleMessage):void{
			dispatchEvent(new CycleMessageEvent(message));
		}

	}
}