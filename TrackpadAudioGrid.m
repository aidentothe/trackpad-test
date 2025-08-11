#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#import <AVFoundation/AVFoundation.h>

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

// TrackpadAudioView - Custom view for visualizing trackpad with audio
@interface TrackpadAudioView : NSView
@property (nonatomic, strong) NSMutableArray *currentFingers;
@property (nonatomic, strong) NSMutableDictionary *fingerTrails;
@property (nonatomic, strong) NSColor *backgroundColor;
@property (nonatomic, strong) NSColor *fingerColor;
@property (nonatomic, strong) NSColor *touchColor;
@property (nonatomic, strong) NSTextField *titleLabel;
@property (nonatomic, strong) NSButton *spamModeCheckbox;
@property (nonatomic) NSInteger gridRows;
@property (nonatomic) NSInteger gridCols;
@property (nonatomic, strong) NSMutableArray *audioPlayers;
@property (nonatomic, strong) NSMutableArray *duplicatePlayers;
@property (nonatomic, strong) NSMutableArray *tileKeys;
@property (nonatomic, strong) NSMutableArray *tileDescriptions;
@property (nonatomic, strong) NSMutableSet *activeCells;
@property (nonatomic, strong) NSMutableDictionary *fingerToCellMap;
@property (nonatomic) BOOL spamMode;
@property (nonatomic) BOOL showInfo;
@end

@implementation TrackpadAudioView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        self.currentFingers = [NSMutableArray array];
        self.fingerTrails = [NSMutableDictionary dictionary];
        self.backgroundColor = [NSColor colorWithCalibratedWhite:0.05 alpha:1.0];
        self.fingerColor = [NSColor colorWithCalibratedRed:1.0 green:1.0 blue:1.0 alpha:0.8];
        self.touchColor = [NSColor colorWithCalibratedRed:1.0 green:0.3 blue:0.3 alpha:1.0];
        
        // Setup 4x4 grid
        self.gridRows = 4;
        self.gridCols = 4;
        self.activeCells = [NSMutableSet set];
        self.fingerToCellMap = [NSMutableDictionary dictionary];
        self.duplicatePlayers = [NSMutableArray array];
        self.spamMode = NO;
        self.showInfo = NO;
        
        // Setup tile keys and descriptions (matching the website layout)
        self.tileKeys = [@[@"A", @"S", @"D", @"F",
                          @"G", @"H", @"J", @"K",
                          @"Z", @"X", @"C", @"V",
                          @"B", @"N", @"M", @"?"] mutableCopy];
        
        self.tileDescriptions = [@[@"piano 1", @"piano 2", @"piano 3", @"piano 4",
                                  @"piano 5", @"piano 6", @"piano 7", @"piano 8",
                                  @"Beat", @"Beautiful Stars", @"Hey!", @"Instrumental Loop",
                                  @"Ladies And Gent..", @"LOOKATCHA", @"Reset Sounds", @"Info"] mutableCopy];
        
        // Initialize audio
        self.audioPlayers = [NSMutableArray array];
        [self setupAudioPlayers];
        
        // Add title label
        self.titleLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(0, frameRect.size.height - 60, frameRect.size.width, 30)];
        self.titleLabel.stringValue = @"RUNAWAY SOUNDBOARD";
        self.titleLabel.bezeled = NO;
        self.titleLabel.drawsBackground = NO;
        self.titleLabel.editable = NO;
        self.titleLabel.selectable = NO;
        self.titleLabel.textColor = [NSColor colorWithCalibratedRed:1.0 green:0.3 blue:0.3 alpha:1.0];
        self.titleLabel.font = [NSFont boldSystemFontOfSize:24];
        self.titleLabel.alignment = NSTextAlignmentCenter;
        [self addSubview:self.titleLabel];
        
        // Add spam mode checkbox
        self.spamModeCheckbox = [[NSButton alloc] initWithFrame:NSMakeRect(frameRect.size.width/2 - 80, frameRect.size.height - 90, 160, 25)];
        self.spamModeCheckbox.buttonType = NSButtonTypeSwitch;
        self.spamModeCheckbox.title = @"Spam Mode";
        self.spamModeCheckbox.state = NSControlStateValueOff;
        self.spamModeCheckbox.target = self;
        self.spamModeCheckbox.action = @selector(spamModeToggled:);
        
        // Style the checkbox
        NSMutableAttributedString *colorTitle = [[NSMutableAttributedString alloc] initWithString:@"Spam Mode"];
        [colorTitle addAttribute:NSForegroundColorAttributeName value:[NSColor whiteColor] range:NSMakeRange(0, colorTitle.length)];
        [colorTitle addAttribute:NSFontAttributeName value:[NSFont systemFontOfSize:14] range:NSMakeRange(0, colorTitle.length)];
        self.spamModeCheckbox.attributedTitle = colorTitle;
        
        [self addSubview:self.spamModeCheckbox];
    }
    return self;
}

