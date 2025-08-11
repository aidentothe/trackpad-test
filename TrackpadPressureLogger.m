#import "TrackpadPressureLogger.h"

@interface TrackpadPressureLogger ()
@property (nonatomic, strong) id pressureMonitor;
@property (nonatomic, strong) id mouseMonitor;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@property (nonatomic, assign) CGFloat lastPressure;
@property (nonatomic, assign) NSPoint lastLocation;
@property (nonatomic, assign) NSPoint previousLocation;
@property (nonatomic, strong) NSTimer *updateTimer;
@end

@implementation TrackpadPressureLogger

- (instancetype)init {
    self = [super init];
    if (self) {
        _dateFormatter = [[NSDateFormatter alloc] init];
        [_dateFormatter setDateFormat:@"HH:mm:ss.SSS"];
        _lastPressure = 0.0;
        _lastLocation = NSMakePoint(0, 0);
        _previousLocation = NSMakePoint(0, 0);
    }
    return self;
}

- (void)startLogging {
    NSLog(@"Starting trackpad pressure logging (passive mode)...");
    
    // Monitor pressure events passively (no interception)
    self.pressureMonitor = [NSEvent addGlobalMonitorForEventsMatchingMask:NSEventMaskPressure
                                                                 handler:^(NSEvent *event) {
        if (event.type == NSEventTypePressure) {
            self.lastPressure = event.pressure;
            self.lastLocation = [NSEvent mouseLocation];
            
            // Get stage information for Force Touch
            NSInteger stage = event.stage;
            CGFloat stageTransition = event.stageTransition;
            
            [self logPressureEvent:event stage:stage transition:stageTransition];
        }
    }];
    
    // Monitor mouse events passively for location updates
    NSEventMask mouseMask = NSEventMaskLeftMouseDown | 
                           NSEventMaskLeftMouseDragged | 
                           NSEventMaskLeftMouseUp |
                           NSEventMaskMouseMoved |
                           NSEventMaskRightMouseDown |
                           NSEventMaskRightMouseDragged |
                           NSEventMaskRightMouseUp;
    
    self.mouseMonitor = [NSEvent addGlobalMonitorForEventsMatchingMask:mouseMask
                                                              handler:^(NSEvent *event) {
        NSPoint currentLocation = [NSEvent mouseLocation];
        
        // Check if this is a click event (always log) or movement event (only log if position changed)
        BOOL isClickEvent = (event.type == NSEventTypeLeftMouseDown ||
                            event.type == NSEventTypeLeftMouseUp ||
                            event.type == NSEventTypeRightMouseDown ||
                            event.type == NSEventTypeRightMouseUp);
        
        BOOL locationChanged = (currentLocation.x != self.lastLocation.x || 
                               currentLocation.y != self.lastLocation.y);
        
        // Log if it's a click event OR if location changed for movement events
        if (isClickEvent || locationChanged) {
            self.previousLocation = self.lastLocation;
            self.lastLocation = currentLocation;
            
            // Try to get pressure from mouse events too
            @try {
                if (event.type == NSEventTypeLeftMouseDragged || 
                    event.type == NSEventTypeRightMouseDragged) {
                    CGFloat pressure = event.pressure;
                    if (pressure > 0) {
                        self.lastPressure = pressure;
                    }
                }
            } @catch (NSException *exception) {
                // Pressure might not be available
            }
            
            NSString *eventType = [self eventTypeString:event.type];
            [self logCurrentState:eventType];
        }
    }];
    
    // Setup global event tap for passive listening only
    [self setupGlobalEventTap];
    
    // Start a timer to periodically log current state if pressure is applied
    self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:0.05
                                                         target:self
                                                       selector:@selector(updatePressureLog)
                                                       userInfo:nil
                                                        repeats:YES];
}



- (NSString *)eventTypeString:(NSEventType)type {
    switch (type) {
        case NSEventTypeLeftMouseDown: return @"L-DOWN";
        case NSEventTypeLeftMouseUp: return @"L-UP";
        case NSEventTypeLeftMouseDragged: return @"L-DRAG";
        case NSEventTypeRightMouseDown: return @"R-DOWN";
        case NSEventTypeRightMouseUp: return @"R-UP";
        case NSEventTypeRightMouseDragged: return @"R-DRAG";
        case NSEventTypeMouseMoved: return @"MOVE";
        case NSEventTypePressure: return @"PRESSURE";
        default: return @"OTHER";
    }
}

