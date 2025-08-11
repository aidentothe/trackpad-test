#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>

// MultitouchSupport structures
typedef struct { float x, y; } MTPoint;
typedef struct { MTPoint pos, vel; } MTVector;

typedef struct {
    int frame;
    double timestamp;
    int identifier, state, foo3, foo4;
    MTVector normalized;
    float size;
    int zero1;
    float angle, majorAxis, minorAxis;
    MTVector mm;
    int zero2[2];
    float unk2;
} Finger;

// MultitouchSupport function declarations
typedef void *MTDeviceRef;
typedef int (*MTContactCallbackFunction)(int, Finger*, int, double, int);

extern MTDeviceRef MTDeviceCreateDefault();
extern void MTRegisterContactFrameCallback(MTDeviceRef, MTContactCallbackFunction);
extern void MTDeviceStart(MTDeviceRef, int);

// TrackpadView - Custom view for visualizing trackpad
@interface TrackpadView : NSView
@property (nonatomic, strong) NSMutableArray *currentFingers;
@property (nonatomic, strong) NSMutableDictionary *fingerTrails;
@property (nonatomic, strong) NSColor *backgroundColor;
@property (nonatomic, strong) NSColor *fingerColor;
@property (nonatomic, strong) NSColor *touchColor;
@property (nonatomic, strong) NSTextField *infoLabel;
@property (nonatomic, strong) NSMutableArray *gridViews;  // Array of 16 grid cells
@property (nonatomic) NSInteger gridRows;
@property (nonatomic) NSInteger gridCols;
@end

@implementation TrackpadView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        self.currentFingers = [NSMutableArray array];
        self.fingerTrails = [NSMutableDictionary dictionary];
        self.backgroundColor = [NSColor colorWithCalibratedWhite:0.1 alpha:1.0];
        self.fingerColor = [NSColor colorWithCalibratedRed:0.3 green:0.6 blue:1.0 alpha:0.8];
        self.touchColor = [NSColor colorWithCalibratedRed:1.0 green:0.4 blue:0.4 alpha:0.9];
        
        // Setup 4x4 grid
        self.gridRows = 4;
        self.gridCols = 4;
        self.gridViews = [NSMutableArray array];
        
        // Add info label
        self.infoLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 10, 300, 60)];
        self.infoLabel.stringValue = @"Waiting for touch...";
        self.infoLabel.bezeled = NO;
        self.infoLabel.drawsBackground = NO;
        self.infoLabel.editable = NO;
        self.infoLabel.selectable = NO;
        self.infoLabel.textColor = [NSColor whiteColor];
        self.infoLabel.font = [NSFont monospacedDigitSystemFontOfSize:11 weight:NSFontWeightRegular];
        [self addSubview:self.infoLabel];
    }
    return self;
}

- (void)updateWithFingers:(NSArray *)fingers {
    self.currentFingers = [fingers mutableCopy];
    
    // Update trails
    NSMutableSet *currentIds = [NSMutableSet set];
    for (NSValue *fingerValue in fingers) {
        Finger finger;
        [fingerValue getValue:&finger];
        
        NSNumber *fingerId = @(finger.identifier);
        [currentIds addObject:fingerId];
        
        // Add to trail
        NSMutableArray *trail = self.fingerTrails[fingerId];
        if (!trail) {
            trail = [NSMutableArray array];
            self.fingerTrails[fingerId] = trail;
        }
        
        NSPoint point = NSMakePoint(finger.normalized.pos.x, finger.normalized.pos.y);
        [trail addObject:[NSValue valueWithPoint:point]];
        
        // Limit trail length
        if (trail.count > 50) {
            [trail removeObjectAtIndex:0];
        }
    }
    
    // Remove old trails
    NSMutableArray *keysToRemove = [NSMutableArray array];
    for (NSNumber *fingerId in self.fingerTrails) {
        if (![currentIds containsObject:fingerId]) {
            NSMutableArray *trail = self.fingerTrails[fingerId];
            if (trail.count > 0) {
                [trail removeObjectAtIndex:0];
                if (trail.count == 0) {
                    [keysToRemove addObject:fingerId];
                }
            }
        }
    }
    [self.fingerTrails removeObjectsForKeys:keysToRemove];
    
    // Update info
    [self updateInfoLabel];
    
    [self setNeedsDisplay:YES];
}

