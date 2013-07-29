package com.photodispatcher.factory{
	import com.photodispatcher.model.Source;
	import com.photodispatcher.model.SourceType;
	import com.photodispatcher.service.web.BaseWeb;
	import com.photodispatcher.service.web.FBookManualWeb;
	import com.photodispatcher.service.web.FotoknigaWeb;
	import com.photodispatcher.service.web.ProfotoWeb;

	public class WebServiceBuilder{

		public static function build(source:Source):BaseWeb{
			if (!source) return null;
			switch(source.type_id){
				case SourceType.SRC_PROFOTO:
					return new ProfotoWeb(source);
					break;
				case SourceType.SRC_FOTOKNIGA:
					return new FotoknigaWeb(source);
					break;
				case SourceType.SRC_FBOOK_MANUAL:
					return new FBookManualWeb(source);
					break;
				default:
					return null;
					break;
			}
		}

	}
}