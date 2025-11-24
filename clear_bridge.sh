# it is important to clear all generadet flutter_bridge files
# for example when you become the rustdeskimpl_ error during the windows build
rm src/bridge_generated.io.rs
rm src/bridge_generated.rs
rm flutter/.flutter-plugins
rm flutter/.flutter-plugins-dependencies
rm -rf flutter/windows/flutter/ephemeral # dir this files would normally not remove without this script
rm flutter/windows/flutter/generated_plugin_registrant.cc # this files would normally not remove without this script
rm flutter/windows/flutter/generated_plugin_registrant.h # this files would normally not remove without this script
rm flutter/windows/flutter/generated_plugins.cmake #this files would normally not remove without this script
rm -rf flutter/.dart_tool #dir
rm -rf flutter/build/
rm libs/portable/data.bin
rm -rf /C//Users/chef/AppData/Local/escradesk
rm flutter/lib/generated_bridge.dart
rm flutter/lib/generated_bridge.freezed.dart
rm flutter/pubspec.lock



cd flutter
flutter clean
flutter pub get
cd ..

~/.cargo/bin/flutter_rust_bridge_codegen --rust-input ./src/flutter_ffi.rs --dart-output ./flutter/lib/generated_bridge.dart



# ich hatte wieder von rustdesk:// auf rustdesk:// gewechselt, dann schlug der buiöd fehl mit rustdeskimpl aber ich hatte auch
# den namen der in einem flutter-code von rustdesk auf escradsk während des build gewechselt
