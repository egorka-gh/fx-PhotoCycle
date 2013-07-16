package com.photodispatcher.print{
	import com.photodispatcher.event.PostCompleteEvent;
	import com.photodispatcher.model.BookSynonym;
	import com.photodispatcher.model.LabPrintCode;
	import com.photodispatcher.model.OrderState;
	import com.photodispatcher.model.PrintGroup;
	import com.photodispatcher.model.Source;
	import com.photodispatcher.model.SourceService;
	import com.photodispatcher.model.dao.LabPrintCodeDAO;
	
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;

	[Event(name="error", type="flash.events.ErrorEvent")]
	[Event(name="postComplete", type="com.photodispatcher.event.PostCompleteEvent")]
	public class LabBase extends Source implements IEventDispatcher{
		
		[Bindable]
		public var enabled:Boolean=true;
		[Bindable]
		public var stateCaption:String;
		
		protected var printTasks:Array=[];
		protected var _chanelMap:Object;
		
		public function LabBase(s:Source){
			super();
			this.changed=s.changed;
			this._hotFolder=s.hotFolder;
			this.id=s.id;
			this.loaded=s.loaded;
			this.loc_type=s.loc_type;
			this.name=s.name;
			this.online=s.online;
			this.type_id=s.type_id;
			this.type_name=s.type_name;
		}
		
		override public function get hotFolder():SourceService{
			return _hotFolder;
		}

		public function orderFolderName(printGroup:PrintGroup):String{
			return printGroup?printGroup.id:'';
		}

		public function post(printGroup:PrintGroup):void{
			if(!printGroup) return;
			var pt:PrintTask= new PrintTask(printGroup,this);
			printTasks.push(pt);
			//start post sequence
			stateCaption='Копирование';
			postNext();
		}
		
		private var postRunning:Boolean;
		private function postNext():void{
			if(postRunning) return;
			var pt:PrintTask;
			if(printTasks.length>0){
				pt=printTasks.shift() as PrintTask;
			}
			if(pt){
				postRunning=true;
				pt.addEventListener(Event.COMPLETE,taskComplete);
				pt.post();
			}else{
				//complited
				stateCaption='Копирование завершено';
			}
		}
		
		public function taskComplete(e:Event):void{
			postRunning=false;
			var pt:PrintTask=e.target as PrintTask;
			if(pt){
				pt.removeEventListener(Event.COMPLETE,taskComplete);
				if (pt.hasErr){
					dispatchEvent(new PostCompleteEvent(pt.printGrp,true,pt.errMsg));
				}else{
					dispatchEvent(new PostCompleteEvent(pt.printGrp));
				}
			}
			postNext();
		}
		
		/**
		 *print script props  
		 * */
		public function printChannel(printGroup:PrintGroup):String{
			var cm:Object=chanelMap;
			if(!cm) return '';
			var result:LabPrintCode=cm[printGroup.key(type_id)] as LabPrintCode;
			if(!result && printGroup.book_type!=0 
				&& printGroup.book_part!=BookSynonym.BOOK_PART_INSERT && printGroup.book_part!=BookSynonym.BOOK_PART_AU_INSERT){
				//lookup vs closest height
				var ch:LabPrintCode;
				for each (ch in cm){
					//exclude height
					if(ch && ch.key(type_id,1)==printGroup.key(type_id,1) && ch.height>=printGroup.height){
						if(!result){
							result=ch;
						}else if((result.height-printGroup.height)>(ch.height-printGroup.height)){
							result=ch;
						}
					}
				}
			}
			return result?result.prt_code:'';
		}

		public function canPrint(printGroup:PrintGroup):Boolean{
			var ch:String=printChannel(printGroup);
			return Boolean(ch);
		}
		
		// Lazy loading chanels
		protected function get chanelMap():Object{
			if(!_chanelMap){
				var dao:LabPrintCodeDAO= new LabPrintCodeDAO();
				var chanels:Array= dao.findAllArray(this.type_id);
				if(chanels){
					_chanelMap=new Object;
					for each(var o:Object in chanels){
						var ch:LabPrintCode=o as LabPrintCode;
						if(ch){
							_chanelMap[ch.key(type_id)]=ch;
						}
					}
				}
			}
			return _chanelMap;
		}
		
	}
}
