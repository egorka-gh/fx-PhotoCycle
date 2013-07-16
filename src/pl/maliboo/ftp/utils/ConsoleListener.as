package pl.maliboo.ftp.utils
{
	import mx.controls.TextInput;
	
	import pl.maliboo.ftp.FTPListener;
	import pl.maliboo.ftp.core.FTPClient;
	import pl.maliboo.ftp.events.FTPEvent;
	
	import spark.components.TextArea;

	public class ConsoleListener extends FTPListener{
		[Bindable]
		public var consoleLog:String='';
		private var textArea:TextArea;
		private var input:TextInput;
		
		public function ConsoleListener(client:FTPClient, output:TextArea=null, input:TextInput=null){
			super(client);
			textArea = output;
			this.input = input;
		}
		
		private function append (text:String):void{
			if(textArea) textArea.text += text + "\n";
			consoleLog += text+"\n";
		}
		
		override public function commandSent (evt:FTPEvent):void{
			if(textArea) textArea.appendText(evt.command.toExecuteString().replace(/PASS .+/gi, "PASS *****")+ "\n");
			consoleLog += evt.command.toExecuteString().replace(/PASS .+/gi, "PASS *****")+ "\n";
		}
		
		override public function responseReceived(evt:FTPEvent):void{
			if(textArea) textArea.appendText(evt.response.code + " " +evt.response.message+ "\n");
			consoleLog += evt.response.code + " " +evt.response.message+ "\n";
		}		
	}
}