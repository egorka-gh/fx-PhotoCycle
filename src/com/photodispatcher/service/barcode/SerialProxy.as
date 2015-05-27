package com.photodispatcher.service.barcode
{
	import com.photodispatcher.event.SerialProxyEvent;
	import com.photodispatcher.shell.ProcessRunner;
	import com.photodispatcher.util.ArrayUtil;
	
	import flash.desktop.NativeProcess;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.NativeProcessExitEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.TimerEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.net.Socket;
	import flash.utils.Timer;
	
	import flashx.textLayout.factory.TruncationOptions;
	
	[Event(name="serialProxyStart", type="com.photodispatcher.event.SerialProxyEvent")]
	[Event(name="serialProxyError", type="com.photodispatcher.event.SerialProxyEvent")]
	[Event(name="serialProxyExit", type="com.photodispatcher.event.SerialProxyEvent")]
	[Event(name="serialProxyConnected", type="com.photodispatcher.event.SerialProxyEvent")]
	public class SerialProxy extends EventDispatcher{
		public static const PROXY_FOLDER:String='serial_proxy';
		public static const PROXY_EXE:String='serproxy.exe';
		public static const PROXY_CFG:String='serproxy.cfg';
		public static const PROXY_PORT_BASE:int=5330;

		private static const KEY_COMS:String='~~comm_ports~~';

		//private var socket:Socket;
		private var process:ProcessRunner;
		//private var proc:NativeProcess;
		//TODO refactor to map by type
		private var comInfos:Array;

		public var remoteIp:String;

		private var _connected:Boolean=false;
		public function get connected():Boolean{
			return _connected;
		}

		
		private var _isStarted:Boolean=false;
		public function get isStarted():Boolean{
			return _isStarted;
		}
			
		public function SerialProxy(){
			//TODO singleton
			super(null);
		}
		
		public function restart():void{
			addEventListener(SerialProxyEvent.SERIAL_PROXY_EXIT, onProxyExit);
			stop();
		}

		private var reconnectTimer:Timer;
		private function onProxyExit(event:SerialProxyEvent):void{
			removeEventListener(SerialProxyEvent.SERIAL_PROXY_EXIT, onProxyExit);
			reconnectTimer= new Timer(3000,1);
			reconnectTimer.addEventListener(TimerEvent.TIMER,onReconnectTimer);
			reconnectTimer.start();
			//start(null);
		}
		private function onReconnectTimer(evt:TimerEvent):void{
			reconnectTimer.removeEventListener(TimerEvent.TIMER,onReconnectTimer);
			reconnectTimer=null;
			start(null);
		}
		
		public function start(newComInfos:Array):void{
			var proxy:Socket2Com;
			//stop();
			if(_isStarted) return;
			if(newComInfos) comInfos=newComInfos;
			if(!comInfos || comInfos.length==0){
				dispatchEvent( new SerialProxyEvent(SerialProxyEvent.SERIAL_PROXY_ERROR,'','SerialProxy init error: Нет настроенных COM портов'));
				return;
			}
			if(remoteIp){
				//create proxies
				for each (ci in comInfos){
					if(ci && ci.type!=ComInfo.COM_TYPE_NONE && ci.num){
						if(!ci.proxy){
							proxy= new Socket2Com(ci,remoteIp);
							ci.proxy=proxy;
						}
					}
				}
				_isStarted=true;
				return;
			}
			//check/copy serial_proxy
			var srcDir:File=File.applicationDirectory;
			srcDir=srcDir.resolvePath(PROXY_FOLDER);
			if(!srcDir.exists || !srcDir.isDirectory){
				dispatchEvent( new SerialProxyEvent(SerialProxyEvent.SERIAL_PROXY_ERROR,'','SerialProxy init error: source folder not found '+srcDir.nativePath));
				return;
			}
			var srcFile:File;
			var dstFile:File;
			//check exe
			srcFile=srcDir.resolvePath(PROXY_EXE);
			if(!srcFile.exists || srcFile.isDirectory){
				dispatchEvent( new SerialProxyEvent(SerialProxyEvent.SERIAL_PROXY_ERROR,'','SerialProxy init error: source file not found '+srcFile.nativePath));
				return;
			}
			//create serproxy.cfg
			srcFile=srcDir.resolvePath(PROXY_CFG);
			if(!srcFile.exists || srcFile.isDirectory){
				dispatchEvent( new SerialProxyEvent(SerialProxyEvent.SERIAL_PROXY_ERROR,'','SerialProxy init error: source file not found '+srcFile.nativePath));
				return;
			}
			//read
			var cfg:String;
			var fs:FileStream;
			try{
				fs=new FileStream();
				fs.open(srcFile,FileMode.READ);
				cfg=fs.readUTFBytes(fs.bytesAvailable);
				fs.close();
			} catch(err:Error){
				dispatchEvent( new SerialProxyEvent(SerialProxyEvent.SERIAL_PROXY_ERROR,'','SerialProxy init error: '+err.message));
				return;
			}
			
			//get potrs list
			var ports:String;
			var conf:String;
			var ci:ComInfo;
			for each(ci in comInfos){
				if(ci.type!=ComInfo.COM_TYPE_NONE && ci.num){
					if(ports){
						ports+=(','+ci.num);
						conf+=ci.getCoonfig();
					}else{
						ports=ci.num;
						conf=ci.getCoonfig();
					}
				}
			}
			var re:RegExp;
			re= new RegExp(KEY_COMS,'gi');
			cfg=cfg.replace(re,ports);
			cfg+=conf;
			//write
			dstFile=File.applicationStorageDirectory;
			dstFile=dstFile.resolvePath(PROXY_FOLDER);
			dstFile=dstFile.resolvePath(PROXY_CFG);
			try{
				fs= new FileStream();
				fs.open(dstFile, FileMode.WRITE);
				fs.writeUTFBytes(cfg);
				fs.close();
			} catch(err:Error){
				dispatchEvent( new SerialProxyEvent(SerialProxyEvent.SERIAL_PROXY_ERROR,'','SerialProxy init error: '+err.message));
				return;
			}
			//start proxy
			dstFile=srcDir.resolvePath(PROXY_EXE);
			process= new ProcessRunner(dstFile.nativePath);
			srcDir=File.applicationStorageDirectory;
			srcDir=srcDir.resolvePath(PROXY_FOLDER);
			dstFile=srcDir.resolvePath(PROXY_CFG);
			var args:Vector.<String>=new Vector.<String>();
			args.push(dstFile.nativePath);
			if(!process.prepare(srcDir.nativePath,args)){
				dispatchEvent( new SerialProxyEvent(SerialProxyEvent.SERIAL_PROXY_ERROR,'','SerialProxy init error'));
				return;
			}
			/*
			//proc.addEventListener(NativeProcessExitEvent.EXIT,complite);
			proc.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, procRespond);
			proc.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, procErr);
			*/
			try{
				process.run();
			}catch(e:Error){
				dispatchEvent( new SerialProxyEvent(SerialProxyEvent.SERIAL_PROXY_ERROR,'','SerialProxy init error: '+e.message));
				return;
			}
			
			//create proxies
			for each (ci in comInfos){
				if(ci && ci.type!=ComInfo.COM_TYPE_NONE && ci.num){
					if(!ci.proxy){
						proxy= new Socket2Com(ci,remoteIp);
						ci.proxy=proxy;
					}
				}
			}

			_isStarted=true;
			dispatchEvent( new SerialProxyEvent(SerialProxyEvent.SERIAL_PROXY_START));
		}
		
		/*
		private var procResponse:String='';
		private function procErr(e:Event):void{
			procResponse+=proc.standardError.readUTFBytes(proc.standardError.bytesAvailable);
			dispatchEvent( new SerialProxyEvent(SerialProxyEvent.SERIAL_PROXY_ERROR,'','SerialProxy recponce: '+procResponse));
		}
		private function procRespond(e:Event):void{
			procResponse+=proc.standardOutput.readUTFBytes(proc.standardOutput.bytesAvailable);
			dispatchEvent( new SerialProxyEvent(SerialProxyEvent.SERIAL_PROXY_ERROR,'','SerialProxy recponce: '+procResponse));
		}
		*/
		
		public function getProxy(type:int):Socket2Com{
			if(!_isStarted) return null;
			var ci:ComInfo;
			ci = ArrayUtil.searchItem('type',type,comInfos) as ComInfo;
			if(!ci || ci.type==ComInfo.COM_TYPE_NONE || !ci.num) return null;
			if (ci.proxy) return ci.proxy;
			var proxy:Socket2Com= new Socket2Com(ci,remoteIp);
			ci.proxy=proxy;
			return proxy;
		}

		public function getProxiesByType(type:int):Array{
			if(!_isStarted) return null;
			var result:Array=[];
			if(type==ComInfo.COM_TYPE_NONE) return result;
			var ci:ComInfo;
			for each (ci in comInfos){
				if(ci && ci.type==type && ci.num){
					if(!ci.proxy){
						var proxy:Socket2Com= new Socket2Com(ci,remoteIp);
						ci.proxy=proxy;
					}
					result.push(ci.proxy);
				}
			}
			return result;
		}
		
		private var toConnect:Array;
		public function connectAll():void{
			var ci:ComInfo;
			toConnect=[];
			_connected=false;
			for each (ci in comInfos){
				if(ci && ci.type!=ComInfo.COM_TYPE_NONE && ci.num){
					if(!ci.proxy){
						var proxy:Socket2Com= new Socket2Com(ci,remoteIp);
						ci.proxy=proxy;
					}
					if(!ci.proxy.connected) toConnect.push(ci.proxy);
				}
			}
			connectNext();
		}
		private function connectNext():void{
			if(toConnect.length==0){
				//complited
				_connected=true;
				dispatchEvent(new SerialProxyEvent(SerialProxyEvent.SERIAL_PROXY_CONNECTED));
				return;
			}
			var proxy:Socket2Com= toConnect.pop() as Socket2Com;
			if(proxy){
				proxy.addEventListener(Event.CONNECT, onProxyConnect);
				proxy.addEventListener(Event.CLOSE, onProxyDisconnect);
				proxy.addEventListener(SerialProxyEvent.SERIAL_PROXY_ERROR, onProxyConnectErr);
				proxy.connect();
			}
		}
		private function onProxyConnect(evt:Event):void{
			var proxy:Socket2Com=evt.target as Socket2Com;
			if(proxy){
				proxy.removeEventListener(Event.CONNECT, onProxyConnect);
				proxy.removeEventListener(SerialProxyEvent.SERIAL_PROXY_ERROR, onProxyConnectErr);
			}
			connectNext();
		}
		private function onProxyConnectErr(evt:SerialProxyEvent):void{
			var proxy:Socket2Com=evt.target as Socket2Com;
			if(proxy){
				proxy.removeEventListener(Event.CONNECT, onProxyConnect);
				proxy.removeEventListener(SerialProxyEvent.SERIAL_PROXY_ERROR, onProxyConnectErr);
			}
			dispatchEvent(evt.clone());
		}
		private function onProxyDisconnect(evt:Event):void{
			var proxy:Socket2Com=evt.target as Socket2Com;
			if(proxy){
				proxy.removeEventListener(Event.CLOSE, onProxyDisconnect);
				var ci:ComInfo;
				for each (ci in comInfos){
					if(ci.proxy && ci.proxy===proxy){
						_connected=false;
						break
					}
				}
			}
		}

		public function stop():void{
			_isStarted=false;
			var ci:ComInfo;
			//disconnect clients
			if(comInfos){
				for each(ci in comInfos){
					if(ci && ci.proxy){
						ci.proxy.close();
						ci.proxy=null;
					}
				}
			}
			if(process && process.isRunning){
				process.process.addEventListener(NativeProcessExitEvent.EXIT, onProcExit);
				process.stop(true);
				process=null;
			}else{
				process=null;
				dispatchEvent(new SerialProxyEvent(SerialProxyEvent.SERIAL_PROXY_EXIT));
			}
		}
		
		private function onProcExit(evt:NativeProcessExitEvent):void{
			var prc:NativeProcess= evt.target as NativeProcess;
			if(prc) prc.removeEventListener(NativeProcessExitEvent.EXIT, onProcExit);
			dispatchEvent(new SerialProxyEvent(SerialProxyEvent.SERIAL_PROXY_EXIT));
		}
	}
}