package com.photodispatcher.model.dao{
	import com.photodispatcher.model.mysql.entities.OrderState;
	
	import mx.collections.ArrayCollection;

	public class DictionaryDAOKill extends BaseDAO{
		public static const PRINT_FAMILY:int=1;
		public static const ORDER_FAMILY:int=2;

		private static var synonymMap:Object;
		
		public static function initSynonymMap():Boolean{
			if(synonymMap) return true;
			var dao:DictionaryDAO= new DictionaryDAO();
			var sql:String="SELECT a.src_type, a.synonym, at.field, (CASE at.list WHEN '1' THEN a.attr_val ELSE av.value END) value"+
							 " FROM config.attr_synonym a, config.attr_value av, config.attr_type at"+
							 " WHERE  a.attr_val = av.id AND av.attr_tp = at.id AND at.attr_fml = 1";
			dao.runSelect(sql,[],true);
			var a:Array=dao.itemsArray;
			if(!a) return false; //read lock
			var newMap:Object=new Object();
			var subMap:Object;
			var fv:FieldValue;
			var fa:Array;
			for each(fv in a){
				if(fv){
					subMap=newMap[fv.src_type.toString()];
					if(!subMap){
						subMap= new Object();
						newMap[fv.src_type.toString()]=subMap;
					}
					fa=subMap[fv.synonym] as Array;
					if(!fa){
						fa=[];
						subMap[fv.synonym]=fa;
					}
					fa.push(fv);
				}
			}
			synonymMap=newMap;
			return true;
		}
		
		/**
		 * parses print properties from path
		 * @param sourceType
		 * @return array of FieldValue 
		 * 
		 */
		public static function translatePath(sourceType:int, path:String):Array{
			if(!synonymMap){
				if(!initSynonymMap()) throw new Error('Блокировка чтения (translatePath)',OrderState.ERR_READ_LOCK);
			}
			var result:Array=[];
			if(!path) return result;
			var map:Object=synonymMap[sourceType.toString()];
			if(!map) return result;
			
			var parse:String=path;
			var synonym:String;
			var re:RegExp;
			var idx:int;
			for (synonym in map){
				if(!parse) break;
				if(synonym){
					re=new RegExp(synonym,'gi');
					idx=parse.search(re);
					if(idx!=-1){
						result=result.concat(map[synonym]);
						parse=parse.replace(re,'');
					}
				}
			}
			return result;
		}

		/**
		 * translate word 2 value
		 * @param 
		 * @return FieldValue 
		 * 
		 */
		public static function translateWord(sourceType:int, word:String, field:String):FieldValue{
			if(!synonymMap){
				if(!initSynonymMap()) throw new Error('Блокировка чтения (translateWord)',OrderState.ERR_READ_LOCK);
			}
			//var result:FieldValue;
			if(!word || !field) return null;
			var map:Object=synonymMap[sourceType.toString()];
			if(!map) return null;
			var fa:Array=map[word];
			if(fa){
				var fv:FieldValue;
				for each(fv in fa){
					if(fv && fv.field==field) return fv;
				}
			}
			return null;
		}


		override protected function processRow(o:Object):Object{
			var a:FieldValue = new FieldValue();
			a.field=o.field;
			a.value=o.value; 
			a.label=o.label;
			a.src_type=o.src_type;
			a.synonym=o.synonym;
			return a;
		}

		/**
		 * parses print properties from path
		 * @param sourceType
		 * @return array of FieldValue 
		 * 
		 */
		/*
		public function translatePath(sourceType:int, path:String):Array{
			var sql:String;
			sql="SELECT at.field, (CASE at.list WHEN '1' THEN a.attr_val ELSE av.value END) value"+
				 " FROM config.attr_synonym a, config.attr_value av, config.attr_type at"+
				 " WHERE a.src_type = ? AND a.attr_val = av.id AND av.attr_tp = at.id AND at.attr_fml = 1"+ 
				      " AND ? LIKE '%' || REPLACE( a.synonym, '_', '~_' ) || '%' ESCAPE '~'";
			runSelect(sql,[sourceType,path]);
			var a:Array=itemsArray;
			if(a==null) throw new Error('Блокировка чтения (translatePath)',OrderState.ERR_READ_LOCK);
			return a;
		}
		*/

		/**
		 * translate word 2 value
		 * @param 
		 * @return FieldValue 
		 * 
		 */
		/*
		public function translateWord(sourceType:int, word:String, field:String, family:int=PRINT_FAMILY):FieldValue{
			var sql:String;
			sql='SELECT at.field, a.attr_val value'+
				 ' FROM config.attr_synonym a, config.attr_value av, config.attr_type at'+
				' WHERE a.src_type = ? AND a.attr_val = av.id AND av.attr_tp = at.id AND at.attr_fml = ? AND a.synonym = ? AND at.field = ?';
			//trace('DictionaryDAO.translateWord: '+sql);
			runSelect(sql,[sourceType,family,word,field]);
			var a:Array=itemsArray;
			if(a==null) throw new Error('Блокировка чтения (translateWord)',OrderState.ERR_READ_LOCK);
			var res:FieldValue;
			if(a && a.length>0) res=a[0];
			return res;
		}
		*/
		
		public function getFieldValueList(fieldId:int, addNone:Boolean=true):ArrayCollection{
			var sql:String;
			sql='SELECT id value, value label FROM config.attr_value av WHERE av.attr_tp IN (0,?)';
			if(addNone){
				//sql='SELECT id value, value label FROM config.attr_value av WHERE av.attr_tp = 0 UNION '+sql;
				sql="SELECT 0 value, ' ' label UNION "+sql;
			}
			runSelect(sql,[fieldId]);
			return itemsList;
		}

		/*
		public function getPDFValueList(includeDefault:Boolean=true):ArrayCollection{
			var sql:String;
			sql='SELECT id value, name label FROM config.pdf_template';
			if(!includeDefault){
				sql=sql + ' WHERE id != 0';
			}
			runSelect(sql);
			return itemsList;
		}
		*/

		public function getBookTypeValueList(includeDefault:Boolean=true):ArrayCollection{
			var sql:String;
			sql='SELECT id value, name label FROM config.book_type';
			if(!includeDefault){
				sql=sql + ' WHERE id != 0';
			}
			runSelect(sql);
			return itemsList;
		}

		public function getBookPartValueList(includeDefault:Boolean=true):ArrayCollection{
			var sql:String;
			sql='SELECT id value, name label FROM config.book_part';
			if(!includeDefault){
				sql=sql + ' WHERE id != 0';
			}
			runSelect(sql);
			return itemsList;
		}

		public function getSrcTypeValueList(loc_type:int=1,includeDefault:Boolean=true):ArrayCollection{
			var sql:String;
			sql='SELECT id value, name label FROM config.src_type WHERE loc_type = ?';
			if(includeDefault){
				sql=sql + ' OR id = 0';
			}
			runSelect(sql,[loc_type]);
			return itemsList;
		}

		public function getWeekDaysValueList(includeDefault:Boolean=true):ArrayCollection{
			var sql:String;
			sql='SELECT id value, name label FROM config.week_days ORDER BY id';
			if(includeDefault){
				sql="SELECT 0 value, ' ' label UNION "+sql;
			}
			runSelect(sql);
			return itemsList;
		}

		public function getTechPointValueList(includeDefault:Boolean=true):ArrayCollection{
			var sql:String;
			sql='SELECT id value, name label FROM config.tech_point ORDER BY id';
			if(includeDefault){
				sql="SELECT null value, ' ' label UNION "+sql;
			}
			runSelect(sql);
			return itemsList;
		}

		public function getTechLayerValueList(includeDefault:Boolean=true):ArrayCollection{
			var sql:String;
			
			//if(includeDefault){
				sql='SELECT id value, name label FROM config.layer ORDER BY id';
			//}else{
			//	sql='SELECT id value, name label FROM config.layer WHERE id!=1 ORDER BY id';
			//}
			runSelect(sql);
			return itemsList;
		}

		public function getLayerGroupValueList(includeDefault:Boolean=false, full:Boolean=false):ArrayCollection{
			var sql:String;
			sql='SELECT id value, name label FROM config.layer_group';
			if(!full) sql+=' WHERE id!=2';//exclude sheet group 
			sql+=' ORDER BY id';
			if(includeDefault){
				sql="SELECT null value, ' ' label UNION "+sql;
			}
			runSelect(sql);
			return itemsList;
		}

		public function getRollValueList(includeDefault:Boolean=true):ArrayCollection{
			var sql:String;
			sql='SELECT width value, width label FROM config.roll ORDER BY width';
			if(includeDefault){
				sql="SELECT null value, ' ' label UNION "+sql;
			}
			runSelect(sql);
			return itemsList;
		}

	}
}