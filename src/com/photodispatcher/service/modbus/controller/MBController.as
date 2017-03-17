package com.photodispatcher.service.modbus.controller{
	import com.photodispatcher.service.modbus.ModbusClient;
	import com.photodispatcher.service.modbus.ModbusRequestEvent;
	import com.photodispatcher.service.modbus.ModbusResponseEvent;
	import com.photodispatcher.service.modbus.ModbusServer;
	import com.photodispatcher.service.modbus.data.ModbusADU;
	
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	
	[Event(name="connectChange", type="flash.events.Event")]
	[Event(name="error", type="flash.events.ErrorEvent")]
	[Event(name="complete", type="flash.events.Event")]
	[Event(name="controllerMesage", type="com.photodispatcher.event.ControllerMesageEvent")]
	public class MBController extends EventDispatcher{
		public static const MESSAGE_CHANEL_SERVER:int	=0;
		public static const MESSAGE_CHANEL_CLIENT:int	=1;

		
		public function MBController(){
			super(null);
		}
		
		[Bindable]
		public var server:ModbusServer;
		public var serverIP:String='';
		public var serverPort:int=503;
		
		[Bindable]
		public var client:ModbusClient;
		public var clientIP:String='';
		public var clientPort:int=502;
		
		public function start():void{
			if(server){
				server.removeEventListener(ErrorEvent.ERROR, onServerErr);
				server.removeEventListener(ModbusRequestEvent.REQUEST_EVENT, onServerADU);
				server.removeEventListener("connectChange", onServerConnect);
				server.stop();
				server=null;
			}
			server=new ModbusServer();
			server.addEventListener(ErrorEvent.ERROR, onServerErr);
			server.addEventListener(ModbusRequestEvent.REQUEST_EVENT, onServerADU);
			server.addEventListener("connectChange", onServerConnect);
			server.serverIP=serverIP;
			server.serverPort=serverPort;
			server.start();
		}
		
		public function stop():void{
			if(server){
				server.removeEventListener(ErrorEvent.ERROR, onServerErr);
				server.removeEventListener(ModbusRequestEvent.REQUEST_EVENT, onServerADU);
				server.removeEventListener("connectChange", onServerConnect);
				server.stop();
				server=null;
			}
			if(client){
				client.removeEventListener(ErrorEvent.ERROR, onClientErr);
				client.removeEventListener(ModbusResponseEvent.RESPONSE_EVENT, onClientADU);
				client.removeEventListener("connectChange", onClientConnect);
				client.stop();
				client=null;
			}
			dispatchEvent(new Event('connectChange'));
		}

		protected function onClientADU(evt:ModbusResponseEvent):void{
			//register writed
		}
		
		[Bindable('connectChange')]
		public function set connected(val:Boolean):void{dispatchEvent(new Event('connectChange'));}
		public function get connected():Boolean{
			return client && client.connected && server && server.cilentConnected;
		}
		
		public function get serverStarted():Boolean{
			return server && server.connected;
		}
		
		protected function onClientConnect(evt:Event):void{
			dispatchEvent(new Event('connectChange'));
			//implement client init
		}
		protected function onServerConnect(evt:Event):void{
			if(server && server.cilentConnected){
				if(client){
					client.removeEventListener(ErrorEvent.ERROR, onClientErr);
					client.removeEventListener(ModbusResponseEvent.RESPONSE_EVENT, onClientADU);
					client.removeEventListener("connectChange", onClientConnect);
					client.stop();
					client=null;
				}
				client=new ModbusClient();
				client.addEventListener(ErrorEvent.ERROR, onClientErr);
				client.addEventListener(ModbusResponseEvent.RESPONSE_EVENT, onClientADU);
				client.addEventListener("connectChange", onClientConnect);
				client.serverIP=clientIP;
				client.serverPort=clientPort;
				client.start();
				
			}
			dispatchEvent(new Event('connectChange'))
		}
		
		
		protected function onServerErr(evt:ErrorEvent):void{
			if(evt.errorID==0){
				logMsg('PC: '+ evt.text);
			}else{
				logErr('PC: '+ evt.text);
			}
		}
		protected function onClientErr(evt:ErrorEvent):void{
			if(evt.errorID==0){
				logMsg('Controller: '+ evt.text);
			}else{
				logErr('Controller: '+ evt.text);
			}
		}
		
		protected function onServerADU(evt:ModbusRequestEvent):void{
			//msg from controller
			var txt:String;
			var adu:ModbusADU=evt.adu;
			if(adu){
				txt='ADU ti:'+adu.transactionId;
				if(adu.pdu){
					txt=txt+'; PDU fnc:'+adu.pdu.functionCode+' adr:'+adu.pdu.address+' val:'+adu.pdu.value;
				}
			}else{
				txt='Empty ADU';
			}
			logMsg('<< '+txt);
			//Implement adu processing
		}
		
		protected function logErr(msg:String):void{
			dispatchEvent( new ErrorEvent(ErrorEvent.ERROR,false,false,msg,1));
		}
		protected function logMsg(msg:String):void{
			dispatchEvent( new ErrorEvent(ErrorEvent.ERROR,false,false,msg,0));
		}

	}
}