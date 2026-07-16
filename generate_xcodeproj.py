import os

xcodeproj_path = "HelixPlayer.xcodeproj"
os.makedirs(xcodeproj_path, exist_ok=True)

pbxproj_content = """// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 54;
	objects = {

/* Begin PBXBuildFile section */
		00000001 /* Info.plist in Resources */ = {isa = PBXBuildFile; fileRef = 00000005 /* Info.plist */; };
		00000002 /* HelixPlayerApp.swift in Sources */ = {isa = PBXBuildFile; fileRef = 00000006 /* HelixPlayerApp.swift */; };
		00000003 /* ContentView.swift in Sources */ = {isa = PBXBuildFile; fileRef = 00000007 /* ContentView.swift */; };
		00000004 /* HelixPlayerTests.swift in Sources */ = {isa = PBXBuildFile; fileRef = 00000008 /* HelixPlayerTests.swift */; };
		00000010 /* CoreAudioHelper.swift in Sources */ = {isa = PBXBuildFile; fileRef = 00000011 /* CoreAudioHelper.swift */; };
		00000012 /* AudioEngineManager.swift in Sources */ = {isa = PBXBuildFile; fileRef = 00000013 /* AudioEngineManager.swift */; };
		00000014 /* AUViewRepresentable.swift in Sources */ = {isa = PBXBuildFile; fileRef = 00000015 /* AUViewRepresentable.swift */; };
		00000017 /* Assets.xcassets in Resources */ = {isa = PBXBuildFile; fileRef = 00000016 /* Assets.xcassets */; };
/* End PBXBuildFile section */

/* Begin PBXContainerItemProxy section */
		00000020 /* PBXContainerItemProxy */ = {
			isa = PBXContainerItemProxy;
			containerPortal = 00000030 /* Project object */;
			proxyType = 1;
			remoteGlobalIDString = 00000040 /* HelixPlayer */;
			remoteInfo = HelixPlayer;
		};
/* End PBXContainerItemProxy section */

/* Begin PBXFileReference section */
		00000005 /* Info.plist */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; };
		00000006 /* HelixPlayerApp.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = HelixPlayerApp.swift; sourceTree = "<group>"; };
		00000007 /* ContentView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ContentView.swift; sourceTree = "<group>"; };
		00000008 /* HelixPlayerTests.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = HelixPlayerTests.swift; sourceTree = "<group>"; };
		00000011 /* CoreAudioHelper.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = CoreAudioHelper.swift; sourceTree = "<group>"; };
		00000013 /* AudioEngineManager.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = AudioEngineManager.swift; sourceTree = "<group>"; };
		00000015 /* AUViewRepresentable.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = AUViewRepresentable.swift; sourceTree = "<group>"; };
		00000016 /* Assets.xcassets */ = {isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; name = Assets.xcassets; path = Assets.xcassets; sourceTree = "<group>"; };
		00000050 /* HelixPlayer.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = HelixPlayer.app; sourceTree = BUILT_PRODUCTS_DIR; };
		00000060 /* HelixPlayerTests.xctest */ = {isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = HelixPlayerTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; };
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		00000070 /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
		00000071 /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		00000080 /* Main Group */ = {
			isa = PBXGroup;
			children = (
				00000090 /* HelixPlayer */,
				00000091 /* HelixPlayerTests */,
				00000092 /* Products */,
			);
			sourceTree = "<group>";
		};
		00000090 /* HelixPlayer */ = {
			isa = PBXGroup;
			children = (
				00000005 /* Info.plist */,
				00000006 /* HelixPlayerApp.swift */,
				00000007 /* ContentView.swift */,
				00000011 /* CoreAudioHelper.swift */,
				00000013 /* AudioEngineManager.swift */,
				00000015 /* AUViewRepresentable.swift */,
				00000016 /* Assets.xcassets */,
			);
			path = HelixPlayer;
			sourceTree = "<group>";
		};
		00000091 /* HelixPlayerTests */ = {
			isa = PBXGroup;
			children = (
				00000008 /* HelixPlayerTests.swift */,
			);
			path = HelixPlayerTests;
			sourceTree = "<group>";
		};
		00000092 /* Products */ = {
			isa = PBXGroup;
			children = (
				00000050 /* HelixPlayer.app */,
				00000060 /* HelixPlayerTests.xctest */,
			);
			name = Products;
			sourceTree = "<group>";
		};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		00000040 /* HelixPlayer */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = 000000a0 /* Build configuration list for PBXNativeTarget "HelixPlayer" */;
			buildPhases = (
				000000b0 /* Sources */,
				00000070 /* Frameworks */,
				000000c1 /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = HelixPlayer;
			productName = HelixPlayer;
			productReference = 00000050 /* HelixPlayer.app */;
			productType = "com.apple.product-type.application";
		};
		00000041 /* HelixPlayerTests */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = 000000a1 /* Build configuration list for PBXNativeTarget "HelixPlayerTests" */;
			buildPhases = (
				000000b1 /* Sources */,
				00000071 /* Frameworks */,
			);
			buildRules = (
			);
			dependencies = (
				000000c0 /* TargetDependency */,
			);
			name = HelixPlayerTests;
			productName = HelixPlayerTests;
			productReference = 00000060 /* HelixPlayerTests.xctest */;
			productType = "com.apple.product-type.bundle.unit-test";
		};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		00000030 /* Project object */ = {
			isa = PBXProject;
			attributes = {
				LastSwiftUpdateCheck = 1300;
				LastUpgradeCheck = 1300;
				TargetAttributes = {
					00000040 = {
						CreatedOnToolsVersion = 13.0;
					};
					00000041 = {
						CreatedOnToolsVersion = 13.0;
						TestTargetID = 00000040 /* HelixPlayer */;
					};
				};
			};
			buildConfigurationList = 000000d0 /* Build configuration list for PBXProject "HelixPlayer" */;
			compatibilityVersion = "Xcode 9.3";
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = 00000080 /* Main Group */;
			productRefGroup = 00000092 /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				00000040 /* HelixPlayer */,
				00000041 /* HelixPlayerTests */,
			);
		};
/* End PBXProject section */

/* Begin PBXSourcesBuildPhase section */
		000000b0 /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				00000002 /* HelixPlayerApp.swift in Sources */,
				00000003 /* ContentView.swift in Sources */,
				00000010 /* CoreAudioHelper.swift in Sources */,
				00000012 /* AudioEngineManager.swift in Sources */,
				00000014 /* AUViewRepresentable.swift in Sources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
		000000b1 /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				00000004 /* HelixPlayerTests.swift in Sources */,
				00000010 /* CoreAudioHelper.swift in Sources */,
				00000012 /* AudioEngineManager.swift in Sources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXSourcesBuildPhase section */

/* Begin PBXResourcesBuildPhase section */
		000000c1 /* Resources */ = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				00000017 /* Assets.xcassets in Resources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXResourcesBuildPhase section */

/* Begin PBXTargetDependency section */
		000000c0 /* TargetDependency */ = {
			isa = PBXTargetDependency;
			target = 00000040 /* HelixPlayer */;
			targetProxy = 00000020 /* PBXContainerItemProxy */;
		};
/* End PBXTargetDependency section */

/* Begin XCBuildConfiguration section */
		000000e0 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++17";
				CLANG_CXX_LIBRARY = "libc++";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_ENABLE_OBJC_WEAK = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_TESTABILITY = YES;
				GCC_C_LANGUAGE_STANDARD = gnu11;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_OPTIMIZATION_LEVEL = 0;
				GCC_PREPROCESSOR_DEFINITIONS = (
					"DEBUG=1",
					"$(inherited)",
				);
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				MACOSX_DEPLOYMENT_TARGET = 12.0;
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				MTL_FAST_MATH = YES;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = macosx;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
			};
			name = Debug;
		};
		000000e1 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++17";
				CLANG_CXX_LIBRARY = "libc++";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_ENABLE_OBJC_WEAK = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				GCC_C_LANGUAGE_STANDARD = gnu11;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				MACOSX_DEPLOYMENT_TARGET = 12.0;
				MTL_ENABLE_DEBUG_INFO = NO;
				MTL_FAST_MATH = YES;
				SDKROOT = macosx;
				SWIFT_COMPILATION_MODE = wholemodule;
				SWIFT_OPTIMIZATION_LEVEL = "-O";
			};
			name = Release;
		};
		000000e2 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				CODE_SIGN_STYLE = Automatic;
				CODE_SIGNING_ALLOWED = NO;
				CODE_SIGNING_REQUIRED = NO;
				CODE_SIGN_IDENTITY = "";
				COMBINE_HIDPI_IMAGES = YES;
				INFOPLIST_FILE = HelixPlayer/Info.plist;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/../Frameworks",
				);
				PRODUCT_BUNDLE_IDENTIFIER = com.helixplayer.HelixPlayer;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_VERSION = 5.0;
			};
			name = Debug;
		};
		000000e3 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				CODE_SIGN_STYLE = Automatic;
				CODE_SIGNING_ALLOWED = NO;
				CODE_SIGNING_REQUIRED = NO;
				CODE_SIGN_IDENTITY = "";
				COMBINE_HIDPI_IMAGES = YES;
				INFOPLIST_FILE = HelixPlayer/Info.plist;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/../Frameworks",
				);
				PRODUCT_BUNDLE_IDENTIFIER = com.helixplayer.HelixPlayer;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_VERSION = 5.0;
			};
			name = Release;
		};
		000000e4 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				BUNDLE_LOADER = "$(TEST_HOST)";
				CODE_SIGN_STYLE = Automatic;
				CODE_SIGNING_ALLOWED = NO;
				CODE_SIGNING_REQUIRED = NO;
				CODE_SIGN_IDENTITY = "";
				GENERATE_INFOPLIST_FILE = YES;
				PRODUCT_BUNDLE_IDENTIFIER = com.helixplayer.HelixPlayerTests;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_VERSION = 5.0;
				TEST_HOST = "$(BUILT_PRODUCTS_DIR)/HelixPlayer.app/Contents/MacOS/HelixPlayer";
			};
			name = Debug;
		};
		000000e5 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				BUNDLE_LOADER = "$(TEST_HOST)";
				CODE_SIGN_STYLE = Automatic;
				CODE_SIGNING_ALLOWED = NO;
				CODE_SIGNING_REQUIRED = NO;
				CODE_SIGN_IDENTITY = "";
				GENERATE_INFOPLIST_FILE = YES;
				PRODUCT_BUNDLE_IDENTIFIER = com.helixplayer.HelixPlayerTests;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_VERSION = 5.0;
				TEST_HOST = "$(BUILT_PRODUCTS_DIR)/HelixPlayer.app/Contents/MacOS/HelixPlayer";
			};
			name = Release;
		};
  /* End XCBuildConfiguration section */

  /* Begin XCConfigurationList section */
  		000000d0 /* Build configuration list for PBXProject "HelixPlayer" */ = {
  			isa = XCConfigurationList;
  			buildConfigurations = (
  				000000e0 /* Debug */,
  				000000e1 /* Release */,
  			);
  			defaultConfigurationIsVisible = 0;
  			defaultConfigurationName = Release;
  		};
  		000000a0 /* Build configuration list for PBXNativeTarget "HelixPlayer" */ = {
  			isa = XCConfigurationList;
  			buildConfigurations = (
  				000000e2 /* Debug */,
  				000000e3 /* Release */,
  			);
  			defaultConfigurationIsVisible = 0;
  			defaultConfigurationName = Release;
  		};
  		000000a1 /* Build configuration list for PBXNativeTarget "HelixPlayerTests" */ = {
  			isa = XCConfigurationList;
  			buildConfigurations = (
  				000000e4 /* Debug */,
  				000000e5 /* Release */,
  			);
  			defaultConfigurationIsVisible = 0;
  			defaultConfigurationName = Release;
  		};
  /* End XCConfigurationList section */
  	};
  	rootObject = 00000030 /* Project object */;
  }
  """

with open(os.path.join(xcodeproj_path, "project.pbxproj"), "w") as f:
    f.write(pbxproj_content)
print("HelixPlayer.xcodeproj generated successfully.")
