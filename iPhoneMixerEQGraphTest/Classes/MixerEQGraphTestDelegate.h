/*
    File: MixerEQGraphTestDelegate.h
Abstract: The application delegate class.
 Version: 1.2.2

*/
 
#import <UIKit/UIKit.h>

#import "MyViewController.h"
#import "CAXException.h"

@interface MixerEQGraphTestDelegate : NSObject <UIApplicationDelegate> {
    UIWindow *window;
    UINavigationController	*navigationController;
	MyViewController		*myViewController;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet UINavigationController *navigationController;
@property (nonatomic, retain) IBOutlet MyViewController *myViewController;

@end