- (void)spamModeToggled:(id)sender {
    self.spamMode = (self.spamModeCheckbox.state == NSControlStateValueOn);
}

- (void)setupAudioPlayers {
    // Get the path to the samples directory relative to the app bundle
    NSString *executablePath = [[NSBundle mainBundle] executablePath];
    NSString *appDirectory = [executablePath stringByDeletingLastPathComponent];
    
    // Go up to the project root and then into samples folder
    // When running from Xcode or command line, the executable is in the same directory as source
    NSString *samplesPath = [appDirectory stringByAppendingPathComponent:@"samples"];
    
    // If samples directory doesn't exist at executable level, try current directory
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:samplesPath]) {
        // Try relative to current working directory
        samplesPath = [[fileManager currentDirectoryPath] stringByAppendingPathComponent:@"samples"];
    }
    
    // Add trailing slash for compatibility with existing code
    samplesPath = [samplesPath stringByAppendingString:@"/"];
    
    NSLog(@"Loading samples from: %@", samplesPath);
    
    // Audio files in the exact order matching the grid
    NSArray *audioFiles = @[
        @"piano1.mp3",
        @"piano2.mp3",
        @"piano3.mp3",
        @"piano4.mp3",
        @"piano5.mp3",
        @"piano6.mp3",
        @"piano7.mp3",
        @"piano8.mp3",
        @"Beat.mp3",
        @"BeautifulStars.mp3",
        @"Hey!.mp3",
        @"Instrumental-loop.c.mp3",
        @"LadiesNGentlemen.mp3",
        @"LookAtCha.mp3",
        @"", // M = Reset Sounds (no audio file)
        @""  // ? = Info (no audio file)
    ];
    
    // Create audio players for each cell
    for (int i = 0; i < 16; i++) {
        if (i < 14 && [(NSString *)audioFiles[i] length] > 0) {
            NSString *fileName = audioFiles[i];
            NSString *filePath = [samplesPath stringByAppendingString:fileName];
            NSURL *fileURL = [NSURL fileURLWithPath:filePath];
            
            NSError *error = nil;
            AVAudioPlayer *player = [[AVAudioPlayer alloc] initWithContentsOfURL:fileURL error:&error];
            
            if (player && !error) {
                [player prepareToPlay];
                player.volume = 0.8;
                
                // Set loop for Instrumental-loop.c.mp3 (index 11, key V)
                if (i == 11) {
                    player.numberOfLoops = -1;
                }
                
                [self.audioPlayers addObject:player];
            } else {
                NSLog(@"Error loading audio file %@: %@", fileName, error);
                [self.audioPlayers addObject:[NSNull null]];
            }
        } else {
            [self.audioPlayers addObject:[NSNull null]];
        }
    }
}

