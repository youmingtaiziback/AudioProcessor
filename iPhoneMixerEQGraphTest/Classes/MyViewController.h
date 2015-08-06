/*
    File: MyViewController.h
Abstract: The main view controller.
 Version: 1.2.2

*/
 
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

#import "AUGraphController.h"

@interface MyViewController : UIViewController
{
	UIView		*instructionsView;
    UIView		*eqView;
    UIWebView 	*webView;
    UIView		*contentView;
    
    UIBarButtonItem 	*infoButtonItem;
    UIBarButtonItem 	*eqButtonItem;
	UIBarButtonItem 	*doneButtonItem;
    
    IBOutlet UIButton 	*startButton;
    
    UISwitch   *bus0Switch;
    UISlider   *bus0VolumeSlider;
    UISwitch   *bus1Switch;
    UISlider   *bus1VolumeSlider;
    UISlider   *outputVolumeSlider;
    UISwitch   *eqSwitch;
    
    UInt8      selectedEQPresetIndex;
   
    AUGraphController *graphController;
}

@property (readonly, nonatomic) IBOutlet UIView    *instructionsView;
@property (readonly, nonatomic) IBOutlet UIView    *eqView;
@property (readonly, nonatomic) IBOutlet UIWebView *webView;
@property (readonly, nonatomic) IBOutlet UIView    *contentView;

@property (nonatomic, retain) UIBarButtonItem *infoButtonItem;
@property (nonatomic, retain) UIBarButtonItem *eqButtonItem;
@property (nonatomic, retain) UIBarButtonItem *doneButtonItem;

@property (readonly, nonatomic) IBOutlet UIButton *startButton;

@property (readonly, nonatomic) IBOutlet UISwitch *bus0Switch;
@property (readonly, nonatomic) IBOutlet UISlider *bus0VolumeSlider;
@property (readonly, nonatomic) IBOutlet UISwitch *bus1Switch;
@property (readonly, nonatomic) IBOutlet UISlider *bus1VolumeSlider;
@property (readonly, nonatomic) IBOutlet UISlider *outputVolumeSlider;
@property (readonly, nonatomic) IBOutlet UISwitch *eqSwitch;

@property (readonly, nonatomic) IBOutlet AUGraphController *graphController;

- (void)setUIDefaults;
- (void)stopForInterruption;

- (IBAction)enableInput:(UISwitch *)sender;
- (IBAction)setInputVolume:(UISlider *)sender;
- (IBAction)setOutputVolume:(UISlider *)sender;
- (IBAction)enableEQ:(UISwitch *)sender;
- (IBAction)buttonPressedAction:(id)sender;

@end