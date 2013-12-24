package com.photodispatcher.model.dao{
	import com.photodispatcher.model.LayerSequence;

	public class LayerSequenceDAO extends BaseDAO{

		public function getBySet(layerset:int, silent:Boolean=false):Array {
			var sql:String;
			var param:Array;
				sql="SELECT la.layerset, la.layer_group, la.seqorder, la.seqlayer, l.name  seqlayer_name"+
					" FROM config.layer_sequence la"+ 
					" INNER JOIN config.layer l ON l.id=la.seqlayer"+
					" WHERE la.layerset=?"+
					" ORDER BY la.layer_group, la.seqorder";
				param=[layerset];
			runSelect(sql,param,silent );
			return itemsArray ;
		}
		
		public function checkBySet(layerset:int, silent:Boolean=false):String {
			var sql:String;
			sql='SELECT l.name name'+
				' FROM config.layer l'+
				' LEFT OUTER JOIN config.layer_allocation la ON l.id=la.layer AND la.layerset=?'+
				' WHERE l.id=1 AND la.layerset is null'+
			  ' UNION'+
			   ' SELECT l.name'+
				' FROM config.layer_sequence ls'+
				' INNER JOIN config.layer l ON l.id=ls.seqlayer'+ 
				' LEFT OUTER JOIN config.layer_allocation la ON ls.seqlayer=la.layer AND la.layerset=ls.layerset'+
				' WHERE ls.layerset=? AND la.layerset is null';
			runSelect(sql,[layerset,layerset],silent );
			if(!lastResult) return '';
			var result:String='';
			for (var j:int=0; j<lastResult.length; j++){
				if(result) result+='\n';
				result=result+'Не назначен лоток для - '+lastResult[j].name;
			}
			return result;
		}
		
		//save batch iside group
		public function updateBatch(items:Array):void{
			if(!items || items.length==0) return;
			var sequence:Array=saveSequence(items);
			executeSequence(sequence);
		}

		//save sequence iside group
		public function saveSequence(items:Array):Array{
			var sequence:Array=[];
			var item:LayerSequence;
			var sql:String;
			var params:Array;
			var i:int;
			var seq:int=0;
			var arr:Array=[];
			if (!items) return [];
			for (i=0;i<items.length;i++){
				item= items[i] as LayerSequence;
				if(item){
					if(item.seqlayer>1){
						arr.push(item);
						seq++;//renum
						item.seqorder=seq;
						//persist
						sql='UPDATE config.layer_sequence SET seqlayer=?  WHERE layerset=? AND layer_group=? AND seqorder=?';
						params=[item.seqlayer, item.layerset, item.layer_group, item.seqorder];
						sequence.push(prepareStatement(sql,params));
						sql='INSERT OR IGNORE INTO config.layer_sequence(layerset, layer_group, seqorder, seqlayer) VALUES(?,?,?,?)';
						params=[item.layerset, item.layer_group, item.seqorder, item.seqlayer];
						sequence.push(prepareStatement(sql,params));
					}
				}
			}
			//del unused
			sql='DELETE FROM config.layer_sequence WHERE layerset=? AND layer_group=? AND seqorder>?';
			params=[item.layerset, item.layer_group, seq];
			sequence.push(prepareStatement(sql,params));
			
			//compact
			items.length=arr.length;
			for (i=0;i<arr.length;i++) items[i]=arr[i];
			
			return sequence;
		}

		override protected function processRow(o:Object):Object{
			var a:LayerSequence= new LayerSequence();
			fillRow(o,a);
			return a;
		}

	}
}