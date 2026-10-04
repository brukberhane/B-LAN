#ifndef RUNNER_WINDOWS_PROXIMITY_H_
#define RUNNER_WINDOWS_PROXIMITY_H_

#include <flutter/binary_messenger.h>

class Win32Window;

// Registers com.brukb.blan/windows and the scans, inbound, and frames
// event channels. The channels are kept for the process. Event listen
// succeeds and sends nothing.
void RegisterWindowsProximity(flutter::BinaryMessenger* messenger,
                              Win32Window* window);

// Drops the window pointer so a later presentWindow returns noWindow.
void ClearWindowsProximityWindow();

#endif  // RUNNER_WINDOWS_PROXIMITY_H_
