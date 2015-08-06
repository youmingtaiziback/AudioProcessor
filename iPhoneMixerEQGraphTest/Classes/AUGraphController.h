/*
     File: AUGraphController.h
 Abstract: Sets up the AUGraph, loading up the audio data using ExtAudioFile, the input render procedure and so on.
  Version: 1.2.2
 
 */

#import <CoreFoundation/CoreFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AudioUnit/AudioUnit.h>

#import "CAStreamBasicDescription.h"
#import "CAComponentDescription.h"

#define MAXBUFS  2
#define NUMFILES 2

typedef struct {
    AudioStreamBasicDescription asbd;
    AudioSampleType *data;
	UInt32 numFrames;
} SoundBuffer, *SoundBufferPtr;

typedef struct {
	UInt32 frameNum;
    UInt32 maxNumFrames;
    SoundBuffer soundBuffer[MAXBUFS];
} SourceAudioBufferData, *SourceAudioBufferDataPtr;

@interface AUGraphController : NSObject
{
    CFURLRef sourceURL[2];
	AUGraph   mGraph;
    AudioUnit mEQ;
    AudioUnit mConverter;
	AudioUnit mMixer;
    CAStreamBasicDescription mClientFormat;
    CAStreamBasicDescription mOutputFormat;
    CFArrayRef mEQPresetsArray;
    SourceAudioBufferData mUserData;
	Boolean mIsPlaying;
}

@property (readonly, nonatomic, getter=isPlaying) Boolean mIsPlaying;
@property (readonly, nonatomic, getter=iPodEQPresetsArray) CFArrayRef mEQPresetsArray;

- (void)initializeAUGraph;
- (void)enableInput:(UInt32)inputNum isOn:(AudioUnitParameterValue)isONValue;
- (void)setInputVolume:(UInt32)inputNum value:(AudioUnitParameterValue)value;
- (void)setOutputVolume:(AudioUnitParameterValue)value;
- (void)startAUGraph;
- (void)stopAUGraph;
@end
