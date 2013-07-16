package pl.maliboo.ftp.errors{
	public class InvokeTimeoutError extends InvokeError{
		public function InvokeTimeoutError(message:String="unknown", id:int=0){
			super(message, id);
		}
	}
}