- (void)updateInfoLabel {
    if (self.currentFingers.count == 0) {
        self.infoLabel.stringValue = @"No fingers detected";
    } else {
        NSMutableString *info = [NSMutableString string];
        [info appendFormat:@"Fingers: %lu\n", self.currentFingers.count];
        
        for (NSValue *fingerValue in self.currentFingers) {
            Finger finger;
            [fingerValue getValue:&finger];
            
            const char *stateStr;
            switch (finger.state) {
                case 1: stateStr = "Start"; break;
                case 2: stateStr = "Hover"; break;
                case 3: stateStr = "Make"; break;
                case 4: stateStr = "Touch"; break;
                case 5: stateStr = "Break"; break;
                case 6: stateStr = "Linger"; break;
                case 7: stateStr = "Out"; break;
                default: stateStr = "Unknown"; break;
            }
            
            [info appendFormat:@"F%d: (%.2f, %.2f) Size:%.2f %s\n",
                finger.identifier,
                finger.normalized.pos.x,
                finger.normalized.pos.y,
                finger.size,
                stateStr];
        }
        
        self.infoLabel.stringValue = info;
    }
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    // Draw background
    [self.backgroundColor setFill];
    NSRectFill(self.bounds);
    
    // Calculate grid dimensions
    NSRect gridArea = NSInsetRect(self.bounds, 20, 20);
    CGFloat cellWidth = gridArea.size.width / self.gridCols;
    CGFloat cellHeight = gridArea.size.height / self.gridRows;
    CGFloat cellPadding = 5.0;
    
    // Draw 4x4 grid cells
    for (int row = 0; row < self.gridRows; row++) {
        for (int col = 0; col < self.gridCols; col++) {
            NSRect cellRect = NSMakeRect(
                gridArea.origin.x + col * cellWidth + cellPadding,
                gridArea.origin.y + row * cellHeight + cellPadding,
                cellWidth - 2 * cellPadding,
                cellHeight - 2 * cellPadding
            );
            
            // Fill cell background
            [[NSColor colorWithCalibratedWhite:0.15 alpha:1.0] setFill];
            NSBezierPath *cellPath = [NSBezierPath bezierPathWithRoundedRect:cellRect xRadius:5 yRadius:5];
            [cellPath fill];
            
            // Draw cell border
            [[NSColor colorWithCalibratedWhite:0.3 alpha:1.0] setStroke];
            [cellPath setLineWidth:1.5];
            [cellPath stroke];
            
            // Draw mini grid lines inside each cell (3x3)
            [[NSColor colorWithCalibratedWhite:0.2 alpha:0.5] setStroke];
            for (int i = 1; i < 3; i++) {
                NSBezierPath *gridLine = [NSBezierPath bezierPath];
                CGFloat x = cellRect.origin.x + (cellRect.size.width * i / 3.0);
                [gridLine moveToPoint:NSMakePoint(x, cellRect.origin.y)];
                [gridLine lineToPoint:NSMakePoint(x, cellRect.origin.y + cellRect.size.height)];
                [gridLine setLineWidth:0.5];
                [gridLine stroke];
                
                CGFloat y = cellRect.origin.y + (cellRect.size.height * i / 3.0);
                gridLine = [NSBezierPath bezierPath];
                [gridLine moveToPoint:NSMakePoint(cellRect.origin.x, y)];
                [gridLine lineToPoint:NSMakePoint(cellRect.origin.x + cellRect.size.width, y)];
                [gridLine setLineWidth:0.5];
                [gridLine stroke];
            }
        }
    }
    
    // Draw trails across all cells
    for (NSNumber *fingerId in self.fingerTrails) {
        NSMutableArray *trail = self.fingerTrails[fingerId];
        if (trail.count > 1) {
            NSBezierPath *trailPath = [NSBezierPath bezierPath];
            
            for (NSInteger i = 0; i < trail.count; i++) {
                NSPoint point = [trail[i] pointValue];
                
                // Map normalized coordinates to grid position
                NSInteger col = (NSInteger)(point.x * self.gridCols);
                NSInteger row = (NSInteger)(point.y * self.gridRows);
                
                // Clamp to grid bounds
                col = MIN(MAX(col, 0), self.gridCols - 1);
                row = MIN(MAX(row, 0), self.gridRows - 1);
                
                // Calculate cell rect
                NSRect cellRect = NSMakeRect(
                    gridArea.origin.x + col * cellWidth + cellPadding,
                    gridArea.origin.y + row * cellHeight + cellPadding,
                    cellWidth - 2 * cellPadding,
                    cellHeight - 2 * cellPadding
                );
                
                // Map to position within cell
                CGFloat cellX = (point.x * self.gridCols) - col;
                CGFloat cellY = (point.y * self.gridRows) - row;
                
                NSPoint screenPoint = NSMakePoint(
                    cellRect.origin.x + cellX * cellRect.size.width,
                    cellRect.origin.y + cellY * cellRect.size.height
                );
                
                if (i == 0) {
                    [trailPath moveToPoint:screenPoint];
                } else {
                    [trailPath lineToPoint:screenPoint];
                }
            }
            
            CGFloat alpha = 0.3;
            [[self.fingerColor colorWithAlphaComponent:alpha] setStroke];
            [trailPath setLineWidth:2.0];
            [trailPath stroke];
        }
    }
    
    // Draw fingers in their respective grid cells
    for (NSValue *fingerValue in self.currentFingers) {
        Finger finger;
        [fingerValue getValue:&finger];
        
        // Determine which grid cell the finger is in
        NSInteger col = (NSInteger)(finger.normalized.pos.x * self.gridCols);
        NSInteger row = (NSInteger)(finger.normalized.pos.y * self.gridRows);
        
        // Clamp to grid bounds
        col = MIN(MAX(col, 0), self.gridCols - 1);
        row = MIN(MAX(row, 0), self.gridRows - 1);
        
        // Calculate cell rect
        NSRect cellRect = NSMakeRect(
            gridArea.origin.x + col * cellWidth + cellPadding,
            gridArea.origin.y + row * cellHeight + cellPadding,
            cellWidth - 2 * cellPadding,
            cellHeight - 2 * cellPadding
        );
        
        // Highlight active cell
        [[self.fingerColor colorWithAlphaComponent:0.2] setFill];
        NSBezierPath *highlightPath = [NSBezierPath bezierPathWithRoundedRect:cellRect xRadius:5 yRadius:5];
        [highlightPath fill];
        
        // Map finger position within the cell
        CGFloat cellX = (finger.normalized.pos.x * self.gridCols) - col;
        CGFloat cellY = (finger.normalized.pos.y * self.gridRows) - row;
        
        NSPoint screenPoint = NSMakePoint(
            cellRect.origin.x + cellX * cellRect.size.width,
            cellRect.origin.y + cellY * cellRect.size.height
        );
        
        // Choose color based on state
        NSColor *color;
        if (finger.state == 4) { // Touch state
            color = self.touchColor;
        } else {
            color = self.fingerColor;
        }
        
        // Draw finger circle
        CGFloat radius = 8 + finger.size * 20; // Scale based on pressure
        NSRect fingerRect = NSMakeRect(screenPoint.x - radius, screenPoint.y - radius, radius * 2, radius * 2);
        
        // Draw shadow
        [[NSColor blackColor] setFill];
        NSBezierPath *shadow = [NSBezierPath bezierPathWithOvalInRect:NSOffsetRect(fingerRect, 2, -2)];
        [shadow fill];
        
        // Draw finger
        [color setFill];
        [[color colorWithAlphaComponent:0.3] setStroke];
        NSBezierPath *fingerPath = [NSBezierPath bezierPathWithOvalInRect:fingerRect];
        [fingerPath fill];
        [fingerPath setLineWidth:2.0];
        [fingerPath stroke];
        
        // Draw finger ID and grid position
        NSString *fingerId = [NSString stringWithFormat:@"%d\n[%ld,%ld]", finger.identifier, (long)col, (long)row];
        NSDictionary *attrs = @{
            NSFontAttributeName: [NSFont boldSystemFontOfSize:10],
            NSForegroundColorAttributeName: [NSColor whiteColor]
        };
        NSSize textSize = [fingerId sizeWithAttributes:attrs];
        NSPoint textPoint = NSMakePoint(screenPoint.x - textSize.width/2, screenPoint.y - textSize.height/2);
        [fingerId drawAtPoint:textPoint withAttributes:attrs];
    }
}

