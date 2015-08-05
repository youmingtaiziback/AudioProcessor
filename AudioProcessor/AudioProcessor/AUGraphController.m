//
//  AUGraphController.m
//  AudioProcessor
//
//  Created by zhouchunbo on 8/6/15.
//  Copyright (c) 2015 edu. All rights reserved.
//

#import "AUGraphController.h"
#import <AudioToolbox/AudioToolbox.h>

static void CheckError(OSStatus error, const char *operation) {
    if (error == noErr) return;
    
    char str[20];
    // see if it appears to be a 4-char-code
    *(UInt32 *)(str + 1) = CFSwapInt32HostToBig(error);
    if (isprint(str[1]) && isprint(str[2]) && isprint(str[3]) && isprint(str[4])) {
        str[0] = str[5] = '\'';
        str[6] = '\0';
    }
    else
        sprintf(str, "%d", (int)error);
    
    fprintf(stderr, "Error: %s (%s)\n", operation, str);
    exit(1);
}

@interface AUGraphController () {
    AUGraph     _graph;
    AudioUnit   _effectUnit;
}
@end

@implementation AUGraphController

#pragma mark - Public Methods

+ (instancetype)sharedInstance {
    static AUGraphController* sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[AUGraphController alloc] init];
    });
    return sharedInstance;
}

- (void)playWithFileName:(NSString *)fileName {
    NSString *filePath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0] stringByAppendingPathComponent:fileName];
    [self setUpAUGraphWithAssetURL:[NSURL URLWithString:filePath]];
}

- (void)stop {
    AUGraphStop(_graph);
}

- (void)setRate:(Float32)value {
    AudioUnitSetParameter(_effectUnit, kNewTimePitchParam_Rate, kAudioUnitScope_Global, 0, value, 0);
}

- (void)setPitch:(Float32)value {
    AudioUnitSetParameter(_effectUnit, kNewTimePitchParam_Pitch, kAudioUnitScope_Global, 0, value, 0);
}

#pragma mark - Private Methods

