//
//  Player.h
//  AudioProcessor
//
//  Created by zhouchunbo on 8/6/15.
//  Copyright (c) 2015 edu. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Player : NSObject
+ (instancetype)sharedInstance;
- (void)playFileWithName:(NSString *)name;
- (void)stopPlay;
@end