@end

// Application delegate
@interface AppDelegate : NSObject <NSApplicationDelegate>
@property (strong) NSWindow *window;
@property (strong) TrackpadView *trackpadView;
@property (strong) NSTextView *logTextView;
@property (strong) NSScrollView *scrollView;
@property MTDeviceRef device;
@end

// Global reference for callback
static AppDelegate *globalAppDelegate = nil;

// Callback function
int visualizerCallback(int device, Finger *data, int nFingers, double timestamp, int frame) {
    if (!globalAppDelegate) return 0;
    
    NSMutableArray *fingers = [NSMutableArray array];
    for (int i = 0; i < nFingers; i++) {
        NSValue *fingerValue = [NSValue value:&data[i] withObjCType:@encode(Finger)];
        [fingers addObject:fingerValue];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [globalAppDelegate.trackpadView updateWithFingers:fingers];
        
        // Log to text view
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"HH:mm:ss.SSS"];
        NSString *timeStr = [formatter stringFromDate:[NSDate date]];
        
        NSMutableString *logEntry = [NSMutableString stringWithFormat:@"[%@] ", timeStr];
        
        if (nFingers == 0) {
            [logEntry appendString:@"No fingers\n"];
        } else {
            [logEntry appendFormat:@"Fingers: %d | ", nFingers];
            for (int i = 0; i < nFingers; i++) {
                Finger *f = &data[i];
                [logEntry appendFormat:@"F%d(%.3f,%.3f,%.2f) ",
                    f->identifier,
                    f->normalized.pos.x,
                    f->normalized.pos.y,
                    f->size];
            }
            [logEntry appendString:@"\n"];
        }
        
        NSAttributedString *attrStr = [[NSAttributedString alloc] initWithString:logEntry
            attributes:@{NSForegroundColorAttributeName: [NSColor labelColor]}];
        
        [[globalAppDelegate.logTextView textStorage] appendAttributedString:attrStr];
        
        // Auto-scroll to bottom
        [globalAppDelegate.logTextView scrollRangeToVisible:NSMakeRange(globalAppDelegate.logTextView.string.length, 0)];
    });
    
    return 0;
}

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    globalAppDelegate = self;
    
    // Create window
    NSRect frame = NSMakeRect(100, 100, 800, 600);
    self.window = [[NSWindow alloc] initWithContentRect:frame
                                               styleMask:(NSWindowStyleMaskTitled |
                                                         NSWindowStyleMaskClosable |
                                                         NSWindowStyleMaskMiniaturizable |
                                                         NSWindowStyleMaskResizable)
                                                 backing:NSBackingStoreBuffered
                                                   defer:NO];
    
    [self.window setTitle:@"Trackpad Visualizer"];
    [self.window makeKeyAndOrderFront:nil];
    
    // Create split view
    NSSplitView *splitView = [[NSSplitView alloc] initWithFrame:[[self.window contentView] bounds]];
    splitView.vertical = NO;
    splitView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    
    // Create trackpad view
    self.trackpadView = [[TrackpadView alloc] initWithFrame:NSMakeRect(0, 0, 800, 400)];
    [splitView addSubview:self.trackpadView];
    
    // Create log view
    self.scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 800, 200)];
    self.scrollView.hasVerticalScroller = YES;
    self.scrollView.hasHorizontalScroller = NO;
    self.scrollView.autohidesScrollers = NO;
    
    self.logTextView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 800, 200)];
    self.logTextView.editable = NO;
    self.logTextView.richText = YES;
    self.logTextView.font = [NSFont monospacedDigitSystemFontOfSize:10 weight:NSFontWeightRegular];
    self.logTextView.backgroundColor = [NSColor textBackgroundColor];
    self.logTextView.textColor = [NSColor labelColor];
    
    self.scrollView.documentView = self.logTextView;
    [splitView addSubview:self.scrollView];
    
    [[self.window contentView] addSubview:splitView];
    
    // Start multitouch monitoring
    self.device = MTDeviceCreateDefault();
    if (self.device) {
        MTRegisterContactFrameCallback(self.device, visualizerCallback);
        MTDeviceStart(self.device, 0);
        
        NSAttributedString *startMsg = [[NSAttributedString alloc] initWithString:@"=== Trackpad Visualizer Started ===\n"
            attributes:@{NSForegroundColorAttributeName: [NSColor systemGreenColor]}];
        [[self.logTextView textStorage] appendAttributedString:startMsg];
    } else {
        NSAttributedString *errorMsg = [[NSAttributedString alloc] initWithString:@"Error: Could not access trackpad. This requires a MacBook with multitouch trackpad.\n"
            attributes:@{NSForegroundColorAttributeName: [NSColor systemRedColor]}];
        [[self.logTextView textStorage] appendAttributedString:errorMsg];
    }
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    globalAppDelegate = nil;
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

@end

// Main function
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        AppDelegate *delegate = [[AppDelegate alloc] init];
        [app setDelegate:delegate];
        [app run];
    }
    return 0;
}