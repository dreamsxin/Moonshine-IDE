////////////////////////////////////////////////////////////////////////////////
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
// http://www.apache.org/licenses/LICENSE-2.0 
// 
// Unless required by applicable law or agreed to in writing, software 
// distributed under the License is distributed on an "AS IS" BASIS, 
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and 
// limitations under the License
// 
// No warranty of merchantability or fitness of any kind. 
// Use this software at your own risk.
// 
////////////////////////////////////////////////////////////////////////////////
package actionScripts.plugins.externalEditors
{	
	import flash.display.DisplayObject;
	import flash.events.Event;
	import flash.filesystem.File;
	import flash.net.registerClassAlias;
	
	import mx.collections.ArrayCollection;
	import mx.core.FlexGlobals;
	import mx.events.CloseEvent;
	import mx.managers.PopUpManager;
	import mx.utils.ObjectUtil;
	
	import actionScripts.events.FilePluginEvent;
	import actionScripts.events.SettingsEvent;
	import actionScripts.factory.FileLocation;
	import actionScripts.plugin.settings.ISettingsProvider;
	import actionScripts.plugin.settings.vo.ISetting;
	import actionScripts.plugin.settings.vo.LinkOnlySetting;
	import actionScripts.plugin.settings.vo.LinkOnlySettingVO;
	import actionScripts.plugins.build.ConsoleBuildPluginBase;
	import actionScripts.plugins.domino.settings.UpdateSitePathSetting;
	import actionScripts.plugins.externalEditors.importer.ExternalEditorsImporter;
	import actionScripts.plugins.externalEditors.settings.ExternalEditorSetting;
	import actionScripts.plugins.externalEditors.utils.ExternalEditorsSharedObjectUtil;
	import actionScripts.plugins.externalEditors.vo.ExternalEditorVO;
	import actionScripts.ui.renderers.FTETreeItemRenderer;
	import actionScripts.valueObjects.ConstantsCoreVO;
	
	import components.popup.ExternalEditorAddEditPopup;
	
	public class ExternalEditorsPlugin extends ConsoleBuildPluginBase implements ISettingsProvider
	{
		public static var NAMESPACE:String = "actionScripts.plugins.externalEditors::ExternalEditorsPlugin";
		
		private static const EVENT_ADD_EDITOR:String = "addNewEditor";
		private static const EVENT_VALIDATE_ALL_EDITORS:String = "validateAllEditors";
		
		public static var editors:ArrayCollection; 
		
		override public function get name():String			{ return "External Editors"; }
		override public function get author():String		{ return ConstantsCoreVO.MOONSHINE_IDE_LABEL + " Project Team"; }
		override public function get description():String	{ return "Accessing external editors from Moonshine-IDE"; }
		
		public var updateSitePath:String;
		
		private var updateSitePathSetting:UpdateSitePathSetting;
		private var editorsUntilSave:ArrayCollection;
		private var settings:Vector.<ISetting>;
		private var removedEditors:Array = [];
		private var addEditEditorWindow:ExternalEditorAddEditPopup;
		private var linkOnlySetting:LinkOnlySetting;
		
		override public function activate():void
		{
			super.activate();
			
			generateEditorsList();
			
			dispatcher.addEventListener(SettingsEvent.EVENT_SETTINGS_SAVED, onSettingsSaved, false, 0, true);
		}
		
		override public function deactivate():void
		{
			super.deactivate();
			
			dispatcher.removeEventListener(SettingsEvent.EVENT_SETTINGS_SAVED, onSettingsSaved);
		}

		override public function resetSettings():void
		{
			ExternalEditorsSharedObjectUtil.resetExternalEditorsInSO();
			editors = ExternalEditorsImporter.getDefaultEditors();
		}
		
		override public function onSettingsClose():void
		{
			editorsUntilSave = null;
			settings = null;
		}
		
        public function getSettingsList():Vector.<ISetting>
        {
			// not to affect original collection 
			// unless a save 
			registerClassAlias("actionScripts.plugins.externalEditors.vo.ExternalEditorVO", ExternalEditorVO);
			registerClassAlias("flash.filesystem.File", File);
			editorsUntilSave = ObjectUtil.clone(editors) as ArrayCollection;
			
			settings = new Vector.<ISetting>();
			linkOnlySetting = new LinkOnlySetting(new <LinkOnlySettingVO>[
				new LinkOnlySettingVO("Add New", EVENT_ADD_EDITOR),
				new LinkOnlySettingVO("Validate All", EVENT_VALIDATE_ALL_EDITORS)
			]);
			linkOnlySetting.addEventListener(EVENT_ADD_EDITOR, onEditorAdd, false, 0, true);
			
			settings.push(linkOnlySetting);
			for each (var editor:ExternalEditorVO in editorsUntilSave)
			{
				settings.push(
					getEditorSetting(editor)
				);
			}
			
			return settings;
        }
		
		private function getEditorSetting(editor:ExternalEditorVO):ExternalEditorSetting
		{
			var tmpSetting:ExternalEditorSetting = new ExternalEditorSetting(editor);
			tmpSetting.addEventListener(ExternalEditorSetting.EVENT_MODIFY, onEditorModify, false, 0, true);
			tmpSetting.addEventListener(ExternalEditorSetting.EVENT_REMOVE, onEditorRemove, false, 0, true);
			
			return tmpSetting;
		}
		
		private function generateEditorsList():void
		{
			editors = ExternalEditorsSharedObjectUtil.getExternalEditorsFromSO();
			if (!editors)
			{
				editors = ExternalEditorsImporter.getDefaultEditors();
			}
			
			updateEventListeners();
		}
		
		private function updateEventListeners():void
		{
			var eventName:String;
			for each (var editor:ExternalEditorVO in editors)
			{
				eventName = "eventOpenWithExternalEditor"+ editor.localID;
				dispatcher.addEventListener(eventName, onOpenWithExternalEditor, false, 0, true);
			}
			
			dispatcher.addEventListener(FTETreeItemRenderer.CONFIGURE_EXTERNAL_EDITORS, onOpenExternalEditorConfiguration, false, 0, true);
		}
		
		private function onSettingsSaved(event:SettingsEvent):void
		{
			
		}
		
		private function onOpenWithExternalEditor(event:FilePluginEvent):void
		{
			var editorID:String = event.type.replace("eventOpenWithExternalEditor", "");
			var editor:ExternalEditorVO;
			editors.source.some(function(item:ExternalEditorVO, index:int, arr:Array):Boolean {
				if (item.localID == editorID)
				{
					editor = item;
					return true;
				}
				return false;
			});
			
			if (editor)
			{
				runExternalEditor(editor, event.file);
			}
		}
		
		private function onOpenExternalEditorConfiguration(event:Event):void
		{
			dispatcher.dispatchEvent(new SettingsEvent(SettingsEvent.EVENT_OPEN_SETTINGS, NAMESPACE));
		}
		
		private function onEditorModify(event:Event):void
		{
			openEditorModifyPopup((event.target as ExternalEditorSetting).editor);
		}
		
		private function onEditorAdd(event:Event):void
		{
			openEditorModifyPopup();
		}
		
		private function openEditorModifyPopup(editor:ExternalEditorVO=null):void
		{
			if (!addEditEditorWindow)
			{
				addEditEditorWindow = PopUpManager.createPopUp(FlexGlobals.topLevelApplication as DisplayObject, ExternalEditorAddEditPopup, true) as ExternalEditorAddEditPopup;
				addEditEditorWindow.editor = editor;
				addEditEditorWindow.addEventListener(CloseEvent.CLOSE, onEditorEditPopupClosed);
				addEditEditorWindow.addEventListener(ExternalEditorAddEditPopup.UPDATE_EDITOR, onUpdateExternalEditorObject);
				
				PopUpManager.centerPopUp(addEditEditorWindow);
			}
			else
			{
				PopUpManager.bringToFront(addEditEditorWindow);
			}	
		}
		
		protected function onUpdateExternalEditorObject(event:Event):void
		{
			var editor:ExternalEditorVO = addEditEditorWindow.editor;
			if (editorsUntilSave.getItemIndex(editor) == -1)
			{
				onEditorSettingAdd(editor);
			}
		}
		
		protected function onEditorEditPopupClosed(event:CloseEvent):void
		{
			addEditEditorWindow.removeEventListener(CloseEvent.CLOSE, onEditorEditPopupClosed);
			addEditEditorWindow.removeEventListener(ExternalEditorAddEditPopup.UPDATE_EDITOR, onUpdateExternalEditorObject);
			
			PopUpManager.removePopUp(addEditEditorWindow);
			addEditEditorWindow = null;
		}
		
		private function onEditorRemove(event:Event):void
		{
			// store the editor references but
			// remove from the collection once Save
			// along with remove corresponding global listener
			removedEditors.push((event.target as ExternalEditorSetting).editor);
			
			editorsUntilSave.removeItem((event.target as ExternalEditorSetting).editor);
			settings.splice(settings.indexOf(event.target), 1);
			(event.target as ExternalEditorSetting).renderer.dispatchEvent(new Event('refresh'));
		}
		
		private function onEditorSettingAdd(editor:ExternalEditorVO):void
		{
			editorsUntilSave.addItem(editor);
			
			var tmpSetting:ExternalEditorSetting = getEditorSetting(editor);
			settings.push(tmpSetting);
			
			// force redraw of setting list using existing renderer
			(settings[2] as ExternalEditorSetting).renderer.dispatchEvent(new Event('refresh'));
		}
		
		private function runExternalEditor(editor:ExternalEditorVO, onPath:FileLocation):void
		{
			var command:String = "open -a '"+ editor.installPath.nativePath +"' '"+ onPath.fileBridge.nativePath +"'";
			print("%s", command);
			
			this.start(
				new <String>[command], null
			);
		}
	}
}