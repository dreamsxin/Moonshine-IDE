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
package actionScripts.ui.tabview
{
    import actionScripts.valueObjects.HamburgerMenuTabsVO;

    import flash.display.DisplayObject;
	import flash.events.Event;
	import flash.geom.Matrix;
	import flash.utils.Dictionary;
	
	import mx.containers.Canvas;
	import mx.core.UIComponent;
	import mx.events.ResizeEvent;

    import spark.events.IndexChangeEvent;
	
    /*
        TODO:
            Make it clearer what selectedIndex means
            Use skins instead of drawing in TabViewTab
    */

	public class TabView extends Canvas
	{
		private var tabContainer:Canvas;
		private var itemContainer:Canvas;
		private var shadow:UIComponent;

        private var hamburgerMenuTabs:HamburgerMenuTabs;
		private var tabsModel:TabsModel;
		
		private var tabLookup:Dictionary = new Dictionary(true); // child:tab
		
		private var tabSizeDefault:int = 200;
		private var tabSizeMin:int = 100;
		
		protected var needsTabLayout:Boolean;
		protected var needsNewSelectedTab:Boolean;
		
		private var _selectedIndex:int = 0;
		public function get selectedIndex():int
		{
			return _selectedIndex;
		}

		public function set selectedIndex(value:int):void
		{
			if (itemContainer.numChildren == 0) return;
			if (value < 0) value = 0;
			_selectedIndex = value;
			
			// Explicitly set new, so no automagic needed.
			needsNewSelectedTab = false;
			
			// Select correct tab
			for (var i:int = 0; i < tabContainer.numChildren; i++)
			{
				if (i == value)
				{
					TabViewTab(tabContainer.getChildAt(i)).selected = true;	
				}
				else
				{
					TabViewTab(tabContainer.getChildAt(i)).selected = false;
				}
			}
			
			var itemToDisplay:DisplayObject = TabViewTab(tabContainer.getChildAt(value)).data as DisplayObject;
			
			// Display or hide content
			for (i = 0; i < itemContainer.numChildren; i++) 
			{	
				var child:DisplayObject = itemContainer.getChildAt(i);
				if (child == itemToDisplay)
				{
					child.visible = true;
					UIComponent(child).setFocus();
					dispatchEvent( new TabEvent(TabEvent.EVENT_TAB_SELECT, child) );
				} 
				else 
				{
					child.visible = false;
				}
			}
			
			invalidateLayoutTabs();
		}
		
		public function TabView()
		{
			super();

			tabsModel = new TabsModel();
			addEventListener(ResizeEvent.RESIZE, handleResize);
		}

		public function setSelectedTab(editor:DisplayObject):void
		{
            var childIndex:int = getChildIndex(editor);
            if (childIndex != selectedIndex && childIndex > -1)
            {
                selectedIndex = childIndex;
            }
			else
			{
			    var hamburgerMenuCount:int = tabsModel.hamburgerTabs.length;
				for (var i:int = 0; i < hamburgerMenuCount; i++)
				{
					var hamburgerMenuTabsVO:HamburgerMenuTabsVO = tabsModel.hamburgerTabs.getItemAt(i) as HamburgerMenuTabsVO;
					if (hamburgerMenuTabsVO.tabData == editor)
					{
						addTabFromHamburgerMenu(hamburgerMenuTabsVO);
						break;
					}
				}
			}
		}

		private function handleResize(event:Event):void
		{
			invalidateLayoutTabs();
		}
		
		override protected function createChildren():void
		{
			super.createChildren();
			
			tabContainer = new Canvas();
			tabContainer.styleName = "tabView";
			tabContainer.horizontalScrollPolicy = 'off';
			tabContainer.height = 25;
			tabContainer.percentWidth = 100;
			super.addChild(tabContainer);
			
			itemContainer = new Canvas();
			itemContainer.percentWidth = 100;
			itemContainer.percentHeight = 100;
			itemContainer.y = 25;
			super.addChild(itemContainer);
			
			shadow = new UIComponent();
			shadow.percentWidth = 200;
			shadow.height = 25;
			shadow.mouseEnabled = false;
			super.addChild(shadow);

			hamburgerMenuTabs = new HamburgerMenuTabs();
			hamburgerMenuTabs.right = 0;
			hamburgerMenuTabs.top = 0;
			hamburgerMenuTabs.visible = hamburgerMenuTabs.includeInLayout = false;
			hamburgerMenuTabs.model = tabsModel;
			hamburgerMenuTabs.addEventListener(Event.CHANGE, onHamburgerMenuTabsChange);
			
			super.addChild(hamburgerMenuTabs);
		}
		
		private function addTabFor(child:DisplayObject):void
		{
			var tab:TabViewTab = new TabViewTab();
			tab.data = child;
			tabLookup[child] = tab;
			if (child.hasOwnProperty('label')) 
			{
				tab.label = child['label'];
				child.addEventListener('labelChanged', updateTabLabel);
			}
			tabContainer.addChildAt(tab,0);

			tab.addEventListener(TabViewTab.EVENT_TAB_CLICK, onTabClick);
			tab.addEventListener(TabViewTab.EVENT_TAB_CLOSE, onTabClose);
			invalidateLayoutTabs();
        }
		
		private function removeTabFor(child:DisplayObject):void
		{
			var tab:DisplayObject = tabLookup[child];
			
			tabLookup[child] = null;
            tab.parent.removeChild(tab);

            child.removeEventListener('labelChanged', updateTabLabel);
            invalidateLayoutTabs();
		}
		
		private function onTabClose(event:Event):void
		{
			var child:DisplayObject = TabViewTab(event.target).data as DisplayObject;
			
			var te:TabEvent = new TabEvent(TabEvent.EVENT_TAB_CLOSE, child);
			dispatchEvent(te);
			if (te.isDefaultPrevented()) return;
			 
			removeChild(child);
			
			invalidateLayoutTabs();
		}

		private function updateTabLabel(event:Event):void
		{
			var child:DisplayObject = event.target as DisplayObject;
			var tab:TabViewTab = tabLookup[child];
			
			tab.label = child['label'];
		}
		
		private function onTabClick(event:Event):void
		{
			if (event.target.parent == tabContainer)
			{ 
				selectedIndex = tabContainer.getChildIndex(event.target as DisplayObject);
			} 
			else
			{
				var tab:TabViewTab = event.target as TabViewTab;
				tabContainer.addChild(tab);
				tab.selected = true;
				selectedIndex = tabContainer.numChildren-1;
			}
		}

		private function onHamburgerMenuTabsChange(event:IndexChangeEvent):void
		{
            addTabFromHamburgerMenu(hamburgerMenuTabs.selectedItem as HamburgerMenuTabsVO);
        }

		override public function getChildIndex(child:DisplayObject):int
		{
			var tab:DisplayObject = tabLookup[child];
			if (tab && tab.parent == tabContainer)
			{
				return tabContainer.getChildIndex(tab);
			}

			return -1;
		}
		
		override public function addChild(child:DisplayObject):DisplayObject
		{
			addTabFor(child);
			var editor:DisplayObject = itemContainer.addChild(child);
            selectedIndex = 0;

			return editor;
		}
		
		override public function removeChildAt(index:int):DisplayObject
		{
			invalidateTabSelection();

			removeTabFor(itemContainer.getChildAt(index));
			return itemContainer.removeChildAt(index);
		}
		
		override public function removeChild(child:DisplayObject):DisplayObject
		{
			invalidateTabSelection();

			var tab:TabViewTab = tabLookup[child];

			if (tab)
            {
                removeTabFor(child);
                return itemContainer.removeChild(child);
            }

			return null;
		}

        private function addTabFromHamburgerMenu(hamburgerMenuTabsVO:HamburgerMenuTabsVO):void
        {
            tabsModel.hamburgerTabs.removeItem(hamburgerMenuTabsVO);

            addChild(hamburgerMenuTabsVO.tabData);
            selectedIndex = 0;
        }

        protected function focusNewTab():void
		{
			if (selectedIndex-1 < tabContainer.numChildren)
				selectedIndex = _selectedIndex-1;
			else
				selectedIndex = 0;
		}

		protected function updateTabLayout():void
		{
			// Each item draws vertical separators on both sides, overlap by 1 px to not have duplicate lines.
			var availableWidth:int = width + 1;

			var tab:TabViewTab = null;
            var i:int;
			var numTabs:int = tabContainer.numChildren;
			hamburgerMenuTabs.visible = hamburgerMenuTabs.includeInLayout = isHamburgerMenuWithTabsVisible();

			if (!canAllTabsFitIntoAvailableSpace())
			{
				for (i = numTabs - 2; i > -1; i--)
				{
					tab = tabContainer.getChildAt(i) as TabViewTab;
					var tabData:DisplayObject = tab.data as DisplayObject;
					if (!tab.selected && tabData)
					{
						tabsModel.hamburgerTabs.addItem(new HamburgerMenuTabsVO(tab["label"], tabData));
						removeChild(tabData);
						break;
					}
				}
			}
			else
			{
                shiftHamburgerMenuTabsIfSpaceAvailable();
			}

            numTabs = tabContainer.numChildren;
			var tabWidth:int = int(availableWidth/numTabs);
			
			tabWidth = Math.max(tabWidth, tabSizeMin);
			tabWidth = Math.min(tabWidth, tabSizeDefault);
			tabWidth += 2;
			
			var pos:int = -2;
			for (i = tabContainer.numChildren-1; i > -1; i--)
			{
				tab = tabContainer.getChildAt(i) as TabViewTab;
				tab.x = pos;
				tab.y = 0;
				pos += tabWidth-1;
			}
		}

		private function shiftHamburgerMenuTabsIfSpaceAvailable():void
		{
			if (!canTabFitIntoAvailableSpace()) return;

			if (tabsModel.hamburgerTabs.length > 0)
			{
				var hamburgerMenuVO:HamburgerMenuTabsVO = tabsModel.hamburgerTabs.source.shift();
				addChild(hamburgerMenuVO.tabData);

				tabsModel.hamburgerTabs.refresh();

				shiftHamburgerMenuTabsIfSpaceAvailable();
			}
		}

		override protected function updateDisplayList(unscaledWidth:Number, unscaledHeight:Number):void
		{
			super.updateDisplayList(unscaledWidth, unscaledHeight);
			
			var mtr:Matrix = new Matrix();
			mtr.createGradientBox(unscaledWidth, 8, Math.PI/2, 0, 18);
			
			shadow.graphics.clear();
			shadow.graphics.beginGradientFill('linear', [0x000000, 0x000000], [0, 0.1], [0, 255], mtr);
			shadow.graphics.drawRect(0, 17, unscaledWidth, 8);
			shadow.graphics.endFill();
			
			shadow.graphics.lineStyle(1, 0x0, 0.4);
			shadow.graphics.moveTo(0, 24);
			shadow.graphics.lineTo(unscaledWidth, 24);
			
			if (needsNewSelectedTab)
			{
				focusNewTab();
				needsNewSelectedTab = false;
			} 
			
			if (needsTabLayout)
			{
				updateTabLayout();
				needsTabLayout = false;
			}
		}

		private function isHamburgerMenuWithTabsVisible():Boolean
		{
            var availableWidth:int = width + 1;
            var numTabs:int = tabContainer.numChildren;
            var allTabsWidth:Number = (numTabs + tabsModel.hamburgerTabs.length) * tabSizeDefault;

            return allTabsWidth > availableWidth;
        }

		private function canAllTabsFitIntoAvailableSpace():Boolean
		{
            var availableWidth:int = width + 1;
            var numTabs:int = tabContainer.numChildren;
            var allTabsWidth:Number = (numTabs + tabsModel.hamburgerTabs.length) * tabSizeDefault;
            var currentTabsWidth:Number = numTabs * tabSizeDefault;

            return !(allTabsWidth > availableWidth && currentTabsWidth > availableWidth);
		}

		private function canTabFitIntoAvailableSpace():Boolean
		{
            var availableWidth:int = width + 1;
            var numTabs:int = tabContainer.numChildren;
            var currentTabsWidth:Number = numTabs * tabSizeDefault;

			if (currentTabsWidth < availableWidth)
			{
				var widthOfEmptySpace:Number = availableWidth - currentTabsWidth;
				if (widthOfEmptySpace > 0 && widthOfEmptySpace > tabSizeDefault)
                {
                    return true;
                }
			}

			return false;
		}

		private function invalidateTabSelection():void
		{
            needsNewSelectedTab = true;
            invalidateDisplayList();
		}

        private function invalidateLayoutTabs():void
        {
            needsTabLayout = true;
            invalidateDisplayList();
        }
    }
}