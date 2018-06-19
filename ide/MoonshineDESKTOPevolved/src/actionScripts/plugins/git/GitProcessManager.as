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
package actionScripts.plugins.git
{
	import flash.desktop.NativeProcess;
	import flash.desktop.NativeProcessStartupInfo;
	import flash.events.IOErrorEvent;
	import flash.events.NativeProcessExitEvent;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	import flash.utils.IDataInput;
	
	import mx.controls.Alert;
	import mx.events.CloseEvent;
	
	import actionScripts.events.GlobalEventDispatcher;
	import actionScripts.events.ShowSettingsEvent;
	import actionScripts.factory.FileLocation;
	import actionScripts.locator.IDEModel;
	import actionScripts.plugin.actionscript.as3project.vo.AS3ProjectVO;
	import actionScripts.plugin.actionscript.as3project.vo.BuildOptions;
	import actionScripts.plugin.console.ConsoleOutputter;
	import actionScripts.plugin.core.compiler.CompilerEventBase;
	import actionScripts.utils.UtilsCore;
	import actionScripts.valueObjects.ConstantsCoreVO;
	import actionScripts.valueObjects.Settings;

	public class GitProcessManager extends ConsoleOutputter
	{
		private var customProcess:NativeProcess;
		private var customInfo:NativeProcessStartupInfo;
		private var queue:Vector.<Object> = new Vector.<Object>();
		private var connectedDevices:Vector.<String>;
		private var windowsAutoJavaLocation:File;
		private var model:IDEModel = IDEModel.getInstance();
		private var isAndroid:Boolean;
		private var isErrorClose:Boolean;
		
		public var gitBinaryPathOSX:String;
		public var setGitAvailable:Function;
		
		protected var processType:String;
		
		private var onXCodePathDetection:Function;
		
		private var _cloningProjectName:String;
		private function get cloningProjectName():String
		{
			return _cloningProjectName;
		}
		private function set cloningProjectName(value:String):void
		{
			var quoteIndex:int = value.indexOf("'");
			_cloningProjectName = value.substring(++quoteIndex, value.indexOf("'", quoteIndex));
		}
		
		public function GitProcessManager()
		{
		}
		
		public function getOSXXCodePath(completion:Function):void
		{
			if (customProcess) startShell(false);
			onXCodePathDetection = completion;
			customInfo = renewProcessInfo();
			
			queue = new Vector.<Object>();
			
			addToQueue({com:'xcode-select -p', showInConsole:false});
			
			if (customProcess) startShell(false);
			startShell(true);
			flush();
		}
		
		public function checkGitAvailability():void
		{
			if (customProcess) startShell(false);
			customInfo = renewProcessInfo();
			
			queue = new Vector.<Object>();
			
			addToQueue({com:ConstantsCoreVO.IS_MACOS ? gitBinaryPathOSX +' --version' : 'git&&--version', showInConsole:false});
			
			if (customProcess) startShell(false);
			startShell(true);
			flush();
		}
		
		public function clone(url:String, target:String):void
		{
			if (customProcess) startShell(false);
			customInfo = renewProcessInfo();
			customInfo.workingDirectory = new File(target);
			
			queue = new Vector.<Object>();
			
			addToQueue({com:ConstantsCoreVO.IS_MACOS ? gitBinaryPathOSX +' clone --progress -v '+ url : 'git&&clone&&--progress&&-v&&'+ url, showInConsole:false});
			
			if (customProcess) startShell(false);
			startShell(true);
			flush();
		}
		
		public function runOnDevice(project:AS3ProjectVO, sdk:File, swf:File, descriptorPath:String, runAsDebugger:Boolean=false):void
		{
			isAndroid = (project.buildOptions.targetPlatform == "Android");
			
			// checks if the credentials are present
			if (!ensureCredentialsPresent(project)) return;
			
			// We need the application ID; without pre-guessing any
			// lets read and find it
			var descriptorFile:FileLocation = project.folderLocation.fileBridge.resolvePath(descriptorPath);
			var descriptorXML:XML = new XML(descriptorFile.fileBridge.read());
			var xmlns:Namespace = new Namespace(descriptorXML.namespace());
			var appID:String = descriptorXML.xmlns::id;
			
			var descriptorPathModified:Array = descriptorPath.split(File.separator);
			var adtPath:String = "-jar&&"+ sdk.nativePath +"/lib/adt.jar&&";
			
			// STEP 1
			//var executableFile:File = (Settings.os == "win") ? new File("c:\\Windows\\System32\\cmd.exe") : new File("/bin/bash");
			var executableFile:File;
			if (!ConstantsCoreVO.IS_MACOS && windowsAutoJavaLocation) executableFile = windowsAutoJavaLocation;
			else 
			{
				var tmpExecutableJava:FileLocation = UtilsCore.getJavaPath();
				if (tmpExecutableJava) executableFile = tmpExecutableJava.fileBridge.getFile as File;
				if (!ConstantsCoreVO.IS_MACOS && !windowsAutoJavaLocation) windowsAutoJavaLocation = executableFile;
			}
			
			if (!executableFile || !executableFile.exists)
			{
				Alert.show("You need Java to complete this process.\nYou can setup Java by going into Settings under File menu.", "Error!");
				return;
			}
			
			if (customProcess) startShell(false);
			customInfo = new NativeProcessStartupInfo();
			customInfo.executable = executableFile;
			customInfo.workingDirectory = swf.parent;
			
			queue = new Vector.<String>();
			queue.push("-c");
			
			addToQueue({com:adtPath +"-devices&&-platform&&"+ (isAndroid ? "android" : "ios"), showInConsole:false});
			
			var debugOptions:String = "";
			if(runAsDebugger)
			{
				debugOptions = "&&-connect";
			}

			var adtPackagingCom:String;
			if (isAndroid) 
			{
				var androidPackagingMode:String = null;
				if(runAsDebugger)
				{
					androidPackagingMode = "apk-debug";
				}
				else
				{
					androidPackagingMode = "apk";
				}
				adtPackagingCom = adtPath +'-package&&-target&&' + androidPackagingMode + debugOptions + '&&-storetype&&pkcs12&&-keystore&&'+ project.buildOptions.certAndroid +'&&-storepass&&'+ (isAndroid ? project.buildOptions.certAndroidPassword : project.buildOptions.certIosPassword) +'&&'+ project.name +'.apk' +'&&'+ descriptorPathModified[descriptorPathModified.length-1] +'&&'+ swf.name;
			}
			else
			{
				var iOSPackagingMode:String = null;
				if(runAsDebugger)
				{
					if(project.buildOptions.iosPackagingMode == BuildOptions.IOS_PACKAGING_FAST)
					{
						//fast bypasses bytecode translation interprets the SWF
						iOSPackagingMode = "ipa-debug-interpreter";
					}
					else
					{
						//standard takes longer to package
						//debug builds aren't meant for the app store, though
						iOSPackagingMode = "ipa-debug";
					}
				}
				else //release
				{
					if(project.buildOptions.iosPackagingMode == BuildOptions.IOS_PACKAGING_FAST)
					{
						//fast bypasses bytecode translation interprets the SWF
						iOSPackagingMode = "ipa-test-interpreter";
					}
					else
					{
						//standard takes longer to package
						//release builds are suitable for the app store
						iOSPackagingMode = "ipa-app-store";
					}
				}
					
				adtPackagingCom = adtPath +'-package&&-target&&' + iOSPackagingMode + debugOptions + '&&-storetype&&pkcs12&&-keystore&&'+ project.buildOptions.certIos +'&&-storepass&&'+ (isAndroid ? project.buildOptions.certAndroidPassword : project.buildOptions.certIosPassword) +'&&-provisioning-profile&&'+ project.buildOptions.certIosProvisioning +'&&'+ project.name +'.ipa' +'&&'+ descriptorPathModified[descriptorPathModified.length-1] +'&&'+ swf.name;
			}
			
			// extensions and resources
			if (project.nativeExtensions && project.nativeExtensions.length > 0) adtPackagingCom+= '&&-extdir&&'+ project.nativeExtensions[0].fileBridge.nativePath;
			if (project.resourcePaths)
			{
				for each (var i:FileLocation in project.resourcePaths)
				{
					adtPackagingCom += '&&'+ i.fileBridge.nativePath;
				}
			}
			
			addToQueue({com:adtPackagingCom, showInConsole:true});
			addToQueue({com:adtPath +"-installApp&&-platform&&"+ (isAndroid ? "android" : "ios") +"{{DEVICE}}-package&&"+ project.name +(isAndroid ? ".apk" : ".ipa"), showInConsole:true});
			addToQueue({com:adtPath +"-launchApp&&-platform&&"+ (isAndroid ? "android" : "ios") +"&&-appid&&"+ appID, showInConsole:true});
			
			if (customProcess) startShell(false);
			startShell(true);
			flush();
		}
		
		private function ensureCredentialsPresent(project:AS3ProjectVO):Boolean
		{
			if (isAndroid && (project.buildOptions.certAndroid && project.buildOptions.certAndroid != "") && (project.buildOptions.certAndroidPassword && project.buildOptions.certAndroidPassword != ""))
			{
				return true;
			}
			else if (!isAndroid && (project.buildOptions.certIos && project.buildOptions.certIos != "") && (project.buildOptions.certIosPassword && project.buildOptions.certIosPassword != "") && (project.buildOptions.certIosProvisioning && project.buildOptions.certIosProvisioning != ""))
			{
				return true;
			}
			
			Alert.show("Insufficient information. Process terminates.", "Error!", Alert.OK, null, onProcessTerminatesDueToCredentials);
			return false;
			
			/*
			 * @local
			 */
			function onProcessTerminatesDueToCredentials(event:CloseEvent):void
			{
				GlobalEventDispatcher.getInstance().dispatchEvent(
					new ShowSettingsEvent(project, "run")
				);
			}
		}
		
		private function addToQueue(value:Object):void
		{
			queue.push(value);
		}
		
		private function flush():void
		{
			if (queue.length == 0) 
			{
				startShell(false);
				return;
			}
			
			if (queue[0].showInConsole) debug("Sending to command: %s", queue[0].com);
			
			var tmpArr:Array = queue[0].com.split("&&");
			if (Settings.os == "win") tmpArr.insertAt(0, "/c");
			else tmpArr.insertAt(0, "-c");
			customInfo.arguments = Vector.<String>(tmpArr);
			
			queue.shift();
			customProcess.start(customInfo);
		}
		
		private function startShell(start:Boolean):void 
		{
			if (start)
			{
				customProcess = new NativeProcess();
				customProcess.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, shellData);
				
				// @note
				// for some strange reason all the standard output turns to standard error output by git command line.
				// to have them dictate and continue the native process (without terminating by assuming as an error)
				// let's listen standard errors to shellData method only
				customProcess.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, shellData);
				
				customProcess.addEventListener(IOErrorEvent.STANDARD_ERROR_IO_ERROR, shellError);
				customProcess.addEventListener(IOErrorEvent.STANDARD_OUTPUT_IO_ERROR, shellError);
				customProcess.addEventListener(NativeProcessExitEvent.EXIT, shellExit);
			}
			else
			{
				if (!customProcess) return;
				if (customProcess.running) customProcess.exit();
				customProcess.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, shellData);
				customProcess.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, shellData);
				customProcess.removeEventListener(IOErrorEvent.STANDARD_ERROR_IO_ERROR, shellError);
				customProcess.removeEventListener(IOErrorEvent.STANDARD_OUTPUT_IO_ERROR, shellError);
				customProcess.removeEventListener(NativeProcessExitEvent.EXIT, shellExit);
				customProcess = null;
				processType = null;
				isErrorClose = false;
				GlobalEventDispatcher.getInstance().dispatchEvent(new CompilerEventBase(CompilerEventBase.STOP_DEBUG,false));
			}
		}
		
		private function shellError(e:ProgressEvent):void 
		{
			if (customProcess)
			{
				var output:IDataInput = customProcess.standardError;
				var data:String = output.readUTFBytes(output.bytesAvailable);
				
				var syntaxMatch:Array;
				var generalMatch:Array;
				var initMatch:Array;
				var hideDebug:Boolean;
				
				syntaxMatch = data.match(/(.*?)\((\d*)\): col: (\d*) Error: (.*).*/);
				if (syntaxMatch) {
					var pathStr:String = syntaxMatch[1];
					var lineNum:int = syntaxMatch[2];
					var colNum:int = syntaxMatch[3];
					var errorStr:String = syntaxMatch[4];
				}
				
				generalMatch = data.match(/(.*?): Error: (.*).*/);
				if (!syntaxMatch && generalMatch)
				{ 
					pathStr = generalMatch[1];
					errorStr  = generalMatch[2];
					pathStr = pathStr.substr(pathStr.lastIndexOf("/")+1);
					error(data);
					hideDebug = true;
				}
				
				if (!hideDebug) debug("%s", data);
				isErrorClose = true;
				startShell(false);
			}
		}
		
		private function shellExit(e:NativeProcessExitEvent):void 
		{
			if (customProcess) 
			{
				if (!isErrorClose) 
				{
					if (processType == GitHubPlugin.CLONE_REQUEST) success("'"+ cloningProjectName +"' ...downloaded successfully ("+ customInfo.workingDirectory.nativePath + File.separator + cloningProjectName +")");
					flush();
				}
			}
		}
		
		private function shellData(e:ProgressEvent):void 
		{
			var output:IDataInput = (customProcess.standardOutput.bytesAvailable != 0) ? customProcess.standardOutput : customProcess.standardError;
			var data:String = output.readUTFBytes(output.bytesAvailable).toLowerCase();
			var match:Array;
			
			match = data.match(/git version/);
			if (match) 
			{
				setGitAvailable(true);
				return;
			}
			
			match = data.match(/xcode.app\/contents\/developer/);
			if (match && (onXCodePathDetection != null))
			{
				onXCodePathDetection(data);
				return;
			}
			
			match = data.match(/'git' is not recognized as an internal or external command/);
			if (match)
			{
				setGitAvailable(false);
				isErrorClose = true;
				startShell(false);
				return;
			}
			
			match = data.match(/cloning into/);
			if (match)
			{
				// for some weird reason git clone always
				// turns to errordata first
				processType = GitHubPlugin.CLONE_REQUEST;
				cloningProjectName = data;
				warning(data);
				return;
			}
			
			isErrorClose = false;
			debug("%s", data);
		}
		
		private function renewProcessInfo():NativeProcessStartupInfo
		{
			customInfo = new NativeProcessStartupInfo();
			customInfo.executable = (Settings.os == "win") ? new File("c:\\Windows\\System32\\cmd.exe") : new File("/bin/bash");
			
			return customInfo;
		}
	}
}