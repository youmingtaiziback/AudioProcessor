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
    NSURL*      _currentFileName;
}
@end

@implementation ViewController

#pragma mark - Life Cycle

- (void)viewDidLoad {
    [super viewDidLoad];
    NSFileManager *manager = [NSFileManager defaultManager];
    
    NSString *fileDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    NSArray *fileNames = [manager contentsOfDirectoryAtPath:fileDir error:nil];
    _currentFileName = [NSURL URLWithString:[fileDir stringByAppendingPathComponent:fileNames[0]]];
    [_fileNameButton setTitle:fileNames[0] forState:UIControlStateNormal];
}

#pragma mark - Action Methods

- (IBAction)play {
    static BOOL isPlaying = NO;
    isPlaying = !isPlaying;
    if (isPlaying) {
        NSURL *musicURL = [NSURL URLWithString:[[NSBundle mainBundle] pathForResource:@"Track1" ofType:@"mp4"]];
        [[AUGraphController sharedInstance] playWithFileName:_currentFileName musicFile:musicURL];
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
        NSString *fileName = [formmater stringFromDate:[NSDate date]];
        NSString *filePath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0] stringByAppendingPathComponent:fileName];
        _currentFileName = [NSURL fileURLWithPath:filePath];
        [[Recorder sharedInstance] startRecordWithFileName:_currentFileName];
        [_recordButton setTitle:@"Stop" forState:UIControlStateNormal];
    }
    else {
        [[Recorder sharedInstance] stopRecord];
        [_fileNameButton setTitle:[_currentFileName lastPathComponent] forState:UIControlStateNormal];
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

- (IBAction)setEQ:(UIButton *)button {
    [[AUGraphController sharedInstance] setPreset:button.tag];
}

@end
