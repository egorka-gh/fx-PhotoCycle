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
		public static function codeIt(textToCode:String):String{
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

	}
}