-(void) setUpAUGraphWithAssetURL:(NSURL *)assetURL {
    if (_graph) {
        CheckError(AUGraphClose(_graph), "Couldn't close old AUGraph");
        CheckError (DisposeAUGraph(_graph), "Couldn't dispose old AUGraph");
    }
    
    CheckError(NewAUGraph(&_graph), "Couldn't create new AUGraph");
    CheckError(AUGraphOpen(_graph), "Couldn't open AUGraph");
    
    // player unit
    AudioComponentDescription fileplayercd = {0};
    fileplayercd.componentType = kAudioUnitType_Generator;
    fileplayercd.componentSubType = kAudioUnitSubType_AudioFilePlayer;
    fileplayercd.componentManufacturer = kAudioUnitManufacturer_Apple;
    AUNode filePlayerNode;
    AudioUnit _filePlayerUnit;
    CheckError(AUGraphAddNode(_graph, &fileplayercd, &filePlayerNode), "Couldn't add file player node");
    CheckError(AUGraphNodeInfo(_graph, filePlayerNode, NULL, &_filePlayerUnit), "couldn't get file player node");
    
    // remote io unit
    AudioComponentDescription outputcd = {0};
    outputcd.componentType = kAudioUnitType_Output;
    outputcd.componentSubType = kAudioUnitSubType_RemoteIO;
    outputcd.componentManufacturer = kAudioUnitManufacturer_Apple;
    AUNode ioNode;
    AudioUnit _ioUnit;
    CheckError(AUGraphAddNode(_graph, &outputcd, &ioNode), "couldn't add remote io node");
    CheckError(AUGraphNodeInfo(_graph, ioNode, NULL, &_ioUnit), "couldn't get remote io unit");
    
    // effect unit here
    AudioComponentDescription effectcd = {0};
    effectcd.componentType = kAudioUnitType_FormatConverter;
    effectcd.componentSubType = kAudioUnitSubType_NewTimePitch;
    effectcd.componentManufacturer = kAudioUnitManufacturer_Apple;
    AUNode effectNode;
    CheckError(AUGraphAddNode(_graph, &effectcd, &effectNode), "couldn't get effect node [time/pitch]");
    CheckError(AUGraphNodeInfo(_graph, effectNode, NULL, &_effectUnit), "couldn't get effect unit from node");
    
    // enable output to the remote io unit
    UInt32 oneFlag = 1;
    UInt32 busZero = 0;
    CheckError(AudioUnitSetProperty(_ioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, busZero, &oneFlag, sizeof(oneFlag)),
               "12");
    
    // set stream format that the effect wants
    AudioStreamBasicDescription streamFormat;
    UInt32 propertySize = sizeof (streamFormat);
    CheckError(AudioUnitGetProperty(_effectUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &streamFormat, &propertySize), "13");
    CheckError(AudioUnitSetProperty(_filePlayerUnit,
                                    kAudioUnitProperty_StreamFormat,
                                    kAudioUnitScope_Output,
                                    busZero,
                                    &streamFormat,
                                    sizeof(streamFormat)),
               "couldn't set stream format on file player bus 0 output");
    CheckError(AudioUnitSetProperty(_ioUnit,
                                    kAudioUnitProperty_StreamFormat,
                                    kAudioUnitScope_Input,
                                    busZero,
                                    &streamFormat,
                                    sizeof(streamFormat)),
               "couldn't set stream format on iounit bus 0 input");
    
    // make connections
    CheckError(AUGraphConnectNodeInput(_graph, filePlayerNode, 0, effectNode, 0), "14");
    CheckError(AUGraphConnectNodeInput(_graph, effectNode, 0, ioNode, 0), "15");
    
    // initialize
    CheckError(AUGraphInitialize(_graph), "Couldn't initialize AUGraph");
    
    CFURLRef audioFileURL = CFBridgingRetain(assetURL);
    AudioFileID audioFile;
    CheckError(AudioFileOpenURL(audioFileURL, kAudioFileReadPermission, kAudioFileCAFType, &audioFile), "Couldn't open audio file");
    
    AudioStreamBasicDescription fileStreamFormat;
    UInt32 propsize = sizeof (fileStreamFormat);
    CheckError(AudioFileGetProperty(audioFile, kAudioFilePropertyDataFormat, &propertySize, &fileStreamFormat),
               "couldn't get input file's stream format");
    
    CheckError(AudioUnitSetProperty(_filePlayerUnit,
                                    kAudioUnitProperty_ScheduledFileIDs,
                                    kAudioUnitScope_Global,
                                    0,
                                    &audioFile,
                                    sizeof(audioFile)),
               "AudioUnitSetProperty[kAudioUnitProperty_ScheduledFileIDs] failed");
    
    UInt64 nPackets;
    propsize = sizeof(nPackets);
    CheckError(AudioFileGetProperty(audioFile,
                                    kAudioFilePropertyAudioDataPacketCount,
                                    &propsize,
                                    &nPackets),
               "AudioFileGetProperty[kAudioFilePropertyAudioDataPacketCount] failed");
    
    // tell the file player AU to play the entire file
    ScheduledAudioFileRegion rgn;
    memset (&rgn.mTimeStamp, 0, sizeof(rgn.mTimeStamp));
    rgn.mTimeStamp.mFlags = kAudioTimeStampSampleTimeValid;
    rgn.mTimeStamp.mSampleTime = 0;
    rgn.mCompletionProc = NULL;
    rgn.mCompletionProcUserData = NULL;
    rgn.mAudioFile = audioFile;
    rgn.mLoopCount = 100;
    rgn.mStartFrame = 0;
    rgn.mFramesToPlay = nPackets * fileStreamFormat.mFramesPerPacket;
    
    CheckError(AudioUnitSetProperty(_filePlayerUnit,
                                    kAudioUnitProperty_ScheduledFileRegion,
                                    kAudioUnitScope_Global,
                                    0,
                                    &rgn,
                                    sizeof(rgn)),
               "AudioUnitSetProperty[kAudioUnitProperty_ScheduledFileRegion] failed");
    
    // prime the file player AU with default values
    UInt32 defaultVal = 0;
    CheckError(AudioUnitSetProperty(_filePlayerUnit,
                                    kAudioUnitProperty_ScheduledFilePrime,
                                    kAudioUnitScope_Global,
                                    0,
                                    &defaultVal,
                                    sizeof(defaultVal)),
               "AudioUnitSetProperty[kAudioUnitProperty_ScheduledFilePrime] failed");
    
    // tell the file player AU when to start playing (-1 sample time means next render cycle)
    AudioTimeStamp startTime;
    memset (&startTime, 0, sizeof(startTime));
    startTime.mFlags = kAudioTimeStampSampleTimeValid;
    startTime.mSampleTime = -1;
    CheckError(AudioUnitSetProperty(_filePlayerUnit,
                                    kAudioUnitProperty_ScheduleStartTimeStamp,
                                    kAudioUnitScope_Global,
                                    0,
                                    &startTime,
                                    sizeof(startTime)),
               "AudioUnitSetProperty[kAudioUnitProperty_ScheduleStartTimeStamp]");
    
    CheckError(AUGraphStart(_graph), "Couldn't start AUGraph");
}

@end