#include "windows_proximity.h"

#include <flutter/encodable_value.h>
#include <flutter/event_channel.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>

#include "win32_window.h"

namespace {

flutter::EncodableValue ErrorEnvelope(const char* code) {
  flutter::EncodableMap map;
  map[flutter::EncodableValue("error")] = flutter::EncodableValue(std::string(code));
  return flutter::EncodableValue(map);
}

bool IsBleMethod(const std::string& method) {
  return method == "startAdvert" || method == "stopAdvert" ||
         method == "startScan" || method == "stopScan" ||
         method == "connectControl" || method == "startListening" ||
         method == "stopListening" || method == "sendFrame" ||
         method == "closeLink";
}

Win32Window* window_ = nullptr;

using EventChannel = flutter::EventChannel<flutter::EncodableValue>;

// Accepts listen and cancel. Sends no events. BLE is unavailable on this stub.
void RegisterIdleEvents(flutter::BinaryMessenger* messenger,
                        const std::string& name,
                        std::unique_ptr<EventChannel>* slot) {
  *slot = std::make_unique<EventChannel>(
      messenger, name, &flutter::StandardMethodCodec::GetInstance());
  (*slot)->SetStreamHandler(
      std::make_unique<flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
          [](const flutter::EncodableValue*,
             std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&&) {
            return nullptr;
          },
          [](const flutter::EncodableValue*) { return nullptr; }));
}

}  // namespace

void ClearWindowsProximityWindow() { window_ = nullptr; }

void RegisterWindowsProximity(flutter::BinaryMessenger* messenger,
                              Win32Window* window) {
  window_ = window;
  static std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      channel;
  channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "com.brukb.blan/windows",
      &flutter::StandardMethodCodec::GetInstance());

  static std::unique_ptr<EventChannel> scans;
  static std::unique_ptr<EventChannel> inbound;
  static std::unique_ptr<EventChannel> frames;
  RegisterIdleEvents(messenger, "com.brukb.blan/windows/scans", &scans);
  RegisterIdleEvents(messenger, "com.brukb.blan/windows/inbound", &inbound);
  RegisterIdleEvents(messenger, "com.brukb.blan/windows/frames", &frames);

  channel->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
             result) {
        const std::string& method = call.method_name();
        if (method == "presentWindow") {
          HWND hwnd = window_ == nullptr ? nullptr : window_->GetHandle();
          if (hwnd == nullptr) {
            result->Error("noWindow", "window missing");
            return;
          }
          ShowWindow(hwnd, SW_RESTORE);
          SetForegroundWindow(hwnd);
          result->Success();
          return;
        }
        if (method == "startHotspot") {
          result->Success(ErrorEnvelope("hotspotFailed"));
          return;
        }
        if (method == "startWifiDirect") {
          result->Success(ErrorEnvelope("wifiDirectFailed"));
          return;
        }
        if (method == "stopHotspot" || method == "stopWifiDirect" ||
            method == "leaveJoined") {
          result->Success();
          return;
        }
        if (method == "join") {
          result->Success(ErrorEnvelope("joinFailed"));
          return;
        }
        if (method == "currentWifi") {
          result->Success();
          return;
        }
        if (IsBleMethod(method)) {
          result->Success(ErrorEnvelope("bleUnavailable"));
          return;
        }
        result->NotImplemented();
      });
}
