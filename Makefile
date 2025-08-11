CC = clang
CFLAGS = -fobjc-arc -framework Cocoa -framework AppKit -Wall
RAW_FLAGS = -fobjc-arc -framework Foundation -F/System/Library/PrivateFrameworks -framework MultitouchSupport -Wall
UI_FLAGS = -fobjc-arc -framework Cocoa -framework AppKit -framework QuartzCore -F/System/Library/PrivateFrameworks -framework MultitouchSupport -Wall
TARGET = TrackpadPressureLogger
RAW_TARGET = TrackpadRawLogger
UI_TARGET = TrackpadVisualizerApp
SOURCES = main.m TrackpadPressureLogger.m
RAW_SOURCES = TrackpadRawLogger.m
UI_SOURCES = TrackpadVisualizerApp.m
APP_NAME = TrackpadPressureLogger.app
UI_APP_NAME = TrackpadVisualizer.app

all: $(TARGET) $(RAW_TARGET) $(UI_TARGET)

$(TARGET): $(SOURCES)
	$(CC) $(CFLAGS) -o $(TARGET) $(SOURCES)

$(RAW_TARGET): $(RAW_SOURCES)
	$(CC) $(RAW_FLAGS) -o $(RAW_TARGET) $(RAW_SOURCES)

$(UI_TARGET): $(UI_SOURCES)
	$(CC) $(UI_FLAGS) -o $(UI_TARGET) $(UI_SOURCES)

app: $(TARGET)
	mkdir -p $(APP_NAME)/Contents/MacOS
	mkdir -p $(APP_NAME)/Contents/Resources
	cp $(TARGET) $(APP_NAME)/Contents/MacOS/
	cp Info.plist $(APP_NAME)/Contents/

ui-app: $(UI_TARGET)
	mkdir -p $(UI_APP_NAME)/Contents/MacOS
	mkdir -p $(UI_APP_NAME)/Contents/Resources
	cp $(UI_TARGET) $(UI_APP_NAME)/Contents/MacOS/
	echo '<?xml version="1.0" encoding="UTF-8"?>' > $(UI_APP_NAME)/Contents/Info.plist
	echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' >> $(UI_APP_NAME)/Contents/Info.plist
	echo '<plist version="1.0">' >> $(UI_APP_NAME)/Contents/Info.plist
	echo '<dict>' >> $(UI_APP_NAME)/Contents/Info.plist
	echo '    <key>CFBundleExecutable</key>' >> $(UI_APP_NAME)/Contents/Info.plist
	echo '    <string>TrackpadVisualizerApp</string>' >> $(UI_APP_NAME)/Contents/Info.plist
	echo '    <key>CFBundleIdentifier</key>' >> $(UI_APP_NAME)/Contents/Info.plist
	echo '    <string>com.example.trackpadvisualizer</string>' >> $(UI_APP_NAME)/Contents/Info.plist
	echo '    <key>CFBundleName</key>' >> $(UI_APP_NAME)/Contents/Info.plist
	echo '    <string>Trackpad Visualizer</string>' >> $(UI_APP_NAME)/Contents/Info.plist
	echo '    <key>CFBundlePackageType</key>' >> $(UI_APP_NAME)/Contents/Info.plist
	echo '    <string>APPL</string>' >> $(UI_APP_NAME)/Contents/Info.plist
	echo '    <key>LSMinimumSystemVersion</key>' >> $(UI_APP_NAME)/Contents/Info.plist
	echo '    <string>10.14</string>' >> $(UI_APP_NAME)/Contents/Info.plist
	echo '    <key>NSHighResolutionCapable</key>' >> $(UI_APP_NAME)/Contents/Info.plist
	echo '    <true/>' >> $(UI_APP_NAME)/Contents/Info.plist
	echo '</dict>' >> $(UI_APP_NAME)/Contents/Info.plist
	echo '</plist>' >> $(UI_APP_NAME)/Contents/Info.plist

run: $(TARGET)
	./$(TARGET)

run-raw: $(RAW_TARGET)
	./$(RAW_TARGET)

run-ui: $(UI_TARGET)
	./$(UI_TARGET)

clean:
	rm -f $(TARGET) $(RAW_TARGET) $(UI_TARGET)
	rm -rf $(APP_NAME) $(UI_APP_NAME)

audio-grid: TrackpadAudioGrid.m
	clang -fobjc-arc -framework Cocoa -framework AppKit -framework QuartzCore -framework AVFoundation -F/System/Library/PrivateFrameworks -framework MultitouchSupport -Wall -o TrackpadAudioGrid TrackpadAudioGrid.m

audio-grid-app: audio-grid
	mkdir -p TrackpadAudioGrid.app/Contents/MacOS
	mkdir -p TrackpadAudioGrid.app/Contents/Resources
	cp TrackpadAudioGrid TrackpadAudioGrid.app/Contents/MacOS/
	echo '<?xml version="1.0" encoding="UTF-8"?>' > TrackpadAudioGrid.app/Contents/Info.plist
	echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' >> TrackpadAudioGrid.app/Contents/Info.plist
	echo '<plist version="1.0">' >> TrackpadAudioGrid.app/Contents/Info.plist
	echo '<dict>' >> TrackpadAudioGrid.app/Contents/Info.plist
	echo '    <key>CFBundleExecutable</key>' >> TrackpadAudioGrid.app/Contents/Info.plist
	echo '    <string>TrackpadAudioGrid</string>' >> TrackpadAudioGrid.app/Contents/Info.plist
	echo '    <key>CFBundleIdentifier</key>' >> TrackpadAudioGrid.app/Contents/Info.plist
	echo '    <string>com.example.trackpadaudiogrid</string>' >> TrackpadAudioGrid.app/Contents/Info.plist
	echo '    <key>CFBundleName</key>' >> TrackpadAudioGrid.app/Contents/Info.plist
	echo '    <string>Trackpad Audio Grid</string>' >> TrackpadAudioGrid.app/Contents/Info.plist
	echo '    <key>CFBundlePackageType</key>' >> TrackpadAudioGrid.app/Contents/Info.plist
	echo '    <string>APPL</string>' >> TrackpadAudioGrid.app/Contents/Info.plist
	echo '    <key>LSMinimumSystemVersion</key>' >> TrackpadAudioGrid.app/Contents/Info.plist
	echo '    <string>10.14</string>' >> TrackpadAudioGrid.app/Contents/Info.plist
	echo '    <key>NSHighResolutionCapable</key>' >> TrackpadAudioGrid.app/Contents/Info.plist
	echo '    <true/>' >> TrackpadAudioGrid.app/Contents/Info.plist
	echo '</dict>' >> TrackpadAudioGrid.app/Contents/Info.plist
	echo '</plist>' >> TrackpadAudioGrid.app/Contents/Info.plist

run-audio-grid: audio-grid
	./TrackpadAudioGrid

.PHONY: all app ui-app audio-grid-app run run-raw run-ui run-audio-grid clean