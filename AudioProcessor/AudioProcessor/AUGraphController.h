//
//  AUGraphController.h
//  AudioProcessor
//
//  Created by zhouchunbo on 8/6/15.
//  Copyright (c) 2015 edu. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AUGraphController : NSObject
+ (instancetype)sharedInstance;
- (void)playWithFileName:(NSURL *)fileName musicFile:(NSURL *)musicURL;
- (void)stop;
- (void)setRate:(Float32)value;
- (void)setPitch:(Float32)value;
- (void)setPreset:(int)index;
@end
