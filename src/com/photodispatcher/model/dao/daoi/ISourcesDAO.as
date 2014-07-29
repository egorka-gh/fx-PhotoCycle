package com.photodispatcher.model.dao.daoi{
	import com.photodispatcher.model.mysql.entities.Source;
	
	import mx.collections.ArrayCollection;

	public interface ISourcesDAO{
		
		function getItem(id:int):Source;
		
		function findAll():ArrayCollection;
		
		function save(item:Source):void;
		
		function update(item:Source):void;
		
		function create(item:Source):void;

	}
}