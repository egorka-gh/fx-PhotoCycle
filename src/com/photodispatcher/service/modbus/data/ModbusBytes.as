package com.photodispatcher.service.modbus.data{
	import flash.utils.ByteArray;

	public class ModbusBytes{
		
		protected var bytes:Array=[];

		public static function int2bcd(value:int):int{
			var res:int=0;
			var shift:int=0;
			var dec:int=value;
			while (dec>0){
				res=res+((dec % 10) << shift);
				dec=int(dec/10);
				shift+=4;
			}
			return res;
		}
		
		public static function readByte(bytes:ByteArray):int{
			var readVal:int;
			if(bytes && bytes.bytesAvailable>0) readVal=bytes.readByte();
			return readVal;
		}
		
		public static function byteArrayToStr(bytes:ByteArray):String{
			if(!bytes || !bytes.length){
				return 'null';
			}
			var res:String='';
			for (var i:int = 0; i < bytes.length; i++){
				res=res+' '+ int(bytes[i]).toString(16);
			}
			return res;
		}

		public static function readWord(bytes:ByteArray):int{
			var readVal:int;
			if(bytes && bytes.bytesAvailable>1){
				readVal=bytes.readByte()*256+bytes.readByte();
			}
			return readVal;
		}

		public function get bytesLenth():int{
				return bytes.length;
		}

		public function addByte(value:int):void{
			bytes.push(value & 255);
		}

		public function setByte(index:int, value:int):void{
			bytes[index]=(value & 255);
		}

		public function addWord(value:int):void{
			addByte(value >> 8);
			addByte(value);
		}

		public function setWord(index:int, value:int):void{
			setByte(index,value >> 8);
			setByte(index+1,value);
		}

		public function getBytes():ByteArray{
			var ba:ByteArray= new ByteArray();
			for (var i:int = 0; i < bytes.length; i++){
				ba.writeByte(bytes[i]);
			}
			return ba;
		}
		
	}
}