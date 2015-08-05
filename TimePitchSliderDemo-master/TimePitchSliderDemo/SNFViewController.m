//
//  SNFViewController.m
//  TimePitchScratch
//
//  Created by Chris Adamson on 10/13/12.
//  Copyright (c) 2012 Your Organization. All rights reserved.
//

#import "SNFViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
//#import "DCFileProducer.h"
//#import "DCMediaPlayer.h"

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

@interface SNFViewController ()
@property (weak, nonatomic) IBOutlet UISlider *timeSlider;
@property (weak, nonatomic) IBOutlet UISlider *pitchSlider;
@property (weak, nonatomic) IBOutlet UILabel *rateLabel;
@property (atomic) AUGraph auGraph;
@property (atomic) AudioUnit ioUnit;
@property (atomic) AudioUnit effectUnit;
@property (atomic) AudioUnit filePlayerUnit;
//@property(nonatomic, retain)DCMediaExporter *mediaExporter;
//@property(nonatomic, retain)DCAudioProducer *audioProducer;
//@property(nonatomic, retain)DCMediaPlayer *mediaPlayer;
@property(nonatomic, retain)UIAlertView *alertView;
@end

@implementation SNFViewController
@synthesize auGraph = _auGraph;
@synthesize ioUnit = _ioUnit;
@synthesize effectUnit = _effectUnit;
@synthesize filePlayerUnit = _filePlayerUnit;
@synthesize song;

#pragma mark - Life Cycle

- (void)viewDidLoad {
    [super viewDidLoad];
	[self setUpAudioSession];
//	self.mediaPlayer = [[DCMediaPlayer alloc] init];
	[self setUpAUGraph];
	[self resetRate];
}

#pragma mark - Private Methods

-(NSError*) setUpAudioSession {
    NSError *sessionErr;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:&sessionErr];
    if (sessionErr)
        return sessionErr;
    
    [[AVAudioSession sharedInstance] setActive:YES error:&sessionErr];
    if (sessionErr)
        return sessionErr;
    return nil;
}

-(void) setUpAUGraph {
    if (self.auGraph) {
        CheckError(AUGraphClose(self.auGraph), "0");
        CheckError (DisposeAUGraph(self.auGraph), "1");
    }
    
    CheckError(NewAUGraph(&_auGraph), "2");
    CheckError(AUGraphOpen(self.auGraph), "3");
    
    // player unit
    AudioComponentDescription fileplayercd = {0};
    fileplayercd.componentType = kAudioUnitType_Generator;
    fileplayercd.componentSubType = kAudioUnitSubType_AudioFilePlayer;
    fileplayercd.componentManufacturer = kAudioUnitManufacturer_Apple;
    AUNode filePlayerNode;
    CheckError(AUGraphAddNode(self.auGraph, &fileplayercd, &filePlayerNode), "4");
    CheckError(AUGraphNodeInfo(self.auGraph, filePlayerNode, NULL, &_filePlayerUnit), "5");
    
    // remote io unit
    AudioComponentDescription outputcd = {0};
    outputcd.componentType = kAudioUnitType_Output;
    outputcd.componentSubType = kAudioUnitSubType_RemoteIO;
    outputcd.componentManufacturer = kAudioUnitManufacturer_Apple;
    AUNode ioNode;
    CheckError(AUGraphAddNode(self.auGraph, &outputcd, &ioNode), "6");
    CheckError(AUGraphNodeInfo(self.auGraph, ioNode, NULL, &_ioUnit), "7");
    
    // effect unit
    AudioComponentDescription effectcd = {0};
    effectcd.componentType = kAudioUnitType_FormatConverter;
    effectcd.componentSubType = kAudioUnitSubType_NewTimePitch;
    effectcd.componentManufacturer = kAudioUnitManufacturer_Apple;
    AUNode effectNode;
    CheckError(AUGraphAddNode(self.auGraph, &effectcd, &effectNode), "8");
    CheckError(AUGraphNodeInfo(self.auGraph,effectNode,NULL,&_effectUnit),"9");
    
    // enable output to the remote io unit
    UInt32 oneFlag = 1;
    UInt32 busZero = 0;
    CheckError(AudioUnitSetProperty(self.ioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, busZero, &oneFlag, sizeof(oneFlag)), "10");
    
    // set stream format that the effect wants
    AudioStreamBasicDescription streamFormat;
    UInt32 propertySize = sizeof (streamFormat);
    CheckError(AudioUnitGetProperty(self.effectUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &streamFormat, &propertySize), "11");
    CheckError(AudioUnitSetProperty(self.filePlayerUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, busZero, &streamFormat, sizeof(streamFormat)), "12");
    CheckError(AudioUnitSetProperty(self.ioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, busZero, &streamFormat, sizeof(streamFormat)), "13");
    
    // make connections
    CheckError(AUGraphConnectNodeInput(self.auGraph, filePlayerNode, 0, effectNode, 0), "14");
    CheckError(AUGraphConnectNodeInput(self.auGraph, effectNode, 0, ioNode, 0), "15");
    
    // initialize
    CheckError(AUGraphInitialize(self.auGraph), "16");
    CAShow(self.auGraph);
    
    // configure file player
//    CFURLRef audioFileURL = CFBridgingRetain([[NSBundle mainBundle] URLForResource:@"12 Bar Blues Bass" withExtension:@"caf"]);
    CFURLRef audioFileURL = CFBridgingRetain([[NSBundle mainBundle] URLForResource:@"RecordedFile" withExtension:nil]);
    AudioFileID audioFile;
    CheckError(AudioFileOpenURL(audioFileURL, kAudioFileReadPermission, kAudioFileCAFType, &audioFile), "17");
    
    AudioStreamBasicDescription fileStreamFormat;
    UInt32 propsize = sizeof (fileStreamFormat);
    CheckError(AudioFileGetProperty(audioFile, kAudioFilePropertyDataFormat, &propertySize, &fileStreamFormat), "18");
    
    CheckError(AudioUnitSetProperty(self.filePlayerUnit, kAudioUnitProperty_ScheduledFileIDs, kAudioUnitScope_Global, 0, &audioFile, sizeof(audioFile)), "5");
    
    UInt64 nPackets;
    propsize = sizeof(nPackets);
    CheckError(AudioFileGetProperty(audioFile, kAudioFilePropertyAudioDataPacketCount, &propsize, &nPackets), "19");
    
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
    
    CheckError(AudioUnitSetProperty(self.filePlayerUnit, kAudioUnitProperty_ScheduledFileRegion, kAudioUnitScope_Global, 0, &rgn, sizeof(rgn)), "7");
    
    // prime the file player AU with default values
    UInt32 defaultVal = 0;
    CheckError(AudioUnitSetProperty(self.filePlayerUnit, kAudioUnitProperty_ScheduledFilePrime, kAudioUnitScope_Global, 0, &defaultVal, sizeof(defaultVal)), "8");
    
    // tell the file player AU when to start playing (-1 sample time means next render cycle)
    AudioTimeStamp startTime;
    memset (&startTime, 0, sizeof(startTime));
    startTime.mFlags = kAudioTimeStampSampleTimeValid;
    startTime.mSampleTime = -1;
    CheckError(AudioUnitSetProperty(self.filePlayerUnit, kAudioUnitProperty_ScheduleStartTimeStamp, kAudioUnitScope_Global, 0, &startTime, sizeof(startTime)), "9");
    CheckError(AUGraphStart(self.auGraph), "20");
}

