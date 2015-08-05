//
//  ViewController.m
//  AudioProcessor
//
//  Created by youmingtaizi on 8/5/15.
//  Copyright (c) 2015 edu. All rights reserved.
//

#import "ViewController.h"
#import "Recorder.h"
#import "AUGraphController.h"

@interface ViewController () {
    IBOutlet UIButton*  _fileNameButton;
    IBOutlet UIButton*  _playButton;
    IBOutlet UIButton*  _recordButton;
    NSString*   _currentFileName;
}
@end

@implementation ViewController

#pragma mark - Action Methods

- (IBAction)play {
    static BOOL isPlaying = NO;
    isPlaying = !isPlaying;
    if (isPlaying) {
        [[AUGraphController sharedInstance] playWithFileName:_currentFileName];
        [_playButton setTitle:@"Stop" forState:UIControlStateNormal];
    }
    else {
        [[AUGraphController sharedInstance] stop];
        [_playButton setTitle:@"Play" forState:UIControlStateNormal];
    }
}

- (IBAction)record {
    static BOOL isRecoding = NO;
    isRecoding = !isRecoding;
    if (isRecoding) {
        NSDateFormatter *formmater = [[NSDateFormatter alloc] init];
        formmater.dateFormat = @"HH:MM:ss";
        _currentFileName = [formmater stringFromDate:[NSDate date]];
        [[Recorder sharedInstance] startRecordWithFileName:_currentFileName];
        [_recordButton setTitle:@"Stop" forState:UIControlStateNormal];
    }
    else {
        [[Recorder sharedInstance] stopRecord];
        [_fileNameButton setTitle:_currentFileName forState:UIControlStateNormal];
        [_recordButton setTitle:@"Record" forState:UIControlStateNormal];
    }
}

- (IBAction)rateChanged:(UISlider *)slider {
    Float32 rateParam =  powf(2.0, [slider value] - 5.0);
    [[AUGraphController sharedInstance] setRate:rateParam];
}

- (IBAction)pitchSliderChanged:(UISlider *)slider {
    [[AUGraphController sharedInstance] setPitch:slider.value];
}

@end
