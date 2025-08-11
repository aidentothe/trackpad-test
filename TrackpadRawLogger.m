#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <math.h>
#import <unistd.h>

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
    float angle, majorAxis, minorAxis; // ellipsoid
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

// Global variables for tracking
static NSDateFormatter *dateFormatter;
static Finger previousFingers[10];
static int previousFingerCount = 0;
static BOOL hasMovement = NO;

// Callback function for multitouch events
int trackpadCallback(int device, Finger *data, int nFingers, double timestamp, int frame) {
    NSString *timeStr = [dateFormatter stringFromDate:[NSDate date]];
    
    // Check if anything has changed
    hasMovement = NO;
    
    // Check for finger count change
    if (nFingers != previousFingerCount) {
        hasMovement = YES;
    } else {
        // Check if any finger has moved significantly
        for (int i = 0; i < nFingers; i++) {
            Finger *f = &data[i];
            
            // Find corresponding previous finger by ID
            BOOL foundPrevious = NO;
            for (int j = 0; j < previousFingerCount; j++) {
                if (previousFingers[j].identifier == f->identifier) {
                    // Check if position changed
                    float dx = fabsf(f->normalized.pos.x - previousFingers[j].normalized.pos.x);
                    float dy = fabsf(f->normalized.pos.y - previousFingers[j].normalized.pos.y);
                    
                    if (dx > 0.001 || dy > 0.001 || 
                        fabsf(f->size - previousFingers[j].size) > 0.01 ||
                        f->state != previousFingers[j].state) {
                        hasMovement = YES;
                        break;
                    }
                    foundPrevious = YES;
                    break;
                }
            }
            
            if (!foundPrevious) {
                hasMovement = YES;
                break;
            }
        }
    }
    
    // Only log if there's movement or state change
    if (hasMovement) {
        printf("[%s] Fingers: %d | ", [timeStr UTF8String], nFingers);
        
        if (nFingers > 0) {
            for (int i = 0; i < nFingers; i++) {
                Finger *f = &data[i];
                
                // State names
                const char *stateStr;
                switch (f->state) {
                    case 0: stateStr = "Not"; break;
                    case 1: stateStr = "Start"; break;
                    case 2: stateStr = "Hover"; break;
                    case 3: stateStr = "Make"; break;
                    case 4: stateStr = "Touch"; break;
                    case 5: stateStr = "Break"; break;
                    case 6: stateStr = "Linger"; break;
                    case 7: stateStr = "Out"; break;
                    default: stateStr = "?"; break;
                }
                
                printf("F%d[Trackpad:(%.3f,%.3f) Size:%.2f State:%s] ",
                       f->identifier,
                       f->normalized.pos.x,
                       f->normalized.pos.y,
                       f->size,
                       stateStr);
            }
        } else {
            printf("No fingers on trackpad");
        }
        
        printf("\n");
        fflush(stdout);
        
        // Store current state for next comparison
        previousFingerCount = nFingers;
        for (int i = 0; i < nFingers && i < 10; i++) {
            previousFingers[i] = data[i];
        }
    }
    
    return 0;
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // Initialize date formatter
        dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"HH:mm:ss.SSS"];
        
        printf("=== Raw Trackpad Position Logger ===\n");
        printf("This shows actual finger positions on the trackpad surface (0.0-1.0)\n");
        printf("Press Ctrl+C to stop\n");
        printf("----------------------------------------\n");
        
        // Create and start multitouch device
        MTDeviceRef dev = MTDeviceCreateDefault();
        if (!dev) {
            printf("Error: Could not create multitouch device.\n");
            printf("This requires a MacBook with a multitouch trackpad.\n");
            return 1;
        }
        
        MTRegisterContactFrameCallback(dev, trackpadCallback);
        MTDeviceStart(dev, 0);
        
        // Run forever
        [[NSRunLoop currentRunLoop] run];
    }
    return 0;
}