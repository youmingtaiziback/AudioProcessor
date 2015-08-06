/*
    File: MixerEQGraphTestDelegate.m  
Abstract: The application delegate class.  
 Version: 1.2.2  
  
*/

#import "MixerEQGraphTestDelegate.h"

@implementation MixerEQGraphTestDelegate

@synthesize window, navigationController, myViewController;

#pragma mark - Audio Session Interruption Notification

- (void)handleInterruption:(NSNotification *)notification
{
    UInt8 theInterruptionType = [[notification.userInfo valueForKey:AVAudioSessionInterruptionTypeKey] intValue];
    
    if (theInterruptionType == AVAudioSessionInterruptionTypeBegan) {
        [self->myViewController stopForInterruption];
    }
    
    if (theInterruptionType == AVAudioSessionInterruptionTypeEnded) {
        // make sure to activate the session
        NSError *error = nil;
        [[AVAudioSession sharedInstance] setActive:YES error:&error];
    
        if (nil != error) NSLog(@"AVAudioSession set active failed with error: %d", error.code);
    }
}

#pragma mark - Audio Session Route Change Notification

- (void)handleRouteChange:(NSNotification *)notification
{
    UInt8 reasonValue = [[notification.userInfo valueForKey:AVAudioSessionRouteChangeReasonKey] intValue];
    AVAudioSessionRouteDescription *routeDescription = [notification.userInfo valueForKey:AVAudioSessionRouteChangePreviousRouteKey];
    
    NSLog(@"Route change:");
    switch (reasonValue) {
    case AVAudioSessionRouteChangeReasonNewDeviceAvailable:
        NSLog(@"     NewDeviceAvailable");
        break;
    case AVAudioSessionRouteChangeReasonOldDeviceUnavailable:
        NSLog(@"     OldDeviceUnavailable");
        break;
    case AVAudioSessionRouteChangeReasonCategoryChange:
        NSLog(@"     CategoryChange");
        NSLog(@" New Category: %@", [[AVAudioSession sharedInstance] category]);
        break;
    case AVAudioSessionRouteChangeReasonOverride:
        NSLog(@"     Override");
        break;
    case AVAudioSessionRouteChangeReasonWakeFromSleep:
        NSLog(@"     WakeFromSleep");
        break;
    case AVAudioSessionRouteChangeReasonNoSuitableRouteForCategory:
        NSLog(@"     NoSuitableRouteForCategory");
        break;
    default:
        NSLog(@"     ReasonUnknown");
    }
}

- (void)applicationDidFinishLaunching:(UIApplication *)application {
//    NSLog(@"**** %c", (0x61756d78 % 2 << 24) >> 16);
    // Override point for customization after application launch
    self.window.rootViewController = navigationController;
    [window makeKeyAndVisible];
    
    try {
        NSError *error = nil;
        
        // Configure the audio session
        AVAudioSession *sessionInstance = [AVAudioSession sharedInstance];
        // our default category -- we change this for conversion and playback appropriately
        [sessionInstance setCategory:AVAudioSessionCategoryPlayback error:&error];
//        XThrowIfError(error.code, "couldn't set audio category");
        NSTimeInterval bufferDuration = .005;
        [sessionInstance setPreferredIOBufferDuration:bufferDuration error:&error];
//        XThrowIfError(error.code, "couldn't set IOBufferDuration");
        double hwSampleRate = 44100.0;
        [sessionInstance setPreferredSampleRate:hwSampleRate error:&error];
//        XThrowIfError(error.code, "couldn't set preferred sample rate");
        // add interruption handler
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleInterruption:) 
                                                     name:AVAudioSessionInterruptionNotification 
                                                   object:sessionInstance];
        // we don't do anything special in the route change notification
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleRouteChange:)
                                                     name:AVAudioSessionRouteChangeNotification 
                                                   object:sessionInstance];
        // activate the audio session
        [sessionInstance setActive:YES error:&error];
//        XThrowIfError(error.code, "couldn't set audio session active\n");
    } catch (CAXException e) {
        char buf[256];
        fprintf(stderr, "Error: %s (%s)\n", e.mOperation, e.FormatError(buf));
    }

    // initialize the graphController object
    [myViewController.graphController initializeAUGraph];
    // set up the mixer according to our interface defaults
    [myViewController setUIDefaults];
}

- (void)dealloc {
    self.window = nil;
    self.navigationController = nil;
    self.myViewController = nil;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AVAudioSessionInterruptionNotification 
                                                  object:[AVAudioSession sharedInstance]];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AVAudioSessionRouteChangeNotification 
                                                  object:[AVAudioSession sharedInstance]];
    
    [super dealloc];
}

@end
