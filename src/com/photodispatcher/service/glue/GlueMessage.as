package com.photodispatcher.service.glue{
	import com.photodispatcher.util.ArrayUtil;
	
	public class GlueMessage{
		public static const MSG_CCH_END:String='@@';
		public static const MSG_CCH_BLOCK:String='~~';
		public static const MSG_CCH_ITEM:String='||';
		
		public static const MSG_ITEM_KEY_NAME:String='name';
		
		
		public static function parse(raw:String, cmd:GlueCmd):GlueMessage{
			var res:GlueMessage= new GlueMessage();
			if(cmd) res.command=cmd.command;
			if(!raw) return res;
			//remove end chars
			raw=raw.substring(0,raw.length-MSG_CCH_END.length);
			//split to blocks
			var rawBlocks:Array=raw.split(MSG_CCH_BLOCK);
			var rawBlock:String;
			var block:GlueMessageBlock;
			var items:Array;
			var rawItems:Array;
			var rawItem:String;
			var blockName:String;
			var idx:int;
			var item:GlueMessageItem;
			for each (rawBlock in rawBlocks){
				if(rawBlock){
					//split to items
					items=[];
					blockName='';
					rawItems=rawBlock.split(MSG_CCH_ITEM);
					for each (rawItem in rawItems){
						//parse item
						if(rawItem){
							idx=rawItem.indexOf('=');
							if(idx!=-1){
								item=new GlueMessageItem();
								item.key=rawItem.substring(0,idx);
								item.value=rawItem.substr(idx+1);
								if(item.key.toLowerCase()==MSG_ITEM_KEY_NAME){
									blockName=item.value;
								}else{
									items.push(item);
								}
							}
						}
					}
					//create block
					if(blockName || items.length>0){
						block=new GlueMessageBlock();
						block.items=items.concat();
						if(blockName) block.key=blockName;
						res.blocks.push(block);
					}
				}
			}
			return res;
		}

		public function GlueMessage(){
		}
		
		public var command:String;
		public var blocks:Array=[];
		
		public function getBlock(key:String):GlueMessageBlock{
			if(!blocks || blocks.length==0) return null;
			return ArrayUtil.searchItem('key',key, blocks) as GlueMessageBlock; 
		}
	}
}