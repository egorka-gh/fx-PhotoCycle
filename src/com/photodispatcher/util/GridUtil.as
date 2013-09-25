package com.photodispatcher.util{
	import spark.components.gridClasses.GridColumn;

	public class GridUtil{

		public static function idToLabel(item:Object, column:GridColumn):String{
			return item[column.dataField+'_name'];
		}
		public static function booleanToLabel(item:Object, column:GridColumn):String{
			return item[column.dataField]?'Да':'Нет';
		}

	}
}