//
//  Player.m
//  AudioProcessor
//
//  Created by zhouchunbo on 8/6/15.
//  Copyright (c) 2015 edu. All rights reserved.
//

#import "Player.h"
#import <AVFoundation/AVFoundation.h>

@interface Player () {
    AVAudioPlayer*  _player;
}
@end

@implementation Player

#pragma mark - Public Methods

+ (instancetype)sharedInstance {
    static Player* player;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        player = [[Player alloc] init];
    });
    return player;
}

- (void)playFileWithName:(NSString *)name {
    NSString *dir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    NSString *filePath = [dir stringByAppendingPathComponent:name];
    _player = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL URLWithString:filePath] error:nil];
    [_player play];
}

- (void)stopPlay {
    [_player stop];
}

@end
