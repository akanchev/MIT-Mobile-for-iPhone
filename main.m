#import <UIKit/UIKit.h>
#import "MITLogging.h"
#import "MITLogFormatter.h"
#import "MITTestFlightLogger.h"

void mit_logger_init( void );
int main(int argc, char *argv[]) {
    @autoreleasepool {
        mit_logger_init();
        return UIApplicationMain(argc, argv, @"UIApplication", @"MIT_MobileAppDelegate");
    }
}

void mit_logger_init( void )
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        {
            DDASLLogger *logger = [DDASLLogger sharedInstance];
            logger.logFormatter = [[MITLogFormatter alloc] init];
            [DDLog addLogger:logger];
        }
        
#if defined(DEBUG)
        {
            DDTTYLogger *logger = [DDTTYLogger sharedInstance];
            logger.logFormatter = [[MITLogFormatter alloc] init];
            [DDLog addLogger:logger];
        }
#endif //DEBUG
        
#if defined(TESTFLIGHT)
        {
            MITTestFlightLogger *logger = [MITTestFlightLogger sharedInstance];
            logger.logFormatter = [[MITLogFormatter alloc] init];
            [DDLog addLogger:logger];
        }
#endif //TESTFLIGHT
        
        DDLogCVerbose(@"Lumberjack logging initialized");
    });
}