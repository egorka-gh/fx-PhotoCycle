package com.photodispatcher.util{
	public class Code128{

		/**
		 * Barcode 128 encoder...</br>
		 *
		 * @param textToCode the text you want to code
		 * @return the encoded text
		 * 
		 * src http://grandzebu.net/informatique/codbar-en/code128.htm
		 */
		public static function codeItOld(textToCode:String):String{
			//char[] text = textToCode.toCharArray();
			var checksum:int = 0;
			var mini:int; 
			var char2:int; 
			var tableB:Boolean = true;
			var i:int;
			
			var code128:String = '';
			
  			//Check for valid characters
			for (i=0; i<textToCode.length; i++){
				//can add Ё code - 203
				if ((textToCode.charCodeAt(i) < 32) || (textToCode.charCodeAt(i) > 126)) return '';
			}
			
			i=0;
			while (i < textToCode.length){
				if (tableB){
					// See if interesting to switch to table C
					// yes for 4 digits at start or end, else if 6 digits
					mini = ((i == 0) || (i + 3 == textToCode.length - 1) ? 4 : 6);
					mini = testNumeric(textToCode, i, mini);
					if (mini < 0){// Choice of table C
						// 210-Starting with table C, 204 - Switch to table C
						code128 += (i == 0 ? String.fromCharCode(210) : String.fromCharCode(204));
						tableB = false;
					}else if (i == 0)
						// Starting with table B
						code128 += String.fromCharCode(209);
				}
				
				if (!tableB){
					// We are on table C, try to process 2 digits
					mini = testNumeric(textToCode, i, 2);
					if (mini < 0){
						//OK for 2 digits, process it
						char2 = int(textToCode.substr(i,2));
						char2 += (char2 < 95 ? 32 : 105);
						code128 += String.fromCharCode(char2);
						i += 2;
					}else{
						// We haven't 2 digits, switch to table B
						code128 += String.fromCharCode(205);
						tableB = true;
					}
				}
				if (tableB){
					// Process 1 digit with table B
					code128 += textToCode.charAt(i);
					i++;
				}
			}
			
			// Calculation of the checksum
			for (i=0; i<code128.length; i++){
				char2 = code128.charCodeAt(i);
				char2 -= (char2 < 127 ? 32 : 105);
				checksum = ((i == 0 ? char2 : checksum) + i * char2) % 103;
			}
			
			// Calculation of the checksum ASCII code
			checksum += (checksum < 95 ? 32 : 105);
			
			// Add the checksum and the STOP
			return code128+String.fromCharCode(checksum)+String.fromCharCode(211);
		}	
		
		private static function testNumeric(text:String, i:int, mini:int):int{
			mini--;
			if (i + mini < text.length){
				for (mini=mini; mini >= 0; mini--){
					if ((text.charCodeAt(i + mini) < 48) || (text.charCodeAt(i + mini) > 57)) break;
				}
			}
			return mini;
		}

		private static const ASCII_OFFSET:int=32;
		private static const HIGH_ASCII_OFFSET:int=18;

		private static function getCode3Char(strVal:String):int{
			var val:int=int(strVal);
			if(val==0){
    			//special case for space value... 00 in Code 3
				val = 96 + ASCII_OFFSET;
			}else if(val > 0 && val < 95){
				val += ASCII_OFFSET;
			} else{
				val= val + ASCII_OFFSET + HIGH_ASCII_OFFSET;
			}
		  return val;
		}
		
		private static function ansiToUnicodeString(inInt:int):String{
			var result:String;
			if (inInt == 128){
				result= String.fromCharCode(0x20AC);
			}else if(inInt == 32 ){
				result = String.fromCharCode(0x20AC);
			}else if( inInt == 145 ){ 
				result = String.fromCharCode(0x2018);
			}else if( inInt == 146 ){ 
				result = String.fromCharCode(0x2019);
			}else if( inInt == 147 ){ 
				result = String.fromCharCode(0x201C);
			} else if( inInt == 148 ){ 
				result = String.fromCharCode(0x201D);
			} else if( inInt == 149 ){
				result = String.fromCharCode(0x2022);
			} else if( inInt == 150 ){ 
				result = String.fromCharCode(0x2013);
			} else if( inInt == 151 ){
				result = String.fromCharCode(0x2014);
			} else if( inInt == 152 ){ 
				result = String.fromCharCode(0x2DC);
			} else if( inInt == 153 ){
				result = String.fromCharCode(0x2122);
			} else if( inInt == 154 ){ 
				result = String.fromCharCode(0x161);
			} else if( inInt == 155 ){ 
				result = String.fromCharCode(0x203A);
			} else if( inInt == 156 ){ 
				result = String.fromCharCode(0x153);
			}
			if(!result) result=String.fromCharCode(inInt);
			return result;
		}
		
		private static function unicodeToAnsiValue(inInt:int):int{
			var result:int=inInt;
			if(inInt==0x20AC){
				result = 32;
			}else if(inInt == 0x2018){ 
				result = 145;
			}else if(inInt == 0x2019){ 
				result = 146;
			}else if(inInt == 0x201C){ 
				result = 147;
			}else if(inInt == 0x201D){ 
				result = 148;
			}else if(inInt == 0x2022){ 
				result = 149;
			}else if(inInt == 0x2013){ 
				result = 150;
			}else if(inInt == 0x2014){ 
				result = 151;
			}else if(inInt == 0x2DC){ 
				result = 152;
			}else if(inInt == 0x2122){ 
				result = 153;
			}else if(inInt == 0x161){ 
				result = 154;
			}else if(inInt == 0x203A){ 
				result = 155;
			}else if(inInt == 0x153){ 
				result = 156;
			}
			return result;
		}

		/*
		* Code128bWin.ttf
		*Web: http://freebarcodefonts.dobsonsw.com
		*/
		public static function codeIt(textToCode:String):String{
			//char[] text = textToCode.toCharArray();
			var checksum:int = 0;
			var mini:int; 
			var char2:int; 
			var tableB:Boolean = true;
			var i:int;
			
			var code128:String = '';
			
			/*
			//Check for valid characters
			for (i=0; i<textToCode.length; i++){
				//can add Ё code - 203
				if ((textToCode.charCodeAt(i) < 32) || (textToCode.charCodeAt(i) > 126)) return '';
			}
			*/
			
			i=0;
			while (i < textToCode.length){
				if (tableB){
					// See if interesting to switch to table C
					// yes for 4 digits at start or end, else if 6 digits
					mini = ((i == 0) || (i + 3 == textToCode.length - 1) ? 4 : 6);
					mini = testNumeric(textToCode, i, mini);
					if (mini < 0){// Choice of table C
						// 210-Starting with table C, 204 - Switch to table C
						//code128 += (i == 0 ? String.fromCharCode(210) : String.fromCharCode(204));
						if(i==0){
							//Starting with table C
							code128+=ansiToUnicodeString(105 + ASCII_OFFSET+ HIGH_ASCII_OFFSET);
						}else{
							//Switch to table C
							code128+=ansiToUnicodeString(99 + ASCII_OFFSET+ HIGH_ASCII_OFFSET);
						}
						tableB = false;
					}else if (i == 0){
						// Starting with table B
						//code128 += String.fromCharCode(209);
						code128+=ansiToUnicodeString(104 + ASCII_OFFSET+ HIGH_ASCII_OFFSET);
					}
				}
				
				if (!tableB){
					// We are on table C, try to process 2 digits
					mini = testNumeric(textToCode, i, 2);
					if (mini < 0){
						//OK for 2 digits, process it
						/*
						char2 = int(textToCode.substr(i,2));
						char2 += (char2 < 95 ? 32 : 105);
						code128 += String.fromCharCode(char2);
						*/
						code128 += ansiToUnicodeString(getCode3Char(textToCode.substr(i,2)));
						i += 2;
					}else{
						// We haven't 2 digits, switch to table B
						//code128 += String.fromCharCode(205);
						code128+=ansiToUnicodeString(100 + ASCII_OFFSET+ HIGH_ASCII_OFFSET);
						tableB = true;
					}
				}
				if (tableB){
					// Process 1 digit with table B
					code128 += textToCode.charAt(i);
					i++;
				}
			}
			//replace space
			code128=code128.replace(' ', ansiToUnicodeString(128));
			// Calculation of the checksum
			code128+=getCheckDigit(code128);
			//stop
			code128+= ansiToUnicodeString(106 + ASCII_OFFSET + HIGH_ASCII_OFFSET);
			
			return code128;
			/*
			for (i=0; i<code128.length; i++){
				char2 = code128.charCodeAt(i);
				char2 -= (char2 < 127 ? 32 : 105);
				checksum = ((i == 0 ? char2 : checksum) + i * char2) % 103;
			}
			// Calculation of the checksum ASCII code
			checksum += (checksum < 95 ? 32 : 105);
			*/
			
			//// Add the checksum and the STOP
			//return code128+String.fromCharCode(checksum)+String.fromCharCode(211);
		}	
		
		private static function getCheckDigit(data:String):String{
			var stringLength:int=data.length;
			var total:int=0;
			var counter:int;
			var outsideCounter:int=1;
			var firstChar:String;
			
			for(counter=0; counter<stringLength; counter++){  
				firstChar = data.charAt(counter);
				if(counter == 0){
					total += getCharValue(firstChar);
				}else{
					total += getCharValue(firstChar) * outsideCounter;
					outsideCounter++;
				}
			}
			total = total % 103;
			if (total == 0){
				return ansiToUnicodeString(128);
			}else{
				if((total + ASCII_OFFSET) > 126){
					return ansiToUnicodeString(total + ASCII_OFFSET + HIGH_ASCII_OFFSET);
				}else{
					return ansiToUnicodeString(total + ASCII_OFFSET);
				}
			}
		}
		
		private static function getCharValue(char:String):int{
			var charValue:int;
			var retVal:int;
			
			charValue = unicodeToAnsiValue(char.charCodeAt(0));
			if (charValue > 144){
				retVal = charValue - ASCII_OFFSET - HIGH_ASCII_OFFSET;
			}else{
				retVal = charValue - ASCII_OFFSET;
			}
			if(charValue == 128) retVal = 0;
			return  retVal;
		}

	}
}