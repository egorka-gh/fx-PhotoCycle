package com.photodispatcher.provider.fbook.download{
	import com.akmeful.fotakrama.data.Project;
	import com.akmeful.fotakrama.library.Library;
	import com.akmeful.fotakrama.net.CommonHttpService;
	import com.akmeful.fotakrama.net.ProjectService;
	import com.akmeful.fotakrama.net.events.ProjectServiceErrorEvent;
	import com.akmeful.fotakrama.net.events.ProjectServiceEvent;
	import com.akmeful.fotakrama.net.vo.project.ProjectViewVO;
	import com.akmeful.fotocalendar.data.FotocalendarProject;
	import com.akmeful.fotocalendar.net.vo.project.FotocalendarViewVO;
	import com.akmeful.fotokniga.book.data.Book;
	import com.akmeful.magnet.data.MagnetProject;
	import com.photodispatcher.model.Source;
	import com.photodispatcher.provider.fbook.FBookProject;
	
	import flash.events.Event;
	import flash.events.IEventDispatcher;

	[Event(name="complete", type="flash.events.Event")]
	public class FBookProjectLoader extends Library	{
		
		public var lastFetchedProject:FBookProject;
		public var lastFetchedType:int;
		public var lastFetchedId:int;
		public var lastErr:String;
		
		
		private var unknownType:Boolean=false;
		private var source:Source;

		public function FBookProjectLoader(source:Source){
			super(null);
			this.source=source;
			service= new ProjectService();
			if(source && source.fbookService){
				(service as ProjectService).baseURL=source.fbookService.url;
			}
		}
		
		override public function set service(value:CommonHttpService):void{
			if(service) service.removeEventListener(ProjectServiceErrorEvent.PROJECT_ERROR,serviceErrorHandler);
			super.service = value;
			if (value) value.addEventListener(ProjectServiceErrorEvent.PROJECT_ERROR,serviceErrorHandler);
		}
		
		override protected function serviceErrorHandler(event:ProjectServiceErrorEvent):void{
			if(unknownType){
				fetchProject(lastFetchedId,FotocalendarProject.PROJECT_TYPE);
				return;
			}
			lastErr='FBookProjectLoader: ' +event.text;
			dispatchEvent(new Event(Event.COMPLETE));  
		}
		
		public function fetchProject(projId:int, projType:int=-1):void{
			lastFetchedProject=null;
			lastErr='';
			if(!source || !source.fbookService || !source.fbookService.url){
				lastErr='FBookProjectLoader: не указаны параметры подключения';
				dispatchEvent(new Event(Event.COMPLETE));  
				return;
			}
			if(!service) return;
			unknownType=projType==-1;
			if(unknownType){
				projType=Book.PROJECT_TYPE;
			}
			lastFetchedType=projType;
			lastFetchedId=projId;
			switch(lastFetchedType){
				case Book.PROJECT_TYPE:
					var bvo:ProjectViewVO = new ProjectViewVO();
					var b:Book=new Book({id:projId});
					bvo.project = b;
					service.execute(bvo);
					break;
				case FotocalendarProject.PROJECT_TYPE:
					var cvo:FotocalendarViewVO=new FotocalendarViewVO();
					var c:FotocalendarProject=new FotocalendarProject({id:projId});
					cvo.project=c;
					service.execute(cvo);
					break;
				case MagnetProject.PROJECT_TYPE:
					var mvo:ProjectViewVO= new ProjectViewVO();
					mvo.updateTargetUrl(pathAlias.getPath('/magnet/view/', false));
					var mp:MagnetProject = new MagnetProject({id:projId});
					mvo.project=mp;
					service.execute(cvo);
					break;
			}
		}
		
		override protected function serviceHandler(event:ProjectServiceEvent):void {
			super.serviceHandler(event);
			lastErr='';
			switch(event.type){
				case ProjectServiceEvent.VIEW:
					var fetchedType:int=-1;
					var raw:Object=event.vo.result.data;
					if(raw.hasOwnProperty('type')){
						fetchedType=raw.type;
					}else{
						//TODO set default Book.PROJECT_TYPE (4 old version)
						fetchedType=Book.PROJECT_TYPE;
					}
					if (fetchedType==-1) return;
					if (fetchedType!=lastFetchedType){
						fetchProject(lastFetchedId,fetchedType);
						return;
					}
					unknownType=false;
					parseRawData(raw);
					dispatchEvent(new Event(Event.COMPLETE));  
					break;
				case ProjectServiceEvent.LIST:
					break;
			}
		}

		override protected function createItem(data:Object):Object {
			return new Project(data);
		}
		
		protected function parseRawData(rawData:Object):void {
			var b:FBookProject = new FBookProject(rawData);
			lastFetchedProject = b;
		}

	}
}