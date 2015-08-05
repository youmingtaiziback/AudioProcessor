//
//  Recorder.m
//  AudioProcessor
//
//  Created by youmingtaizi on 8/5/15.
//  Copyright (c) 2015 edu. All rights reserved.
//

#import "Recorder.h"
#import <AVFoundation/AVFoundation.h>

@interface Recorder () {
    AVAudioRecorder*    _recorder;
}
@end

@implementation Recorder

#pragma mark - Public Methods

+ (instancetype)sharedInstance {
    static Recorder* recorder;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        recorder = [[Recorder alloc] init];
    });
    return recorder;
}

- (void)startRecordWithFileName:(NSString *)name {
    NSString *filePathDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    NSURL *fileURL = [NSURL fileURLWithPath:[filePathDir stringByAppendingPathComponent:name]];
    _recorder = [[AVAudioRecorder alloc] initWithURL:fileURL settings:nil error:nil];
    [_recorder prepareToRecord];
    [_recorder record];
}

- (void)stopRecord {
    [_recorder stop];
}

@end
