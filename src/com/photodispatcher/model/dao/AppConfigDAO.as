package com.photodispatcher.model.dao{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.event.AsyncSQLEvent;
	import com.photodispatcher.model.AppConfig;
	
	import mx.collections.ArrayCollection;
	
	public class AppConfigDAO extends BaseDAO {
		
		public function getItem():AppConfig{
			if(runSelect("SELECT * FROM config.app_config WHERE id=?", ['0'])){
				return item as AppConfig;
			}else{
				return null;
			}
		}
		
		
		override public function save(item:Object):void{
			var it:AppConfig=item as AppConfig;
			if(!it) return;
			if (item.id){
				update(it);
			}else{
				//create(item);
			}
		}
		
		public function update(item:AppConfig):void{
			//addEventListener("asyncSQLEvent",onUpdate);
			execute(
				'UPDATE config.app_config SET wrk_path=?, monitor_interval=?, content_filter=?,'+
				' fbblok_font=?, fbblok_notching=?, fbblok_bar=?, fbblok_bar_offset=?,'+
				' fbcover_bar=?, fbcover_bar_offset=?, fbcover_font=?, fbcover_notching=?,'+
				' tech_bar=?, tech_bar_offset=?, tech_add=?, tech_bar_step=?, tech_bar_color=?'+
				' WHERE id=?',
				[	item.wrk_path,
					item.monitor_interval,
					item.content_filter,
					item.fbblok_font,
					item.fbblok_notching,
					item.fbblok_bar,
					item.fbblok_bar_offset,
					item.fbcover_bar,
					item.fbcover_bar_offset,
					item.fbcover_font,
					item.fbcover_notching,
					item.tech_bar,
					item.tech_bar_offset,
					item.tech_add,
					item.tech_bar_step,
					item.tech_bar_color,
					item.id],item);
		}
		/*
		private function onUpdate(e:AsyncSQLEvent):void{
			removeEventListener("asyncSQLEvent",onUpdate);
			if(e.result==AsyncSQLEvent.RESULT_COMLETED){
				var item:AppConfig=e.item as AppConfig;
				if(item) item.changed=false;
			}
		}*/
		
		override protected function processRow(o:Object):Object{
			var a:AppConfig = new AppConfig();
			/*
			a.id=o.id;
			a.wrk_path=o.wrk_path;
			a.monitor_interval=o.monitor_interval;
			
			a.loaded = true;
			*/
			fillRow(o,a);
			return a;
		}

	}
}