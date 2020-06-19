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
	import actionScripts.factory.FileLocation;
	import actionScripts.plugins.ondiskproj.crud.exporter.components.RoyaleDataGridColumn;
	
	import view.dominoFormBuilder.vo.DominoFormFieldVO;
	import view.dominoFormBuilder.vo.DominoFormVO;
	
	public class ListingPageGenerator extends RoyalePageGeneratorBase
	{
		private var _pageRelativePathString:String;
		override protected function get pageRelativePathString():String		{	return _pageRelativePathString;	}
		
		public function ListingPageGenerator(projectPath:FileLocation, form:DominoFormVO)
		{
			_pageRelativePathString = "src/views/modules/"+ form.formName +"/"+ form.formName +"_views/"+ form.formName +"_listing.mxml";
			
			super(projectPath, form);
			generate();
		}
		
		override public function generate():void
		{
			var fileContent:String = loadPageFile();
			if (!fileContent) return;
			
			fileContent = fileContent.replace(/%DataGridColumns%/ig, generateColumns());
			fileContent = fileContent.replace(/%FormName%/g, form.viewName);
			saveFile(fileContent);
		}
		
		private function generateColumns():String
		{
			var tmpContent:String = "";
			for each (var field:DominoFormFieldVO in form.fields)
			{
				if (field.isIncludeInView)
				{
					tmpContent += RoyaleDataGridColumn.toCode(field) +"\n";
				}
			}
			
			return tmpContent;
		}
	}
}