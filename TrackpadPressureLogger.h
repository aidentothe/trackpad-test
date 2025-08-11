#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@interface TrackpadPressureLogger : NSObject

- (void)startLogging;
- (void)stopLogging;

@end