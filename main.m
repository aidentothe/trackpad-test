#import <Cocoa/Cocoa.h>
#import "TrackpadPressureLogger.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // Create the application
        NSApplication *app = [NSApplication sharedApplication];
        
        // Create and initialize the trackpad logger
        TrackpadPressureLogger *logger = [[TrackpadPressureLogger alloc] init];
        [logger startLogging];
        
        NSLog(@"Trackpad Pressure Logger started. Press Ctrl+C to stop.");
        NSLog(@"Note: This requires a Force Touch trackpad (MacBook 2015 or later)");
        NSLog(@"Move your finger on the trackpad to see location and pressure data.");
        
        // Run the application
        [app run];
    }
    return 0;
}