- (void)playSoundForCell:(NSInteger)cellIndex {
    // Handle special cells
    if (cellIndex == 14) { // M = Reset Sounds
        [self resetAllSounds];
        return;
    } else if (cellIndex == 15) { // ? = Info
        self.showInfo = !self.showInfo;
        [self setNeedsDisplay:YES];
        return;
    }
    
    if (cellIndex >= 0 && cellIndex < self.audioPlayers.count) {
        AVAudioPlayer *player = self.audioPlayers[cellIndex];
        if (player && ![player isKindOfClass:[NSNull class]]) {
            if (self.spamMode) {
                // In spam mode, create duplicate players for overlapping sounds
                NSError *error = nil;
                AVAudioPlayer *duplicate = [[AVAudioPlayer alloc] initWithContentsOfURL:player.url error:&error];
                if (duplicate && !error) {
                    duplicate.volume = player.volume;
                    duplicate.numberOfLoops = player.numberOfLoops;
                    [duplicate play];
                    [self.duplicatePlayers addObject:duplicate];
                }
            } else {
                // Normal mode - stop and restart
                [player stop];
                player.currentTime = 0;
                [player play];
            }
        }
    }
}

- (void)resetAllSounds {
    // Stop all main players
    for (AVAudioPlayer *player in self.audioPlayers) {
        if (player && ![player isKindOfClass:[NSNull class]]) {
            [player stop];
            player.currentTime = 0;
        }
    }
    
    // Stop all duplicate players (spam mode)
    for (AVAudioPlayer *player in self.duplicatePlayers) {
        [player stop];
    }
    [self.duplicatePlayers removeAllObjects];
}

