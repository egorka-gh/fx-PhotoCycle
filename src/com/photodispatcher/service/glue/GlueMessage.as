package com.photodispatcher.service.glue{
	import com.photodispatcher.util.ArrayUtil;
	
	import mx.utils.StringUtil;
	
	public class GlueMessage{
		public static const MSG_CCH_END:String='@@';
		public static const MSG_CCH_BLOCK:String='~~';
		public static const MSG_CCH_ITEM:String='||';
		
		public static const ITEM_KEY_NAME:String='Name';
		public static const ITEM_KEY_TEXT:String='Text';
		public static const ITEM_KEY_COLTEXT:String='ColText';
		public static const ITEM_KEY_COLBACK:String='ColBack';
		public static const ITEM_KEY_ENABLED:String='Enabled';

		public static const BLOCK_KEY_PRODUCT:String='Product';
		public static const BLOCK_KEY_GLM:String='GLM';
		public static const BLOCK_KEY_GBT:String='GBT';
		public static const BLOCK_KEY_BOOKS:String='Books';
		public static const BLOCK_KEY_BOOKSDAY:String='Books/Day';
		public static const BLOCK_KEY_PAGE:String='Page';
		public static const BLOCK_KEY_LASTBOOK:String='Last book';
		public static const BLOCK_KEY_PAGESBOOK:String='Pages per Book';

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
				rawBlock=StringUtil.trim(rawBlock);
				if(rawBlock){
					//split to items
					items=[];
					blockName='';
					rawItems=rawBlock.split(MSG_CCH_ITEM);
					for each (rawItem in rawItems){
						//parse item
						rawItem=StringUtil.trim(rawItem);
						if(rawItem){
							idx=rawItem.indexOf('=');
							if(idx!=-1){
								item=new GlueMessageItem();
								item.key=StringUtil.trim(rawItem.substring(0,idx));
								item.value=StringUtil.trim(rawItem.substr(idx+1));
								if(item.key==ITEM_KEY_NAME){
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
						if(!block.key && cmd.command==GlueProxy.CMD_GET_STATUS){
							//parse Text item by ':'
							item=block.getItem(ITEM_KEY_TEXT);
							if(item && item.value){
								rawItem=item.value;
								idx=rawItem.indexOf(':');
								if(idx!=-1){
									block.key=StringUtil.trim(rawItem.substring(0,idx));
									item.value=StringUtil.trim(rawItem.substr(idx+1));
								}
							}
						}
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
		
		public function getBlockItemValue(keyBlock:String, keyItem:String):String{
			var result:String='';
			var block:GlueMessageBlock=getBlock(keyBlock);
			if(block){
				var item:GlueMessageItem=block.getItem(keyItem);
				if(item && item.value) result=item.value;
			}
			return result;
		}
		
	}
}