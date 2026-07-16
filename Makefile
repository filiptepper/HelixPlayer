.PHONY: all generate build test run clean release

all: generate build

generate:
	python3 scripts/generate_icons.py
	python3 generate_xcodeproj.py

build: generate
	xcodebuild -project HelixPlayer.xcodeproj -scheme HelixPlayer -configuration Debug -sdk macosx build CONFIGURATION_BUILD_DIR=$(PWD)/build/Debug

test: generate
	xcodebuild -project HelixPlayer.xcodeproj -scheme HelixPlayerTests -configuration Debug -sdk macosx test CONFIGURATION_BUILD_DIR=$(PWD)/build/Debug

run: build
	./build/Debug/HelixPlayer.app/Contents/MacOS/HelixPlayer

release: generate
	xcodebuild -project HelixPlayer.xcodeproj -scheme HelixPlayer -configuration Release -sdk macosx build CONFIGURATION_BUILD_DIR=$(PWD)/build/Release CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""
	cd build/Release && zip -r ../../HelixPlayer-Release.zip HelixPlayer.app
	@echo "Local release build completed: HelixPlayer-Release.zip"

clean:
	rm -rf build HelixPlayer.xcodeproj HelixPlayer-Release.zip HelixPlayer/Assets.xcassets
