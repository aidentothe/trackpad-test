# Trackpad Pressure Logger

A macOS application that logs trackpad location and pressure data to the terminal.

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
open TrackpadPressureLogger.app
```

## Permissions

This application requires accessibility permissions to capture global trackpad events:

1. Go to System Preferences > Security & Privacy > Privacy > Accessibility
2. Click the lock to make changes
3. Add the TrackpadPressureLogger application
4. Enable the checkbox next to it

## Output Format

The logger outputs data in the following format:
```
[HH:mm:ss.SSS] EVENT_TYPE | Location: (X, Y) | Pressure: P.PPP
```

Where:
- `HH:mm:ss.SSS` - Timestamp with milliseconds
- `EVENT_TYPE` - Type of event (MOVE, DOWN, UP, DRAG, PRESSURE)
- `X, Y` - Screen coordinates
- `P.PPP` - Pressure value (0.000 to 1.000)

## Notes

- Pressure values range from 0.0 (no pressure) to 1.0 (maximum pressure)
- Location coordinates are in screen space
- The application runs in the background (no dock icon)
- Press Ctrl+C to stop the logger

## Troubleshooting

If you're not seeing pressure data:
1. Ensure you have a Force Touch trackpad
2. Check that accessibility permissions are granted
3. Try pressing harder on the trackpad
4. Make sure you're running macOS 10.11 or later