/*
    File: MyViewController.m 
Abstract: The main view controller. 
 Version: 1.2.2 
 
*/

#import "MyViewController.h"

#define kTransitionDuration	0.75

@implementation MyViewController

@synthesize instructionsView, eqView, webView, contentView, infoButtonItem, eqButtonItem, doneButtonItem, startButton, bus0Switch, bus0VolumeSlider, bus1Switch, bus1VolumeSlider, outputVolumeSlider, eqSwitch, graphController;

#pragma mark - Life Cycle

- (void)viewDidLoad
{
	// load up the info text
    NSString *infoSouceFile = [[NSBundle mainBundle] pathForResource:@"info" ofType:@"html"];
	NSString *infoText = [NSString stringWithContentsOfFile:infoSouceFile encoding:NSUTF8StringEncoding error:nil];
    [self.webView loadHTMLString:infoText baseURL:nil];
    
    // set up start button
    UIImage *greenImage = [[UIImage imageNamed:@"green_button.png"] stretchableImageWithLeftCapWidth:12.0 topCapHeight:0.0];
	UIImage *redImage = [[UIImage imageNamed:@"red_button.png"] stretchableImageWithLeftCapWidth:12.0 topCapHeight:0.0];
	
	[startButton setBackgroundImage:greenImage forState:UIControlStateNormal];
	[startButton setBackgroundImage:redImage forState:UIControlStateSelected];
    
    // add the subview
    [self.view addSubview:instructionsView];
	[self.view addSubview:contentView];
	
	// add our custom buttons as the nav bars custom views
	UIButton* infoButton = [UIButton buttonWithType:UIButtonTypeInfoLight];
	[infoButton addTarget:self action:@selector(flipInfoAction:) forControlEvents:UIControlEventTouchUpInside];
    
    UIButton* disclosureButton = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];   
	[disclosureButton addTarget:self action:@selector(flipEQAction:) forControlEvents:UIControlEventTouchUpInside];
	
    infoButtonItem = [[UIBarButtonItem alloc] initWithCustomView:infoButton];
    self.navigationItem.leftBarButtonItem = infoButtonItem;
    
    eqButtonItem = [[UIBarButtonItem alloc] initWithCustomView:disclosureButton];
    self.navigationItem.rightBarButtonItem = nil; // eqButtonItem;
	
	// create our done button for the flipped views (used later)
	doneButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:nil];
}

- (void)dealloc
{    
    [instructionsView release];
    [eqView release];
    [webView release];
    [contentView release];
    
    self.infoButtonItem = nil;
    self.eqButtonItem = nil;
    self.doneButtonItem = nil;

    [startButton release];
    
    [bus0Switch release];
    [bus0VolumeSlider release];
    [bus1Switch release];
    [bus1VolumeSlider release];
    [outputVolumeSlider release];
    [eqSwitch release];
        
    [graphController release];
    
	[super dealloc];
}

#pragma mark - Public Methods

- (void)setUIDefaults
{
    [graphController enableInput:0 isOn:bus0Switch.isOn];
    [graphController enableInput:1 isOn:bus1Switch.isOn];
    [graphController setInputVolume:0 value:bus0VolumeSlider.value];
    [graphController setInputVolume:1 value:bus1VolumeSlider.value];
    [graphController setOutputVolume:outputVolumeSlider.value];
    
    bus0VolumeSlider.continuous = YES;
    bus1VolumeSlider.continuous = YES;
    outputVolumeSlider.continuous = YES;
    
    // the ipod eq has a list of presets, the first at index 0 is called "Disabled"
    // and is selected by default when the EQ instance is created -- we don't need
    // to specifically do anything since our default UI has the EQ turned off
    // however we do want to pick the "Flat" preset when the EQ is initially enabled
    // after that, it will represent what the user has selected from the list
    selectedEQPresetIndex = 8; // index 8 is the "Flat" preset
}

