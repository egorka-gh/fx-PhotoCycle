package com.photodispatcher.tech.register{
	public class RegisterResult	{
		public static const ERR_NOT_MY:int=-1;
		public static const ERR_NOT_FOUND:int=-2;
		public static const ERR_WRONG_SEQ:int=-3;
		public static const ERR_REJECTED:int=-4;
		public static const ALLREADY_REGISTRED:int=0;
		public static const REGISTRED:int=1;
		public static const REGISTRED_REJECT:int=2;
		//sequence complited
		public static const COMPLITED:int=3;
		
		public static function getCaption(res:int):String{
			var caption:String="";
			switch(res){
				case ERR_NOT_MY:{
					caption="Not my";
					break;
				}
				case ERR_NOT_FOUND:{
					caption="Не найден";
					break;
				}
				case ERR_WRONG_SEQ:{
					caption="Не верная последовательность";
					break;
				}
				case ERR_REJECTED:{
					caption="Брак";
					break;
				}
				case ALLREADY_REGISTRED:{
					caption="Повторная регистрация";
					break;
				}
				case REGISTRED:{
					caption="Ok";
					break;
				}
				case REGISTRED_REJECT:{
					caption="Брак";
					break;
				}
				default:{
					caption=res.toString();
					break;
				}
			}
		}
		
	}
}