- (void)updateWithFingers:(NSArray *)fingers {
    NSMutableSet *previousCells = [self.activeCells mutableCopy];
    NSMutableSet *currentCells = [NSMutableSet set];
    
    self.currentFingers = [fingers mutableCopy];
    
    // Update trails and track active cells
    NSMutableSet *currentIds = [NSMutableSet set];
    NSMutableDictionary *newFingerToCellMap = [NSMutableDictionary dictionary];
    
    for (NSValue *fingerValue in fingers) {
        Finger finger;
        [fingerValue getValue:&finger];
        
        NSNumber *fingerId = @(finger.identifier);
        [currentIds addObject:fingerId];
        
        // Calculate which cell this finger is in
        NSInteger col = (NSInteger)(finger.normalized.pos.x * self.gridCols);
        NSInteger row = (NSInteger)(finger.normalized.pos.y * self.gridRows);
        col = MIN(MAX(col, 0), self.gridCols - 1);
        row = MIN(MAX(row, 0), self.gridRows - 1);
        NSInteger cellIndex = row * self.gridCols + col;
        
        // Track finger press transitions
        NSNumber *previousCell = self.fingerToCellMap[fingerId];
        
        // State 3 = Make (initial press), State 4 = Touch (held down)
        if (finger.state == 3) { // Only on initial press
            // If this is a new press or the finger moved to a different cell
            if (!previousCell || [previousCell integerValue] != cellIndex) {
                [self playSoundForCell:cellIndex];
                [currentCells addObject:@(cellIndex)];
            }
            newFingerToCellMap[fingerId] = @(cellIndex);
        } else if (finger.state == 4) { // Held down
            if (previousCell) {
                [currentCells addObject:previousCell];
                newFingerToCellMap[fingerId] = previousCell;
            }
        }
        
        // Add to trail
        NSMutableArray *trail = self.fingerTrails[fingerId];
        if (!trail) {
            trail = [NSMutableArray array];
            self.fingerTrails[fingerId] = trail;
        }
        
        NSPoint point = NSMakePoint(finger.normalized.pos.x, finger.normalized.pos.y);
        [trail addObject:[NSValue valueWithPoint:point]];
        
        // Limit trail length
        if (trail.count > 30) {
            [trail removeObjectAtIndex:0];
        }
    }
    
    // Update the finger-to-cell mapping
    self.fingerToCellMap = newFingerToCellMap;
    self.activeCells = currentCells;
    
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
    
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    // Draw background
    [self.backgroundColor setFill];
    NSRectFill(self.bounds);
    
    // Calculate grid dimensions (leave space for title and checkbox)
    NSRect gridArea = NSMakeRect(20, 20, self.bounds.size.width - 40, self.bounds.size.height - 120);
    CGFloat cellWidth = gridArea.size.width / self.gridCols;
    CGFloat cellHeight = gridArea.size.height / self.gridRows;
    CGFloat cellPadding = 8.0;
    
    // Draw info overlay if active
    if (self.showInfo) {
        // Blur effect
        [[NSColor colorWithCalibratedWhite:0.0 alpha:0.7] setFill];
        NSRectFill(self.bounds);
        
        // Info content
        NSMutableParagraphStyle *centerStyle = [[NSMutableParagraphStyle alloc] init];
        centerStyle.alignment = NSTextAlignmentCenter;
        
        NSDictionary *infoAttrs = @{
            NSFontAttributeName: [NSFont systemFontOfSize:16],
            NSForegroundColorAttributeName: [NSColor whiteColor],
            NSParagraphStyleAttributeName: centerStyle
        };
        
        NSString *infoText = @"RUNAWAY SOUNDBOARD\n\nTrackpad version\n\nPress firmly on cells to play sounds\n\nPress M to reset all sounds\nPress ? to toggle this info\n\nEnable Spam Mode for overlapping sounds";
        NSSize textSize = [infoText sizeWithAttributes:infoAttrs];
        NSRect textRect = NSMakeRect((self.bounds.size.width - textSize.width) / 2,
                                     (self.bounds.size.height - textSize.height) / 2,
                                     textSize.width,
                                     textSize.height);
        [infoText drawInRect:textRect withAttributes:infoAttrs];
        
        return;
    }
    
    // Draw 4x4 grid cells
    for (int row = 0; row < self.gridRows; row++) {
        for (int col = 0; col < self.gridCols; col++) {
            NSInteger cellIndex = row * self.gridCols + col;
            NSRect cellRect = NSMakeRect(
                gridArea.origin.x + col * cellWidth + cellPadding,
                gridArea.origin.y + row * cellHeight + cellPadding,
                cellWidth - 2 * cellPadding,
                cellHeight - 2 * cellPadding
            );
            
            // Check if this cell is active
            BOOL isActive = [self.activeCells containsObject:@(cellIndex)];
            
            // Fill cell background
            if (isActive) {
                [[NSColor colorWithCalibratedWhite:0.4 alpha:1.0] setFill];
            } else {
                [[NSColor colorWithCalibratedWhite:0.2 alpha:1.0] setFill];
            }
            NSBezierPath *cellPath = [NSBezierPath bezierPathWithRoundedRect:cellRect xRadius:8 yRadius:8];
            [cellPath fill];
            
            // Draw cell border
            if (isActive) {
                [[NSColor colorWithCalibratedWhite:0.8 alpha:1.0] setStroke];
                [cellPath setLineWidth:2.0];
            } else {
                [[NSColor colorWithCalibratedWhite:0.3 alpha:1.0] setStroke];
                [cellPath setLineWidth:1.0];
            }
            [cellPath stroke];
            
            // Draw key letter (large and centered)
            NSString *keyLetter = self.tileKeys[cellIndex];
            NSDictionary *keyAttrs = @{
                NSFontAttributeName: [NSFont boldSystemFontOfSize:48],
                NSForegroundColorAttributeName: [NSColor whiteColor]
            };
            NSSize keySize = [keyLetter sizeWithAttributes:keyAttrs];
            NSPoint keyPoint = NSMakePoint(
                cellRect.origin.x + (cellRect.size.width - keySize.width) / 2,
                cellRect.origin.y + (cellRect.size.height - keySize.height) / 2 + 10
            );
            [keyLetter drawAtPoint:keyPoint withAttributes:keyAttrs];
            
            // Draw description (below key)
            NSString *description = self.tileDescriptions[cellIndex];
            NSDictionary *descAttrs = @{
                NSFontAttributeName: [NSFont systemFontOfSize:12],
                NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:0.7 alpha:1.0]
            };
            NSSize descSize = [description sizeWithAttributes:descAttrs];
            NSPoint descPoint = NSMakePoint(
                cellRect.origin.x + (cellRect.size.width - descSize.width) / 2,
                cellRect.origin.y + 10
            );
            [description drawAtPoint:descPoint withAttributes:descAttrs];
        }
    }
    
    // Draw trails
    for (NSNumber *fingerId in self.fingerTrails) {
        NSMutableArray *trail = self.fingerTrails[fingerId];
        if (trail.count > 1) {
            NSBezierPath *trailPath = [NSBezierPath bezierPath];
            
            for (NSInteger i = 0; i < trail.count; i++) {
                NSPoint point = [trail[i] pointValue];
                
                NSPoint screenPoint = NSMakePoint(
                    gridArea.origin.x + point.x * gridArea.size.width,
                    gridArea.origin.y + point.y * gridArea.size.height
                );
                
                if (i == 0) {
                    [trailPath moveToPoint:screenPoint];
                } else {
                    [trailPath lineToPoint:screenPoint];
                }
            }
            
            CGFloat alpha = 0.5;
            [[self.fingerColor colorWithAlphaComponent:alpha] setStroke];
            [trailPath setLineWidth:2.0];
            [trailPath stroke];
        }
    }
    
    // Draw fingers
    for (NSValue *fingerValue in self.currentFingers) {
        Finger finger;
        [fingerValue getValue:&finger];
        
        NSPoint screenPoint = NSMakePoint(
            gridArea.origin.x + finger.normalized.pos.x * gridArea.size.width,
            gridArea.origin.y + finger.normalized.pos.y * gridArea.size.height
        );
        
        // Choose color based on state
        NSColor *color;
        if (finger.state == 3 || finger.state == 4) {
            color = self.touchColor;
        } else {
            color = self.fingerColor;
        }
        
        // Draw finger circle
        CGFloat radius = 8 + finger.size * 15;
        NSRect fingerRect = NSMakeRect(screenPoint.x - radius, screenPoint.y - radius, radius * 2, radius * 2);
        
        [color setFill];
        [[color colorWithAlphaComponent:0.3] setStroke];
        NSBezierPath *fingerPath = [NSBezierPath bezierPathWithOvalInRect:fingerRect];
        [fingerPath fill];
        [fingerPath setLineWidth:2.0];
        [fingerPath stroke];
    }
}