// called if we've been interrupted and if we're playing, stop
- (void)stopForInterruption
{
    if (graphController.isPlaying) {
        [graphController stopAUGraph];
        self.startButton.selected = NO;
    }
}

#pragma mark - Actions Methods

// do the info button flip
- (void)flipInfoAction:(id)sender
{
    if ([self.contentView superview]) {
        // flip to readme info view
        self.navigationItem.title = @"Read Me eh?";
        self.navigationItem.rightBarButtonItem = self.navigationItem.leftBarButtonItem = nil;
        
        [UIView transitionFromView:self.contentView
                            toView:self.instructionsView
                          duration:kTransitionDuration
                           options:UIViewAnimationOptionTransitionFlipFromLeft
                        completion:^(BOOL finished){
                            self.navigationItem.leftBarButtonItem = doneButtonItem;
                        }];
    } else {
        // flip back to main content view
        self.navigationItem.title = @"MixerEQGraph Test";
        self.navigationItem.rightBarButtonItem = self.navigationItem.leftBarButtonItem = nil;
        
        [UIView transitionFromView:self.instructionsView
                            toView:self.contentView
                          duration:kTransitionDuration
                           options:UIViewAnimationOptionTransitionFlipFromRight
                        completion:^(BOOL finished){
                            self.navigationItem.leftBarButtonItem = infoButtonItem;
                            if (eqSwitch.isOn) {
                                self.navigationItem.rightBarButtonItem = eqButtonItem;
                            }
                            
                        }];
    }
    
    doneButtonItem.action = @selector(flipInfoAction:);
}

// do the eq button flip
- (void)flipEQAction:(id)sende
{
    if ([self.contentView superview]) {
        // flip to eq view
        self.navigationItem.title = @"iPod Equalizer";
        self.navigationItem.rightBarButtonItem = self.navigationItem.leftBarButtonItem = nil;
        
        [UIView transitionFromView:self.contentView
                            toView:self.eqView
                          duration:kTransitionDuration
                           options:UIViewAnimationOptionTransitionFlipFromRight
                        completion:^(BOOL finished){
                            self.navigationItem.rightBarButtonItem = doneButtonItem;
                        }];
    } else {
        // flip back to main content view
        self.navigationItem.title = @"MixerEQGraph Test";
        self.navigationItem.rightBarButtonItem = self.navigationItem.leftBarButtonItem = nil;
        
        [UIView transitionFromView:self.eqView
                            toView:self.contentView
                          duration:kTransitionDuration
                           options:UIViewAnimationOptionTransitionFlipFromLeft
                        completion:^(BOOL finished){
                            self.navigationItem.leftBarButtonItem = infoButtonItem;
                            if (eqSwitch.isOn) {
                                self.navigationItem.rightBarButtonItem = eqButtonItem;
                            }
                        }];
    }
    
    doneButtonItem.action = @selector(flipEQAction:);
}

// handle the button press
- (IBAction)buttonPressedAction:(id)sender
{
    if (graphController.isPlaying) {
        [graphController stopAUGraph];
        self.startButton.selected = NO;
    }
    else {
        [graphController startAUGraph];
        self.startButton.selected = YES;
    }
}

// handle input on/off switch action
- (IBAction)enableInput:(UISwitch *)sender
{
    UInt32 inputNum = [sender tag];
    AudioUnitParameterValue isOn = (AudioUnitParameterValue)sender.isOn;
    
    if (0 == inputNum) self.bus0VolumeSlider.enabled = isOn;
    if (1 == inputNum) self.bus1VolumeSlider.enabled = isOn;
                                    
    [graphController enableInput:inputNum isOn:isOn];
}

// handle input volume changes
- (IBAction)setInputVolume:(UISlider *)sender
{
	UInt32 inputNum = [sender tag];
    AudioUnitParameterValue value = sender.value;
    [graphController setInputVolume:inputNum value:value];
}

// handle output volume changes
- (IBAction)setOutputVolume:(UISlider *)sender
{
    AudioUnitParameterValue value = sender.value;
    
    [graphController setOutputVolume:value];
}

@end