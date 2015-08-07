//
//  AUGraphController.m
//  AudioProcessor
//
//  Created by zhouchunbo on 8/6/15.
//  Copyright (c) 2015 edu. All rights reserved.
//

#import "AUGraphController.h"
#import <AudioToolbox/AudioToolbox.h>
#import "CAStreamBasicDescription.h"
#import <AudioUnit/AudioUnit.h>

#define MAXBUFS  1
#define NUMFILES 1

const Float64 kGraphSampleRate = 44100.0;

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
    AudioUnit   _eqUnit;
    AudioUnit   _effectUnit;
    CAStreamBasicDescription mClientFormat;
    CAStreamBasicDescription mOutputFormat;
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

- (void)playWithFileName:(NSURL *)fileName musicFile:(NSURL *)musicURL {
    [self setUpAUGraphWithAssetURL:fileName musicFile:musicURL];
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

- (void)setPreset:(int)index {
    CFArrayRef mEQPresetsArray;
    UInt32 size = sizeof(mEQPresetsArray);
    CheckError(AudioUnitGetProperty(_eqUnit, kAudioUnitProperty_FactoryPresets, kAudioUnitScope_Global, 0, &mEQPresetsArray, &size), "14");
    AUPreset *aPreset = (AUPreset*)CFArrayGetValueAtIndex(mEQPresetsArray, index);
    CheckError(AudioUnitSetProperty(_eqUnit, kAudioUnitProperty_PresentPreset, kAudioUnitScope_Global, 0, aPreset, sizeof(AUPreset)), "14");
}

#pragma mark - Private Methods

-(void) setUpAUGraphWithAssetURL:(NSURL *)assetURL musicFile:(NSURL *)musicURL {
    if (_graph) {
        CheckError(AUGraphClose(_graph), "Couldn't close old AUGraph");
        CheckError (DisposeAUGraph(_graph), "Couldn't dispose old AUGraph");
    }
    
    CheckError(NewAUGraph(&_graph), "Couldn't create new AUGraph");
    CheckError(AUGraphOpen(_graph), "Couldn't open AUGraph");
    
    mClientFormat.SetCanonical(2, true);
    mClientFormat.mSampleRate = kGraphSampleRate;
    
    // output format
    mOutputFormat.SetAUCanonical(2, false);
    mOutputFormat.mSampleRate = kGraphSampleRate;

    /* 播放背景音乐配置 */
    // player unit
    AudioComponentDescription bgfileplayercd = {0};
    bgfileplayercd.componentType = kAudioUnitType_Generator;
    bgfileplayercd.componentSubType = kAudioUnitSubType_AudioFilePlayer;
    bgfileplayercd.componentManufacturer = kAudioUnitManufacturer_Apple;
    AUNode bgFilePlayerNode;
    AudioUnit bgFilePlayerUnit;
    CheckError(AUGraphAddNode(_graph, &bgfileplayercd, &bgFilePlayerNode), "Couldn't add file player node");
    CheckError(AUGraphNodeInfo(_graph, bgFilePlayerNode, NULL, &bgFilePlayerUnit), "couldn't get file player node");

    // eq unit
    AudioComponentDescription eqcd = {0};
    eqcd.componentType = kAudioUnitType_Effect;
    eqcd.componentSubType = kAudioUnitSubType_AUiPodEQ;
    eqcd.componentManufacturer = kAudioUnitManufacturer_Apple;
    AUNode eqNode;
    CheckError(AUGraphAddNode(_graph, &eqcd, &eqNode), "couldn't get effect node [time/pitch]");
    CheckError(AUGraphNodeInfo(_graph, eqNode, NULL, &_eqUnit), "couldn't get effect unit from node");
    // set property
    CFArrayRef mEQPresetsArray;
    UInt32 size = sizeof(mEQPresetsArray);
    CheckError(AudioUnitGetProperty(_eqUnit, kAudioUnitProperty_FactoryPresets, kAudioUnitScope_Global, 0, &mEQPresetsArray, &size), "14");
    AUPreset *aPreset = (AUPreset*)CFArrayGetValueAtIndex(mEQPresetsArray, 3);
    CheckError(AudioUnitSetProperty(_eqUnit, kAudioUnitProperty_PresentPreset, kAudioUnitScope_Global, 0, aPreset, sizeof(AUPreset)), "14");
    
    /* 播放人声配置 */
    // player unit
    AudioComponentDescription fileplayercd = {0};
    fileplayercd.componentType = kAudioUnitType_Generator;
    fileplayercd.componentSubType = kAudioUnitSubType_AudioFilePlayer;
    fileplayercd.componentManufacturer = kAudioUnitManufacturer_Apple;
    AUNode filePlayerNode;
    AudioUnit filePlayerUnit;
    CheckError(AUGraphAddNode(_graph, &fileplayercd, &filePlayerNode), "Couldn't add file player node");
    CheckError(AUGraphNodeInfo(_graph, filePlayerNode, NULL, &filePlayerUnit), "couldn't get file player node");
    
    // effect unit here
    AudioComponentDescription effectcd = {0};
    effectcd.componentType = kAudioUnitType_FormatConverter;
    effectcd.componentSubType = kAudioUnitSubType_NewTimePitch;
    effectcd.componentManufacturer = kAudioUnitManufacturer_Apple;
    AUNode effectNode;
    CheckError(AUGraphAddNode(_graph, &effectcd, &effectNode), "couldn't get effect node [time/pitch]");
    CheckError(AUGraphNodeInfo(_graph, effectNode, NULL, &_effectUnit), "couldn't get effect unit from node");
    // set property
    AudioStreamBasicDescription streamFormat;
    UInt32 propertySize = sizeof (streamFormat);
    CheckError(AudioUnitGetProperty(_effectUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &streamFormat, &propertySize), "13");
    CheckError(AudioUnitSetProperty(filePlayerUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &streamFormat, sizeof(streamFormat)), "14");
    
    // mixer unit
    AudioComponentDescription mixercd = {0};
    mixercd.componentType = kAudioUnitType_Mixer;
    mixercd.componentSubType = kAudioUnitSubType_MultiChannelMixer;
    mixercd.componentManufacturer = kAudioUnitManufacturer_Apple;
    AUNode mixerNode;
    AudioUnit mixerUnit;
    CheckError(AUGraphAddNode(_graph, &mixercd, &mixerNode), "couldn't get effect node [time/pitch]");
    CheckError(AUGraphNodeInfo(_graph, mixerNode, NULL, &mixerUnit), "couldn't get effect unit from node");
    // set property
    UInt32 numbuses = 2;
    CheckError(AudioUnitSetProperty(mixerUnit, kAudioUnitProperty_ElementCount, kAudioUnitScope_Input, 0, &numbuses, sizeof(numbuses)), "16");
    CheckError(AudioUnitSetProperty(mixerUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &mOutputFormat, sizeof(mOutputFormat)), "123");
    CheckError(AudioUnitSetProperty(mixerUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &mOutputFormat, sizeof(mOutputFormat)), "14");

    // remote io unit
    AudioComponentDescription outputcd = {0};
    outputcd.componentType = kAudioUnitType_Output;
    outputcd.componentSubType = kAudioUnitSubType_RemoteIO;
    outputcd.componentManufacturer = kAudioUnitManufacturer_Apple;
    AUNode ioNode;
    CheckError(AUGraphAddNode(_graph, &outputcd, &ioNode), "couldn't add remote io node");
    AudioUnit ioUnit;
    CheckError(AUGraphNodeInfo(_graph, ioNode, NULL, &ioUnit), "couldn't get remote io unit");
    
    // make connections
    CheckError(AUGraphConnectNodeInput(_graph, filePlayerNode, 0, effectNode, 0), "16");
    CheckError(AUGraphConnectNodeInput(_graph, effectNode, 0, mixerNode, 1), "16");
    
    CheckError(AUGraphConnectNodeInput(_graph, bgFilePlayerNode, 0, eqNode, 0), "16");
    CheckError(AUGraphConnectNodeInput(_graph, eqNode, 0, mixerNode, 0), "16");
    
    CheckError(AUGraphConnectNodeInput(_graph, mixerNode, 0, ioNode, 0), "17");

    // initialize
    CheckError(AUGraphInitialize(_graph), "18");
    
    CAShow(_graph);
    
    // 背景音乐
    AudioFileID bgAudioFile;
    CheckError(AudioFileOpenURL((CFURLRef)CFBridgingRetain(musicURL), kAudioFileReadPermission, kAudioFileCAFType, &bgAudioFile), "19");
    AudioStreamBasicDescription bgFileStreamFormat;
    UInt32 bgPropsize = sizeof (mOutputFormat);
    CheckError(AudioFileGetProperty(bgAudioFile, kAudioFilePropertyDataFormat, &propertySize, &bgFileStreamFormat), "20");
    CheckError(AudioUnitSetProperty(bgFilePlayerUnit, kAudioUnitProperty_ScheduledFileIDs, kAudioUnitScope_Global, 0, &bgAudioFile, sizeof(bgAudioFile)), "21");
    UInt64 nBGPackets;
    bgPropsize = sizeof(nBGPackets);
    CheckError(AudioFileGetProperty(bgAudioFile, kAudioFilePropertyAudioDataPacketCount, &bgPropsize, &nBGPackets), "22");
    ScheduledAudioFileRegion bgrgn;
    memset (&bgrgn.mTimeStamp, 0, sizeof(bgrgn.mTimeStamp));
    bgrgn.mTimeStamp.mFlags = kAudioTimeStampSampleTimeValid;
    bgrgn.mTimeStamp.mSampleTime = 0;
    bgrgn.mCompletionProc = NULL;
    bgrgn.mCompletionProcUserData = NULL;
    bgrgn.mAudioFile = bgAudioFile;
    bgrgn.mLoopCount = 100;
    bgrgn.mStartFrame = 0;
    bgrgn.mFramesToPlay = nBGPackets * bgFileStreamFormat.mFramesPerPacket;
    CheckError(AudioUnitSetProperty(bgFilePlayerUnit, kAudioUnitProperty_ScheduledFileRegion, kAudioUnitScope_Global, 0, &bgrgn, sizeof(bgrgn)), "23");
    UInt32 bgDefaultVal = 0;
    CheckError(AudioUnitSetProperty(bgFilePlayerUnit, kAudioUnitProperty_ScheduledFilePrime, kAudioUnitScope_Global, 0, &bgDefaultVal, sizeof(bgDefaultVal)), "24");
    AudioTimeStamp bgStartTime;
    memset (&bgStartTime, 0, sizeof(bgStartTime));
    bgStartTime.mFlags = kAudioTimeStampSampleTimeValid;
    bgStartTime.mSampleTime = -1;
    CheckError(AudioUnitSetProperty(bgFilePlayerUnit, kAudioUnitProperty_ScheduleStartTimeStamp, kAudioUnitScope_Global, 0, &bgStartTime, sizeof(bgStartTime)), "25");
    
    // 人声
    CFURLRef audioFileURL = (CFURLRef)CFBridgingRetain(assetURL);
    AudioFileID audioFile;
    CheckError(AudioFileOpenURL(audioFileURL, kAudioFileReadPermission, kAudioFileCAFType, &audioFile), "19");
    AudioStreamBasicDescription fileStreamFormat;
    UInt32 propsize = sizeof (mOutputFormat);
    CheckError(AudioFileGetProperty(audioFile, kAudioFilePropertyDataFormat, &propertySize, &fileStreamFormat), "20");
    CheckError(AudioUnitSetProperty(filePlayerUnit, kAudioUnitProperty_ScheduledFileIDs, kAudioUnitScope_Global, 0, &audioFile, sizeof(audioFile)), "21");
    UInt64 nPackets;
    propsize = sizeof(nPackets);
    CheckError(AudioFileGetProperty(audioFile, kAudioFilePropertyAudioDataPacketCount, &propsize, &nPackets), "22");
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
    CheckError(AudioUnitSetProperty(filePlayerUnit, kAudioUnitProperty_ScheduledFileRegion, kAudioUnitScope_Global, 0, &rgn, sizeof(rgn)), "23");
    UInt32 defaultVal = 0;
    CheckError(AudioUnitSetProperty(filePlayerUnit, kAudioUnitProperty_ScheduledFilePrime, kAudioUnitScope_Global, 0, &defaultVal, sizeof(defaultVal)), "24");
    AudioTimeStamp startTime;
    memset (&startTime, 0, sizeof(startTime));
    startTime.mFlags = kAudioTimeStampSampleTimeValid;
    startTime.mSampleTime = -1;
    CheckError(AudioUnitSetProperty(filePlayerUnit, kAudioUnitProperty_ScheduleStartTimeStamp, kAudioUnitScope_Global, 0, &startTime, sizeof(startTime)), "25");

    CheckError(AUGraphStart(_graph), "Couldn't start AUGraph");
}

@end