- (void)setupGlobalEventTap {
    CGEventMask eventMask = ((1 << kCGEventLeftMouseDown) | 
                            (1 << kCGEventLeftMouseUp) | 
                            (1 << kCGEventLeftMouseDragged) |
                            (1 << kCGEventRightMouseDown) |
                            (1 << kCGEventRightMouseUp) |
                            (1 << kCGEventRightMouseDragged) |
                            (1 << kCGEventMouseMoved));
    
    CFMachPortRef eventTap = CGEventTapCreate(
        kCGSessionEventTap,
        kCGHeadInsertEventTap,
        kCGEventTapOptionListenOnly,  // This ensures we only listen, never intercept
        eventMask,
        eventTapCallback,
        (__bridge void *)self
    );
    
    if (eventTap) {
        CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0);
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);
        CGEventTapEnable(eventTap, true);
    } else {
        NSLog(@"Failed to create event tap. Grant accessibility permissions:");
        NSLog(@"System Preferences > Security & Privacy > Privacy > Accessibility");
    }
}

static CGEventRef eventTapCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
    TrackpadPressureLogger *logger = (__bridge TrackpadPressureLogger *)refcon;
    
    // Get location
    CGPoint location = CGEventGetLocation(event);
    NSPoint newLocation = NSMakePoint(location.x, location.y);
    
    // Only update if location has changed
    if (newLocation.x != logger.lastLocation.x || newLocation.y != logger.lastLocation.y) {
        logger.previousLocation = logger.lastLocation;
        logger.lastLocation = newLocation;
    }
    
    // Try to get pressure from CGEvent
    int64_t pressure = CGEventGetIntegerValueField(event, kCGMouseEventPressure);
    if (pressure > 0) {
        logger.lastPressure = pressure / 255.0;
    }
    
    // Also try to get tablet pressure for devices that report it
    int64_t tabletPressure = CGEventGetIntegerValueField(event, kCGTabletEventPointPressure);
    if (tabletPressure > 0) {
        logger.lastPressure = tabletPressure / 65535.0; // Tablet pressure is 0-65535
    }
    
    return event;
}

- (void)updatePressureLog {
    // Only log if there's significant pressure AND location has changed
    if (self.lastPressure > 0.01 && 
        (self.lastLocation.x != self.previousLocation.x || 
         self.lastLocation.y != self.previousLocation.y)) {
        [self logCurrentState:@"CONTINUOUS"];
        self.previousLocation = self.lastLocation;
    }
}

- (void)logPressureEvent:(NSEvent *)event stage:(NSInteger)stage transition:(CGFloat)transition {
    NSString *timestamp = [self.dateFormatter stringFromDate:[NSDate date]];
    
    NSString *logMessage = [NSString stringWithFormat:
        @"[%@] PRESSURE | Cursor: (%.1f, %.1f) | Pressure: %.3f | Stage: %ld | Transition: %.3f",
        timestamp,
        self.lastLocation.x,
        self.lastLocation.y,
        self.lastPressure,
        (long)stage,
        transition
    ];
    
    printf("%s\n", [logMessage UTF8String]);
    fflush(stdout);
}

- (void)logCurrentState:(NSString *)eventType {
    NSString *timestamp = [self.dateFormatter stringFromDate:[NSDate date]];
    
    NSString *logMessage = [NSString stringWithFormat:
        @"[%@] %@ | Cursor: (%.1f, %.1f) | Pressure: %.3f",
        timestamp,
        eventType,
        self.lastLocation.x,
        self.lastLocation.y,
        self.lastPressure
    ];
    
    printf("%s\n", [logMessage UTF8String]);
    fflush(stdout);
}

- (void)stopLogging {
    [self.updateTimer invalidate];
    self.updateTimer = nil;
    
    if (self.pressureMonitor) {
        [NSEvent removeMonitor:self.pressureMonitor];
        self.pressureMonitor = nil;
    }
    
    if (self.mouseMonitor) {
        [NSEvent removeMonitor:self.mouseMonitor];
        self.mouseMonitor = nil;
    }
    
    NSLog(@"Trackpad pressure logging stopped.");
}

- (void)dealloc {
    [self stopLogging];
}

@end