package com.photodispatcher.service.modbus.data{
	import flash.utils.ByteArray;
	
	public class ModbusPDU{
		
		public static const FUNC_READ_COILS:int=1;
		public static const FUNC_READ_DISCRETS:int=2;
		public static const FUNC_READ_HOLDING_REGISTERS:int=3;
		public static const FUNC_READ_INPUT_REGISTERS:int=4;
		public static const FUNC_WRITE_COIL:int=5;
		public static const FUNC_WRITE_REGISTER:int=6;
		public static const FUNC_WRITE_COILS:int=15;
		public static const FUNC_WRITE_REGISTERS:int=16;
		
		public static const ERR_ILLEGAL_FUNCTION:int=1;
		public static const ERR_ILLEGAL_DATA_ADDRESS:int=2;
		public static const ERR_ILLEGAL_DATA_VALUE:int=3;
		public static const ERR_SERVER_DEVICE_FAILURE:int=4;
		public static const ERR_ACKNOWLEDGE:int=5;
		public static const ERR_SERVER_DEVICE_BUSY:int=6;

		public static function readResponse(bytes:ByteArray):ModbusPDU{
			var pdu:ModbusPDU;
			var len:int;
			var i:int;
			if(bytes && bytes.bytesAvailable){
				pdu=new ModbusPDU(ModbusBytes.readByte(bytes));
				switch(pdu.functionCode){
					case FUNC_READ_COILS:
					case FUNC_READ_DISCRETS:
						len=ModbusBytes.readByte(bytes);
						pdu.values=[];
						for( i=0; i<len; i++){
							pdu.values.push(ModbusBytes.readByte(bytes));
						}
						break;
					case FUNC_READ_HOLDING_REGISTERS:
					case FUNC_READ_INPUT_REGISTERS:
						len=ModbusBytes.readByte(bytes);
						len=len/2;
						pdu.values=[];
						for( i=0; i<len; i++){
							pdu.values.push(ModbusBytes.readWord(bytes));
						}
						break;
					case FUNC_WRITE_COIL: // the value written
					case FUNC_WRITE_REGISTER: // the value written
					case FUNC_WRITE_COILS: // quantity of coils
					case FUNC_WRITE_REGISTERS: // quantity of registers
						// the starting address
						pdu.address=ModbusBytes.readWord(bytes);
						// value or quantity
						pdu.value=ModbusBytes.readWord(bytes);
						break;
					default:
						if(pdu.functionCode & 0x80){
							//read error code
							pdu.errCode=ModbusBytes.readByte(bytes);
						}
				}
			}
			return pdu;
		}

		public static function readRequest(bytes:ByteArray):ModbusPDU{
			var pdu:ModbusPDU;
			var len:int;
			var i:int;
			if(bytes && bytes.bytesAvailable){
				pdu=new ModbusPDU(ModbusBytes.readByte(bytes));
				switch(pdu.functionCode){
					case FUNC_READ_COILS:
					case FUNC_READ_DISCRETS:
					case FUNC_READ_HOLDING_REGISTERS:
					case FUNC_READ_INPUT_REGISTERS:
						pdu.address=ModbusBytes.readWord(bytes);
						pdu.value=ModbusBytes.readWord(bytes);
						break;
					case FUNC_WRITE_COIL: // the value written 0x0000/0xFF00
					case FUNC_WRITE_REGISTER: // the value written
						pdu.address=ModbusBytes.readWord(bytes);
						pdu.value=ModbusBytes.readWord(bytes);
						break;
					case FUNC_WRITE_COILS: 
						pdu.address=ModbusBytes.readWord(bytes);
						pdu.value=ModbusBytes.readWord(bytes); // quantity of coils
						len=ModbusBytes.readByte(bytes); // quantity of bytes
						for( i=0; i<len; i++){ // bytes vs bits to set
							pdu.values.push(ModbusBytes.readByte(bytes));
						}
						break;
					case FUNC_WRITE_REGISTERS: 
						pdu.address=ModbusBytes.readWord(bytes);
						pdu.value=ModbusBytes.readWord(bytes); // quantity of registers
						len=ModbusBytes.readByte(bytes); // quantity of bytes
						len=len/2; // quantity of words
						for( i=0; i<len; i++){ // read registers 
							pdu.values.push(ModbusBytes.readWord(bytes));
						}
						break;
					default:
						if(pdu.functionCode & 0x80){
							//read error code
							pdu.errCode=ModbusBytes.readByte(bytes);
						}
				}
			}
			return pdu;
		}

		public function ModbusPDU(functionCode:int=0){
			this.functionCode=functionCode;
		}
		

		public var functionCode:int;
		public var address:int;
		public var value:int;
		public var values:Array;
		public var errCode:int;
		
		public function createRequest():ByteArray{
			var ba:ByteArray= new ByteArray();
			var len:int;
			var i:int;
			var bytes:ModbusBytes= new ModbusBytes();
			bytes.addByte(functionCode);
			switch(functionCode){
				case FUNC_READ_COILS:
				case FUNC_READ_DISCRETS:
				case FUNC_READ_HOLDING_REGISTERS:
				case FUNC_READ_INPUT_REGISTERS:
					if(value>0){
						bytes.addWord(address);
						bytes.addWord(value);
					}
					break;
				case FUNC_WRITE_COIL: // the value written 0x0000/0xFF00
					bytes.addWord(address);
					if(value>0){
						bytes.addWord(0xFF00);
					}else{
						bytes.addWord(0);
					}
					break;
				case FUNC_WRITE_REGISTER: // the value written
					bytes.addWord(address);
					bytes.addWord(value);
					break;
				case FUNC_WRITE_COILS:
					if(value>0 && values && values.length>0){
						bytes.addWord(address);
						bytes.addWord(value); // quantity of coils
						bytes.addByte(values.length); // quantity of bytes
						for( i=0; i<values.length; i++){ // bytes vs bits to set
							bytes.addByte(values[i]);
						}
					}
					break;
				case FUNC_WRITE_REGISTERS: 
					if(value>0 && values && values.length>0){
						bytes.addWord(address);
						bytes.addWord(value); // quantity of registers
						bytes.addByte(values.length*2); // quantity of bytes
						for( i=0; i<values.length; i++){ // registers
							bytes.addWord(values[i]);
						}
					}
					break;
			}
			if(bytes.bytesLenth>1){
				ba=bytes.getBytes();
			}
			return ba;
		}

		
		public function createErrResponse(err:int):ByteArray{
			if(errCode>0){
				var bytes:ModbusBytes= new ModbusBytes();
				bytes.addByte(functionCode | 0x80);
				bytes.addByte(errCode);
				return bytes.getBytes();
			}
			return null;
		}
		
		public function createResponse():ByteArray{
			var len:int;
			var i:int;
			if(errCode>0){
				return createErrResponse(errCode);
			}
			var bytes:ModbusBytes= new ModbusBytes();
			bytes.addByte(functionCode);
			switch(functionCode){
				case FUNC_READ_COILS:
				case FUNC_READ_DISCRETS:
					if(values && values.length>0){
						bytes.addByte(values.length);
						for( i=0; i<values.length; i++){
							bytes.addByte(values[i]);
						}
					}else{
						return createErrResponse(ERR_ILLEGAL_DATA_VALUE);
					}
					break;
				case FUNC_READ_HOLDING_REGISTERS:
				case FUNC_READ_INPUT_REGISTERS:
					if(values && values.length>0){
						bytes.addByte(values.length*2);
						for( i=0; i<values.length; i++){
							bytes.addWord(values[i]);
						}
					}else{
						return createErrResponse(ERR_ILLEGAL_DATA_VALUE);
					}
					break;
				case FUNC_WRITE_COIL: // the value written
				case FUNC_WRITE_REGISTER: // the value written
				case FUNC_WRITE_COILS: // quantity of coils
				case FUNC_WRITE_REGISTERS: // quantity of registers
					// the starting address
					bytes.addWord(address);
					// value or quantity
					bytes.addWord(value);
					break;
			}
			if(bytes.bytesLenth>1){
				return bytes.getBytes();
			}else{
				return createErrResponse(ERR_ILLEGAL_FUNCTION);
			}
		}

	}
}