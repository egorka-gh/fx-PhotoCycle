package pl.maliboo.ftp.invokers
{
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.net.Socket;
	
	import pl.maliboo.ftp.Commands;
	import pl.maliboo.ftp.FTPCommand;
	import pl.maliboo.ftp.FTPFile;
	import pl.maliboo.ftp.Responses;
	import pl.maliboo.ftp.core.FTPClient;
	import pl.maliboo.ftp.core.FTPInvoker;
	import pl.maliboo.ftp.errors.InvokeError;
	import pl.maliboo.ftp.events.FTPEvent;
	import pl.maliboo.ftp.utils.PassiveSocketInfo;

	public class ListInv extends FTPInvoker{
		
		private var passiveSocket:Socket;
		private var listing:String;
		private var directory:String;
		private var listingSend:Boolean=false;
		
		public function ListInv(client:FTPClient, directory:String)
		{
			super(client);
			this.directory = directory;
			listing = "";
		}
		
		override protected function startSequence ():void{
			sendCommand(new FTPCommand(Commands.PASV));
			startTimeoutTimer();
		}
		
		override protected function responseHandler(evt:FTPEvent):void{
			resetTimeoutTimer();
			//trace('list responce: '+evt.response.code.toString()+'-'+evt.response.message);
			switch (evt.response.code){
				case Responses.ENTERING_PASV:
					try{
						passiveSocket =	PassiveSocketInfo.createPassiveSocket(evt.response.message,
							handlePassiveConnect,
							handleListing, 
							ioErrorHandlerPass, 
							handleClose);
					} catch(e:Error){
						releaseWithError(new InvokeError(e.message));
						return;
					}
					break;
				case Responses.COMMAND_OK:
					//sendCommand(new FTPCommand(Commands.LIST, directory+"-l"));
					sendCommand(new FTPCommand(Commands.LIST, '-l'+(directory?(' '+directory):'')));
					break;
				case Responses.DATA_CONN_CLOSE:
					//file action successful
					//completed
					//trace('DATA_CONN_CLOSE:\n'+listing);
					
					if(!listingSend){
						if(passiveSocket && passiveSocket.connected) handleListing(null);
						var listEvt:FTPEvent = new FTPEvent(FTPEvent.LISTING);
						//trace('list complite attempt to parse');
						if(listing){
							listingSend=true;
							try{
								listEvt.listing = FTPFile.parseFormListing(listing, (directory?directory:client.workingDirectory));
							}catch(error:Error){
								trace('parse err ' +error.message);
								trace('parse err listing: '+listing);
								listEvt.listing=[];
							}
							if(!listEvt.listing) listEvt.listing=[];
							release(listEvt);
						}else{
							trace('Server says list send, but listing empty, waite data socket close');
						}
						/*
						if(listEvt.listing){
							release(listEvt);
						}else{
							releaseWithError(new InvokeError('Ошибка парса списка файлов'));
							trace('parse err listing: '+listing);
						}
						*/
					}
					break;
				case Responses.FILE_STATUS_OK:
					//Here comes the directory listing. message
					if(!passiveSocket || !passiveSocket.connected){
						releaseWithError(new InvokeError('Passive not connected'));
					}else{
						handleListing(null);
					}
					/*
					if(passiveSocket.connected){
					listing += passiveSocket.readUTFBytes(passiveSocket.bytesAvailable);
					}
					*/
					//trace('FILE_STATUS_OK:\n'+listing);
					//WHY ??? FILE_STATUS_OK= 150; 	//File status okay; about to open data connection.
					/*
					var listEvt2:FTPEvent = new FTPEvent(FTPEvent.LISTING);
					listEvt2.listing = FTPFile.parseFormListing(listing, client.workingDirectory);
					release(listEvt2);
					*/
					break;
				case Responses.CONNECTION_CLOSED:	//ABOR Connection closed; transfer aborted.
					if(aborted){
						var pauseEvent:FTPEvent = new FTPEvent(FTPEvent.PAUSE);
						pauseEvent.bytes = 0;
						pauseEvent.bytesTotal=0;
						pauseEvent.file = '';
						pauseEvent.path= directory;
						pauseEvent.process="listing";
						release(pauseEvent);
					}else{
						releaseWithError(new InvokeError('Data connection closed'));
					}
					break;
				default:
					releaseWithError(new InvokeError(evt.response.message));

			}
		}
		
		override protected function cleanUp ():void{
			if(passiveSocket!=null){
				passiveSocket.removeEventListener(Event.CONNECT, handlePassiveConnect);
				passiveSocket.removeEventListener(ProgressEvent.SOCKET_DATA, handleListing);
				passiveSocket.removeEventListener(IOErrorEvent.IO_ERROR, ioErrorHandlerPass);
				passiveSocket.removeEventListener(Event.CLOSE, handleClose);

				//if(passiveSocket.connected) passiveSocket.close();
				try{
					if(passiveSocket.connected) passiveSocket.close();
				}catch(err:Error){}
				passiveSocket=null;
			}
		}

		private function handleClose (evt:Event):void{
			var listEvt:FTPEvent = new FTPEvent(FTPEvent.LISTING);
			//trace('list complite attempt to parse');
			if(listing){
				try{
					listEvt.listing = FTPFile.parseFormListing(listing, (directory?directory:client.workingDirectory));
				}catch(error:Error){
					trace('parse err ' +error.message);
					trace('parse err listing: '+listing);
					listEvt.listing=[];
				}
			}
			if(!listEvt.listing) listEvt.listing=[];
			release(listEvt);
		}
		
		private function ioErrorHandlerPass (evt:IOErrorEvent):void{
			releaseWithError(new InvokeError('Passive socket err: '+evt.text));
		}

		private function handlePassiveConnect (evt:Event):void{
			resetTimeoutTimer();
			//sendCommand(new FTPCommand(Commands.LIST, directory+"-l"));
			sendCommand(new FTPCommand(Commands.LIST, '-l'+(directory?(' '+directory):'')));
		}
		
		private function handleListing (evt:ProgressEvent):void{
			resetTimeoutTimer();
			if(passiveSocket.connected && passiveSocket.bytesAvailable>0) listing += passiveSocket.readUTFBytes(passiveSocket.bytesAvailable);
			//just accumulate socket response
			/*
			var listEvt:FTPEvent = new FTPEvent(FTPEvent.LISTING);
			listEvt.listing = FTPFile.parseFormListing(listing, client.workingDirectory);
			release(listEvt);
			*/
		}
	}
}