package com.photodispatcher.service.barcode
{
	import com.photodispatcher.event.SerialProxyEvent;
	import com.photodispatcher.shell.ProcessRunner;
	
	import flash.desktop.NativeProcess;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.net.Socket;
	
	[Event(name="serialProxyData", type="com.photodispatcher.event.SerialProxyEvent")]
	[Event(name="serialProxyError", type="com.photodispatcher.event.SerialProxyEvent")]
	[Event(name="connect", type="flash.events.Event")]
	[Event(name="close", type="flash.events.Event")]
	public class SerialProxy extends EventDispatcher{
		public static const PROXY_FOLDER:String='serial_proxy';
		public static const PROXY_EXE:String='serproxy.exe';
		public static const PROXY_CFG:String='serproxy.cfg';
		public static const PROXY_PORT_BASE:int=5330;

		private static const KEY_COM:String='~~com_num~~';
		private static const KEY_BAUD:String='~~com_baud~~';
		private static const KEY_PORT:String='~~proxy_port~~';

		private var socket:Socket;
		private var process:ProcessRunner;
		private var proc:NativeProcess;

		public function SerialProxy(){
			super(null);
		}
		
		public function start(com_port:int=1, com_baud:int=2400):void{
			var proxy_port:int=PROXY_PORT_BASE+com_port;
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
			/*
			//copy exe
			dstFile=File.applicationStorageDirectory;
			dstFile=dstFile.resolvePath(PROXY_FOLDER);
			dstFile=dstFile.resolvePath(PROXY_EXE);
			if(!dstFile.exists){
				try{
					srcFile.copyTo(dstFile);
				}catch(e:Error){
					dispatchEvent( new SerialProxyEvent(SerialProxyEvent.SERIAL_PROXY_ERROR,'','SerialProxy init error: '+e.message));
					return;
				}
			}
			*/
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
			var re:RegExp;
			re= new RegExp(KEY_COM,'gi');
			cfg=cfg.replace(re,com_port.toString());
			re= new RegExp(KEY_BAUD,'gi');
			cfg=cfg.replace(re,com_baud.toString());
			re= new RegExp(KEY_PORT,'gi');
			cfg=cfg.replace(re,proxy_port.toString());
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
			proc=process.prepare(srcDir.nativePath,args);
			if(!proc){
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
			//connect to proxy
			socket = new Socket();
			socket.addEventListener( Event.CLOSE, onSocket );
			socket.addEventListener( Event.CONNECT, onSocket );
			socket.addEventListener( IOErrorEvent.IO_ERROR, onIOErrorEvent );
			socket.addEventListener( SecurityErrorEvent.SECURITY_ERROR, onSecurityError );
			socket.addEventListener( ProgressEvent.SOCKET_DATA, onSocketData );
			try{
				socket.connect('127.0.0.1',proxy_port);
			}catch(err:Error){
				dispatchEvent( new SerialProxyEvent(SerialProxyEvent.SERIAL_PROXY_ERROR,'','SerialProxy init error: '+err.message));
			}
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
		
		private function onSocket(event:Event):void{
			dispatchEvent(event.clone());
		}
		
		private function onIOErrorEvent( event:IOErrorEvent ):void{
			dispatchEvent( new SerialProxyEvent(SerialProxyEvent.SERIAL_PROXY_ERROR,'','SerialProxy error: '+event.text));
		}
		
		private function onSecurityError( event:SecurityErrorEvent ):void{
			dispatchEvent( new SerialProxyEvent(SerialProxyEvent.SERIAL_PROXY_ERROR,'','SerialProxy error: '+event.text));
		}
		
		private function onSocketData( event:ProgressEvent ):void{
			var res:String=socket.readUTFBytes(socket.bytesAvailable);
			dispatchEvent( new SerialProxyEvent(SerialProxyEvent.SERIAL_PROXY_DATA,res));
		}
		
		public function get connected():Boolean{
			return socket &&  socket.connected;
		}

		public function send( value:String ):void{			
			socket.writeUTFBytes(value);
			socket.flush();
		}
		
		public function clean():void{
			if(socket && socket.connected && socket.bytesAvailable){
				socket.readUTFBytes(socket.bytesAvailable);
			}
		}

		public function stop():void{
			if(socket){
				if(socket.connected) socket.close();
				socket.removeEventListener(Event.CLOSE, onSocket );
				socket.removeEventListener(Event.CONNECT, onSocket );
				socket.removeEventListener(IOErrorEvent.IO_ERROR, onIOErrorEvent );
				socket.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityError );
				socket.removeEventListener(ProgressEvent.SOCKET_DATA, onSocketData );
				
			}
			socket=null;
			if(process && process.isRunning){
				process.stop(true);
			}
			process=null;
		}
	}
}