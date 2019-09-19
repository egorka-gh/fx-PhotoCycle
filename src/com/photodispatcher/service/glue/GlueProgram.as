package com.photodispatcher.service.glue
{
	import com.akmeful.commands.Command;
	
	import flash.events.EventDispatcher;
	
	import mx.collections.ArrayCollection;

	[Bindable]
	public class GlueProgram {
		
		public static function fromRaw(raw:Object):GlueProgram{
			var res:GlueProgram;
			if(!raw || !raw.hasOwnProperty('steps')) return null;
			res= new GlueProgram();
			res.steps= new ArrayCollection();
			for each (var st:Object in raw.steps){
				if(st.type){
					var step:GlueProgramStep= new GlueProgramStep();
					res.steps.addItem(step);
					step.type=st.type;
					step.interval=st.interval;
					step.command= st.command;
					if(st.checkBlocks && step.type==GlueProgramStep.TYPE_WAIT_FOR){
						step.checkBlocks= new ArrayCollection();
						for each (var b:Object in st.checkBlocks){
							if(b.items){
								var block:GlueMessageBlock= new GlueMessageBlock();
								step.checkBlocks.addItem(block);
								block.key=b.key;
								block.type=b.type;
								block.items= new ArrayCollection();
								for each (var it:Object in b.items){
									var item:GlueMessageItem= new GlueMessageItem();
									block.items.addItem(item);
									item.key=it.key;
									item.parentKey=block.key;
									item.type=block.type;
									item.value=it.value;
								}
							}
						}
					}
					step.setCaption();
				}
			}
			return res;
		}
		
		public function GlueProgram(){
			
		}
		
		public var steps:ArrayCollection; //GlueProgramStep
		
		public var product:String;

	}
}