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
package actionScripts.plugins.ondiskproj.crud.exporter.pages
{
	import actionScripts.plugins.ondiskproj.crud.exporter.components.RoyaleFormItem;
	import actionScripts.plugins.ondiskproj.crud.exporter.settings.RoyaleCRUDClassReferenceSettings;
	import actionScripts.plugins.ondiskproj.crud.exporter.utils.RoyaleCRUDUtils;
	import actionScripts.valueObjects.ProjectVO;
	
	import view.dominoFormBuilder.vo.DominoFormFieldVO;
	import view.dominoFormBuilder.vo.DominoFormVO;
	
	public class AddEditPageGenerator extends RoyalePageGeneratorBase
	{
		private var _pageRelativePathString:String;
		override protected function get pageRelativePathString():String		{	return _pageRelativePathString;	}
		
		public function AddEditPageGenerator(project:ProjectVO, form:DominoFormVO, classReferenceSettings:RoyaleCRUDClassReferenceSettings)
		{
			_pageRelativePathString = "views/modules/"+ form.formName +"/"+ form.formName +"_views/"+ form.formName +"_addEdit.mxml";
			
			super(project, form, classReferenceSettings);
			generate();
		}
		
		override public function generate():void
		{
			var fileContent:String = loadPageFile();
			if (!fileContent) return;
			
			generateClassReferences();
			
			fileContent = fileContent.replace(/%ImportStatements%/ig, "import "+ classReferenceSettings[(form.formName +"_listing"+ RoyaleCRUDClassReferenceSettings.IMPORT)] +";\n");
			fileContent = fileContent.replace(/%ListingComponentName%/ig, form.formName +"_listing");
			fileContent = fileContent.replace(/%ViewComponentName%/ig, form.formName +"_addEdit");
			
			fileContent = fileContent.replace(/%FormItems%/ig, generateFormItems());
			fileContent = fileContent.replace(/%FormName%/ig, form.viewName);
			saveFile(fileContent);
		}
		
		private function generateFormItems():String
		{
			var tmpContent:String = "";
			for each (var field:DominoFormFieldVO in form.fields)
			{
				tmpContent += RoyaleFormItem.toCode(field) +"\n";
			}
			
			return tmpContent;
		}
		
		private function generateClassReferences():void
		{
			if (!classReferenceSettings.hasOwnProperty(form.formName +"_listing"+ RoyaleCRUDClassReferenceSettings.IMPORT))
			{
				var importPath:String = RoyaleCRUDUtils.getImportReferenceFor(form.formName +"_listing.mxml", project, ["mxml"]);
				classReferenceSettings[(form.formName +"_listing"+ RoyaleCRUDClassReferenceSettings.IMPORT)] = importPath;
				
				var splitPath:Array = importPath.split(".");
				splitPath[splitPath.length - 1] = "*";
				classReferenceSettings[(form.formName +"_listing"+ RoyaleCRUDClassReferenceSettings.NAMESPACE)] = splitPath.join(".");
			}
		}
	}
}