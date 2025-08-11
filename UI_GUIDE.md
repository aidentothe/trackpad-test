# Trackpad Visualizer UI

A graphical user interface for visualizing trackpad touches in real-time using the MultitouchSupport API.

## Features

- **Visual Trackpad Surface**: Shows a graphical representation of the trackpad with grid lines
- **Real-time Finger Tracking**: Displays finger positions as colored circles
- **Pressure Visualization**: Circle size changes based on touch pressure
- **Touch Trails**: Shows movement paths for each finger
- **Multi-finger Support**: Tracks up to 10 simultaneous touches
- **State Indicators**: Different colors for hover vs touch states
- **Live Data Log**: Scrolling text log of all touch events with timestamps
- **Finger IDs**: Each touch point shows its unique identifier

## Building

```bash
# Build the UI application
make ui-app

# Or build just the executable
make TrackpadVisualizerApp
```

## Running

```bash
# Run the executable directly
./TrackpadVisualizerApp

# Or run through make
make run-ui

# Or launch the app bundle
open TrackpadVisualizer.app
```

## UI Components

1. **Top Panel - Trackpad Visualization**
   - Dark background with grid overlay
   - Blue circles for hovering fingers
   - Red circles for touching fingers
   - Finger trails show recent movement history
   - Numbers inside circles show finger IDs

2. **Bottom Panel - Live Data Log**
   - Timestamp for each event
   - Finger count and positions
   - Coordinates in normalized format (0.0-1.0)
   - Size values indicate pressure
   - Auto-scrolls to show latest events

3. **Info Label**
   - Shows current finger count
   - Lists each finger's position, size, and state
   - States: Start, Hover, Make, Touch, Break, Linger, Out

## API Access

The UI maintains full access to the MultitouchSupport API through:
- `MTDeviceRef` for device handle
- `MTContactCallbackFunction` for receiving touch events
- Direct access to raw `Finger` struct data

The callback function processes raw trackpad data and updates the UI asynchronously on the main thread.

## Technical Details

- Uses private `MultitouchSupport.framework` for raw trackpad access
- Coordinates are normalized (0.0-1.0) where:
  - X: 0.0 = left edge, 1.0 = right edge
  - Y: 0.0 = top edge, 1.0 = bottom edge (inverted for display)
- Pressure/size values typically range from 0.0 to 1.0
- Updates at native trackpad refresh rate (typically 60-120Hz)

## Requirements

- macOS with multitouch trackpad (MacBook or external Magic Trackpad)
- macOS 10.14 or later
- Access to private frameworks (SIP may need adjustment on newer macOS versions)