@end

// Application delegate
@interface AppDelegate : NSObject <NSApplicationDelegate>
@property (strong) NSWindow *window;
@property (strong) TrackpadAudioView *trackpadView;
@property MTDeviceRef device;
@end

// Global reference for callback
static AppDelegate *globalAppDelegate = nil;

// Callback function
int audioVisualizerCallback(int device, Finger *data, int nFingers, double timestamp, int frame) {
    if (!globalAppDelegate) return 0;
    
    NSMutableArray *fingers = [NSMutableArray array];
    for (int i = 0; i < nFingers; i++) {
        NSValue *fingerValue = [NSValue value:&data[i] withObjCType:@encode(Finger)];
        [fingers addObject:fingerValue];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [globalAppDelegate.trackpadView updateWithFingers:fingers];
    });
    
    return 0;
}

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    globalAppDelegate = self;
    
    // Create window
    NSRect frame = NSMakeRect(100, 100, 800, 700);
    self.window = [[NSWindow alloc] initWithContentRect:frame
                                               styleMask:(NSWindowStyleMaskTitled |
                                                         NSWindowStyleMaskClosable |
                                                         NSWindowStyleMaskMiniaturizable |
                                                         NSWindowStyleMaskResizable)
                                                 backing:NSBackingStoreBuffered
                                                   defer:NO];
    
    [self.window setTitle:@"Runaway Soundboard - Trackpad Edition"];
    [self.window makeKeyAndOrderFront:nil];
    
    // Set dark appearance
    self.window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameVibrantDark];
    
    // Create trackpad view
    self.trackpadView = [[TrackpadAudioView alloc] initWithFrame:[[self.window contentView] bounds]];
    self.trackpadView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [[self.window contentView] addSubview:self.trackpadView];
    
    // Start multitouch monitoring
    self.device = MTDeviceCreateDefault();
    if (self.device) {
        MTRegisterContactFrameCallback(self.device, audioVisualizerCallback);
        MTDeviceStart(self.device, 0);
    } else {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Error";
        alert.informativeText = @"Could not access trackpad. This requires a MacBook with multitouch trackpad.";
        [alert runModal];
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