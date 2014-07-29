/**
 * Generated by Gas3 v2.3.2 (Granite Data Services).
 *
 * NOTE: this file is only generated if it does not exist. You may safely put
 * your custom code here.
 */

package com.photodispatcher.model.mysql.entities {

    [Bindable]
    [RemoteClass(alias="com.photodispatcher.model.mysql.entities.AbstractEntity")]
    public class AbstractEntity extends AbstractEntityBase {
		public static const PERSIST_NEW:int=0;
		public static const PERSIST_LOADED:int=1;
		public static const PERSIST_CHANGED:int=-1;
		
		public function get loaded():Boolean{
			return this.persistState!=PERSIST_NEW;
		}
		public function set loaded(value:Boolean):void{
			this.persistState=value?PERSIST_LOADED:PERSIST_NEW;
		}

		private var _changed:Boolean;
		public function get changed():Boolean{
			return _changed;
		}
		public function set changed(value:Boolean):void{
			_changed=value;
			if(value && loaded) this.persistState=PERSIST_CHANGED;
		}

    }
}