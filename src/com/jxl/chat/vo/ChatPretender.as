package com.jxl.chat.vo{
	public class ChatPretender{
		private static const BUILD_POST_MSGS:Array=['Размещение на подготовку заказа',
			'слепика заказик',
			'хорош курить, обработай',
			'собери быренько',
			'это... помощь нужна, подготовь плз',
			'есть кто, тут заказ надо подготовить'];
		private static const LOAD_POST_MSGS:Array=['Размещение на загрузку заказа',
			'грузани ка заказик',
			'надоб загрузить',
			'бегом грузить заказ',
			'я тебе тут заказ заныкал, буш грузить?',
			'зашиваюсь плин, загрузи плз',
			'брат канала не хватает, загрузи а?',
			'загрузи быренько',
			'это... помощь нужна, загрузи плз',
			'есть кто, тут заказ надо загрузить'];
		private static const POST_CONFIRM_MSGS:Array=['Принято',
													'ок',
													'акейчег',
													'сча',
													'лады',
													'а чё опять я, троли блин, ужо',
													'угу',
													'чичас',
													'ё наканец та',
													'что за... а да',
													'ух работну',
													'плин. да сча',
													'ну дык поможемо',
													'да что за день такой. ща тока штаны подтяну',
													'от жеш... канечна',
													'нема базару',
													'сделам в лучшем виде',
													'дык не вопрос',
													'а тож'];
		
		private static function randomMessage(msgs:Array):String{
			if(!msgs) return '';
			var idx:int= Math.round(Math.random()*(msgs.length-1));
			return msgs[idx]+' ';
		}
		
		public static function buildPostMessage():String{
			return randomMessage(BUILD_POST_MSGS);
		}

		public static function loadPostMessage():String{
			return randomMessage(LOAD_POST_MSGS);
		}

		public static function postConfirmMessage():String{
			return randomMessage(POST_CONFIRM_MSGS);
		}
	}
}