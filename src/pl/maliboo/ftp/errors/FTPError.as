package pl.maliboo.ftp.errors
{
	public class FTPError extends Error{
		//import mx.controls.Alert;
		
		public function FTPError(message:String="", id:int=0){
			this.message=message;
			//Alert.show(message, "Error");
		}
		
	}
}