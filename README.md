# Trackpad Audio Grid

A macOS application that creates an interactive audio grid controlled by trackpad location and pressure.

## Requirements

- macOS 10.11 or later
- Force Touch trackpad (MacBook 2015 or later, or Magic Trackpad)
- Xcode Command Line Tools

## Building

```bash
make
```

## Running

### Method 1: Direct execution
```bash
make run
```

### Method 2: As an app bundle
```bash
make app
open TrackpadAudioGrid.app
```

## Permissions

This application requires accessibility permissions to capture global trackpad events:

1. Go to System Preferences > Security & Privacy > Privacy > Accessibility
2. Click the lock to make changes
3. Add the TrackpadAudioGrid application
4. Enable the checkbox next to it

## How it Works

The application creates an interactive audio grid where:
- Horizontal position (X-axis) controls the pitch/frequency
- Vertical position (Y-axis) controls additional audio parameters
- Trackpad pressure controls the volume
- Different grid cells trigger different notes or sounds

## Notes

- Pressure values range from 0.0 (no pressure) to 1.0 (maximum pressure)
- The grid maps the trackpad surface to musical notes
- The application runs in the background (no dock icon)
- Press Ctrl+C to stop the application

## Troubleshooting

If the audio grid isn't working:
1. Ensure you have a Force Touch trackpad
2. Check that accessibility permissions are granted
3. Verify audio output is enabled and volume is up
4. Try pressing harder on the trackpad for volume control
5. Make sure you're running macOS 10.11 or later