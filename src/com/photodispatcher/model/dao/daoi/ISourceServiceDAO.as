package com.photodispatcher.model.dao.daoi{
	import com.photodispatcher.model.SourceService;

	public interface ISourceServiceDAO{
		
		function getBySource(sourceId:int):Array;
		
		function save(item:SourceService):void;
		
		function update(item:SourceService):void;
		
		function create(item:SourceService):void;

	}
}