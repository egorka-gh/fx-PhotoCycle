package com.photodispatcher.service.modbus.data{
	import flash.utils.ByteArray;

	public class ModbusADU{
		
		public var pdu:ModbusPDU;
		private var header:ModbusBytes;
		
		public static function readRequest(bytes:ByteArray):ModbusADU{
			var adu:ModbusADU;
			var len:int;
			if(bytes && bytes.length>0){
				bytes.position=0;
				adu=new ModbusADU();
				// transaction ID
				adu.transactionId=ModbusBytes.readWord(bytes);
				// protocol
				ModbusBytes.readWord(bytes);
				// length	 		
				len=ModbusBytes.readWord(bytes);
				if(len==bytes.bytesAvailable){
					// device ID
					adu.deviceID=ModbusBytes.readByte(bytes);
					adu.pdu=ModbusPDU.readRequest(bytes);
				}else{
					adu=null;
				}
			}
			return adu;
		}

		public static function readResponse(bytes:ByteArray):ModbusADU{
			var adu:ModbusADU;
			var len:int;
			if(bytes && bytes.length>0){
				bytes.position=0;
				adu=new ModbusADU();
				// transaction ID
				adu.transactionId=ModbusBytes.readWord(bytes);
				// protocol
				ModbusBytes.readWord(bytes);
				// length	 		
				len=ModbusBytes.readWord(bytes);
				if(len==bytes.bytesAvailable){
					// device ID
					adu.deviceID=ModbusBytes.readByte(bytes);
					adu.pdu=ModbusPDU.readResponse(bytes);
				}else{
					adu=null;
				}
			}
			return adu;
		}

		public function ModbusADU(){
			//pdu= new ModbusPDU();
			//init header
			header=new ModbusBytes();
			// transaction ID
			header.addWord(0);
			// protocol
			header.addWord(0);
			// length	 		
			header.addWord(0);
			// device ID
			header.addByte(0xFF);
		}
		
		private var _transactionId:int;
		public function get transactionId():int{
			return _transactionId;
		}
		public function set transactionId(value:int):void{
			_transactionId = value;
			header.setWord(0,value);
		}

		private var _deviceID:int;
		public function get deviceID():int{
			return _deviceID;
		}
		public function set deviceID(value:int):void{
			_deviceID = value;
			header.setByte(6,value);
		}

		private function setLen(pduLen:uint):void{
			//=1+pdu.lenth (deviceID byte+pdu bytes)
			header.setWord(4,1+pduLen);
		}
		
		public function createRequest():ByteArray{
			var ba:ByteArray;
			var ba2:ByteArray;
			if(pdu){
				ba2=pdu.createRequest();
				if(ba2 && ba2.length>0){
					setLen(ba2.length);
					ba=header.getBytes();
					ba.writeBytes(ba2);
				}
			}
			return ba;
		}

		public function createResponse():ByteArray{
			var ba:ByteArray;
			var ba2:ByteArray;
			if(pdu){
				ba2=pdu.createResponse();
				if(ba2 && ba2.length>0){
					setLen(ba2.length);
					ba=header.getBytes();
					ba.writeBytes(ba2);
				}
			}
			return ba;
		}

	}
}