-(void) resetRate {
    // available rates are from 1/32 to 32. slider runs 0 to 10, where each whole
    // value is a power of 2:
    //		1/32, 1/16, 1/8, 1/4, 1/2, 1, 2, 4, 8, 16, 32
    // so:
    //		slider = 5, rateParam = 1.0
    //		slider = 0, rateParam = 1/32
    //		slider = 10, rateParam = 32
    Float32 rateParam =  powf(2.0, [self.timeSlider value] - 5.0);
    self.rateLabel.text = [NSString stringWithFormat: @"%0.3f", rateParam];
    CheckError(AudioUnitSetParameter(self.effectUnit, kNewTimePitchParam_Rate, kAudioUnitScope_Global, 0, rateParam, 0), "couldn't set pitch parameter");
}

-(void) resetPitch {
    Float32 pitchParam = [self.pitchSlider value];
    CheckError(AudioUnitSetParameter(self.effectUnit, kNewTimePitchParam_Pitch, kAudioUnitScope_Global, 0, pitchParam, 0), "couldn't set pitch parameter");
}

-(void) playSongWithAssetURL:(NSURL *)assetURL {
    [self setUpAUGraphWithAssetURL:assetURL];
}

-(void) setUpAUGraphWithAssetURL:(NSURL *)assetURL {
    if (self.auGraph) {
        CheckError(AUGraphClose(self.auGraph), "Couldn't close old AUGraph");
        CheckError (DisposeAUGraph(self.auGraph), "Couldn't dispose old AUGraph");
    }
    
    CheckError(NewAUGraph(&_auGraph), "Couldn't create new AUGraph");
    CheckError(AUGraphOpen(self.auGraph), "Couldn't open AUGraph");
    
    // player unit
    AudioComponentDescription fileplayercd = {0};
    fileplayercd.componentType = kAudioUnitType_Generator;
    fileplayercd.componentSubType = kAudioUnitSubType_AudioFilePlayer;
    fileplayercd.componentManufacturer = kAudioUnitManufacturer_Apple;
    AUNode filePlayerNode;
    CheckError(AUGraphAddNode(self.auGraph, &fileplayercd, &filePlayerNode), "Couldn't add file player node");
    CheckError(AUGraphNodeInfo(self.auGraph, filePlayerNode, NULL, &_filePlayerUnit), "couldn't get file player node");
    
    // remote io unit
    AudioComponentDescription outputcd = {0};
    outputcd.componentType = kAudioUnitType_Output;
    outputcd.componentSubType = kAudioUnitSubType_RemoteIO;
    outputcd.componentManufacturer = kAudioUnitManufacturer_Apple;
    AUNode ioNode;
    CheckError(AUGraphAddNode(self.auGraph, &outputcd, &ioNode), "couldn't add remote io node");
    CheckError(AUGraphNodeInfo(self.auGraph, ioNode, NULL, &_ioUnit), "couldn't get remote io unit");
    
    // effect unit here
    AudioComponentDescription effectcd = {0};
    effectcd.componentType = kAudioUnitType_FormatConverter;
    effectcd.componentSubType = kAudioUnitSubType_NewTimePitch;
    effectcd.componentManufacturer = kAudioUnitManufacturer_Apple;
    AUNode effectNode;
    CheckError(AUGraphAddNode(self.auGraph, &effectcd, &effectNode), "couldn't get effect node [time/pitch]");
    CheckError(AUGraphNodeInfo(self.auGraph, effectNode, NULL, &_effectUnit), "couldn't get effect unit from node");
    
    // enable output to the remote io unit
    UInt32 oneFlag = 1;
    UInt32 busZero = 0;
    CheckError(AudioUnitSetProperty(self.ioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, busZero, &oneFlag, sizeof(oneFlag)),
               "12");
    
    // set stream format that the effect wants
    AudioStreamBasicDescription streamFormat;
    UInt32 propertySize = sizeof (streamFormat);
    CheckError(AudioUnitGetProperty(self.effectUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &streamFormat, &propertySize), "13");
    CheckError(AudioUnitSetProperty(self.filePlayerUnit,
                                    kAudioUnitProperty_StreamFormat,
                                    kAudioUnitScope_Output,
                                    busZero,
                                    &streamFormat,
                                    sizeof(streamFormat)),
               "couldn't set stream format on file player bus 0 output");
    CheckError(AudioUnitSetProperty(self.ioUnit,
                                    kAudioUnitProperty_StreamFormat,
                                    kAudioUnitScope_Input,
                                    busZero,
                                    &streamFormat,
                                    sizeof(streamFormat)),
               "couldn't set stream format on iounit bus 0 input");
    
    // make connections
    CheckError(AUGraphConnectNodeInput(self.auGraph, filePlayerNode, 0, effectNode, 0), "14");
    CheckError(AUGraphConnectNodeInput(self.auGraph, effectNode, 0, ioNode, 0), "15");

    // initialize
    CheckError(AUGraphInitialize(self.auGraph), "Couldn't initialize AUGraph");
    
    CFURLRef audioFileURL = CFBridgingRetain(assetURL);
    AudioFileID audioFile;
    CheckError(AudioFileOpenURL(audioFileURL, kAudioFileReadPermission, kAudioFileCAFType, &audioFile), "Couldn't open audio file");
    
    AudioStreamBasicDescription fileStreamFormat;
    UInt32 propsize = sizeof (fileStreamFormat);
    CheckError(AudioFileGetProperty(audioFile, kAudioFilePropertyDataFormat, &propertySize, &fileStreamFormat),
               "couldn't get input file's stream format");
    
    CheckError(AudioUnitSetProperty(self.filePlayerUnit,
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
    
    CheckError(AudioUnitSetProperty(self.filePlayerUnit,
                                    kAudioUnitProperty_ScheduledFileRegion,
                                    kAudioUnitScope_Global,
                                    0,
                                    &rgn,
                                    sizeof(rgn)),
               "AudioUnitSetProperty[kAudioUnitProperty_ScheduledFileRegion] failed");
    
    // prime the file player AU with default values
    UInt32 defaultVal = 0;
    CheckError(AudioUnitSetProperty(self.filePlayerUnit,
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
    CheckError(AudioUnitSetProperty(self.filePlayerUnit,
                                    kAudioUnitProperty_ScheduleStartTimeStamp,
                                    kAudioUnitScope_Global,
                                    0,
                                    &startTime,
                                    sizeof(startTime)),
               "AudioUnitSetProperty[kAudioUnitProperty_ScheduleStartTimeStamp]");

    CheckError(AUGraphStart(self.auGraph), "Couldn't start AUGraph");
}

#pragma mark - Action Methods

- (IBAction)chooseSongButtonPressed:(id)sender {
}

- (IBAction)timeSliderChanged:(id)sender {
    [self resetRate];
}

- (IBAction)pitchSliderChanged:(id)sender {
    [self resetPitch];
}

- (IBAction)handleResetTo1Tapped:(id)sender {
    self.timeSlider.value = 5.0; // see math explainer in resetRate
    [self resetRate];
}

@end
