.PHONY: build run clean install uninstall release prep

APP_NAME = Paperclip
BUNDLE_ID = cc.airbase.paperclip
BUILD_DIR = build
INSTALL_DIR = /Applications

# Prep: clean extended attributes that break codesign
prep:
	@xattr -cr Paperclip Paperclip.xcodeproj 2>/dev/null || true
	@rm -rf $(BUILD_DIR)

# Debug build
build: prep
	xcodebuild -project $(APP_NAME).xcodeproj -scheme $(APP_NAME) -configuration Debug -derivedDataPath $(BUILD_DIR) build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

# Release build
release: prep
	xcodebuild -project $(APP_NAME).xcodeproj -scheme $(APP_NAME) -configuration Release -derivedDataPath $(BUILD_DIR) build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

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
