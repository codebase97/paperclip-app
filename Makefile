.PHONY: build run clean install uninstall release

APP_NAME = Paperclip
BUNDLE_ID = cc.airbase.paperclip
BUILD_DIR = build
INSTALL_DIR = /Applications

# Debug build
build:
	xcodebuild -project $(APP_NAME).xcodeproj -scheme $(APP_NAME) -configuration Debug -derivedDataPath $(BUILD_DIR) build

# Release build
release:
	xcodebuild -project $(APP_NAME).xcodeproj -scheme $(APP_NAME) -configuration Release -derivedDataPath $(BUILD_DIR) build

# Build and run
run: build
	open $(BUILD_DIR)/Build/Products/Debug/$(APP_NAME).app

# Run release build
run-release: release
	open $(BUILD_DIR)/Build/Products/Release/$(APP_NAME).app

# Clean build artifacts
clean:
	rm -rf $(BUILD_DIR)
	xcodebuild -project $(APP_NAME).xcodeproj -scheme $(APP_NAME) clean

# Install to /Applications
install: release
	@echo "Installing $(APP_NAME) to $(INSTALL_DIR)..."
	@rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"
	@cp -R "$(BUILD_DIR)/Build/Products/Release/$(APP_NAME).app" "$(INSTALL_DIR)/"
	@echo "Installed. Grant Accessibility permissions in System Settings."

# Uninstall from /Applications
uninstall:
	@echo "Removing $(APP_NAME) from $(INSTALL_DIR)..."
	@rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"
	@echo "Uninstalled."

# Open Xcode project
xcode:
	open $(APP_NAME).xcodeproj

# Show help
help:
	@echo "Paperclip Menu Bar App"
	@echo ""
	@echo "Usage:"
	@echo "  make build        Build debug version"
	@echo "  make release      Build release version"
	@echo "  make run          Build and run debug"
	@echo "  make run-release  Build and run release"
	@echo "  make install      Install to /Applications"
	@echo "  make uninstall    Remove from /Applications"
	@echo "  make clean        Clean build artifacts"
	@echo "  make xcode        Open in Xcode"
