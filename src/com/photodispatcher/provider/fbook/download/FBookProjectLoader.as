package com.photodispatcher.provider.fbook.download{
	import com.akmeful.card.data.CardProject;
	import com.akmeful.fotakrama.cfg.PathAlias;
	import com.akmeful.fotakrama.data.Project;
	import com.akmeful.fotakrama.library.Library;
	import com.akmeful.fotakrama.net.CommonHttpService;
	import com.akmeful.fotakrama.net.ProjectService;
	import com.akmeful.fotakrama.net.events.ProjectServiceErrorEvent;
	import com.akmeful.fotakrama.net.events.ProjectServiceEvent;
	import com.akmeful.fotakrama.net.vo.project.ProjectViewVO;
	import com.akmeful.fotocalendar.data.FotocalendarProject;
	import com.akmeful.fotocalendar.net.vo.project.FotocalendarViewVO;
	import com.akmeful.fotocanvas.data.FotocanvasProject;
	import com.akmeful.fotocup.data.FotocupProject;
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
			var url:String; 
			super(null);
			this.source=source;
			this.pathAlias=PathAlias.instance;
			service= new ProjectService();
			if(source && source.fbookService){
				url=source.fbookService.url;
				if(url.substr(-1,1)=='/') url=url.substr(0,url.length-1);
				(service as ProjectService).baseURL=url;
			}
		}
		
		override public function set service(value:CommonHttpService):void{
			if(service) service.removeEventListener(ProjectServiceErrorEvent.PROJECT_ERROR,serviceErrorHandler);
			super.service = value;
			if (value) value.addEventListener(ProjectServiceErrorEvent.PROJECT_ERROR,serviceErrorHandler);
		}
		
		override protected function serviceErrorHandler(event:ProjectServiceErrorEvent):void{
			if(unknownType){
				switch(lastFetchedType){
					case Book.PROJECT_TYPE:
						//try calendar
						fetchProject(lastFetchedId,FotocalendarProject.PROJECT_TYPE);
						return;
						break;
					case FotocalendarProject.PROJECT_TYPE:
						//try magnet
						fetchProject(lastFetchedId,MagnetProject.PROJECT_TYPE);
						return;
						break;
					case MagnetProject.PROJECT_TYPE:
						fetchProject(lastFetchedId,FBookProject.PROJECT_TYPE_BCARD);
						return;
						break;
					case FBookProject.PROJECT_TYPE_BCARD:
						fetchProject(lastFetchedId,FotocanvasProject.PROJECT_TYPE);
						return;
						break;
					case FotocanvasProject.PROJECT_TYPE:
						fetchProject(lastFetchedId,FotocupProject.PROJECT_TYPE);
						return;
						break;
				}
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
			if(projType==-1){
				unknownType=true;
				projType=Book.PROJECT_TYPE;
			}
			lastFetchedType=projType;
			lastFetchedId=projId;
			var bvo:ProjectViewVO = new ProjectViewVO();
			var proj:Project;
			switch(lastFetchedType){
				case Book.PROJECT_TYPE:
					proj=new Book({id:projId});
					bvo.project = proj;
					service.execute(bvo);
					break;
				case FotocalendarProject.PROJECT_TYPE:
					var cvo:FotocalendarViewVO=new FotocalendarViewVO();
					var c:FotocalendarProject=new FotocalendarProject({id:projId});
					cvo.project=c;
					service.execute(cvo);
					break;
				case MagnetProject.PROJECT_TYPE:
					bvo.updateTargetUrl('/magnet/view/');
					proj= new MagnetProject({id:projId});
					bvo.project=proj;
					service.execute(bvo);
					break;
				case FBookProject.PROJECT_TYPE_BCARD:
					bvo.updateTargetUrl('/bcard/view/');
					proj= new CardProject('','',{id:projId});
					bvo.project=proj;
					service.execute(bvo);
					break;
				case FotocanvasProject.PROJECT_TYPE:
					//viewUrl="{pathAlias.getPath('/bcard/view/', false)}"
					bvo.updateTargetUrl('/canvas/view/');
					proj= new FotocanvasProject('','',{id:projId});
					bvo.project=proj;
					service.execute(bvo);
					break;
				case FotocupProject.PROJECT_TYPE:
					//viewUrl="{pathAlias.getPath('/bcard/view/', false)}"
					bvo.updateTargetUrl('/cup/view/');
					proj= new FotocupProject('','',{id:projId});
					bvo.project=proj;
					service.execute(bvo);
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
			return new Project('','',data);
		}
		
		protected function parseRawData(rawData:Object):void {
			var b:FBookProject = new FBookProject(rawData);
			lastFetchedProject = b;
		}

	}
}