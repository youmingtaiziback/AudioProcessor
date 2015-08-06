/*
    File: AUGraphController.mm
Abstract: Sets up the AUGraph, loading up the audio data using ExtAudioFile, the input render procedure and so on.
 Version: 1.2.2

*/

#import "AUGraphController.h"

const Float64 kGraphSampleRate = 44100.0;

static void SilenceData(AudioBufferList *inData) {
	for (UInt32 i=0; i < inData->mNumberBuffers; i++)
		memset(inData->mBuffers[i].mData, 0, inData->mBuffers[i].mDataByteSize);
}

// audio render procedure to render our client data format
// 2 ch 'lpcm' 16-bit little-endian signed integer interleaved this is mClientFormat data, see CAStreamBasicDescription SetCanonical()
static OSStatus renderInput(void *inRefCon,
                            AudioUnitRenderActionFlags *ioActionFlags,
                            const AudioTimeStamp *inTimeStamp,
                            UInt32 inBusNumber,
                            UInt32 inNumberFrames,
                            AudioBufferList *ioData) {
    SourceAudioBufferDataPtr userData = (SourceAudioBufferDataPtr)inRefCon;
    AudioSampleType *in = userData->soundBuffer[inBusNumber].data;
    AudioSampleType *out = (AudioSampleType *)ioData->mBuffers[0].mData;
    UInt32 sample = userData->frameNum * userData->soundBuffer[inBusNumber].asbd.mChannelsPerFrame;
    
    // make sure we don't attempt to render more data than we have available in the source buffers
    // if one buffer is larger than the other, just render silence for that bus until we loop around again
    if ((userData->frameNum + inNumberFrames) > userData->soundBuffer[inBusNumber].numFrames) {
        UInt32 offset = (userData->frameNum + inNumberFrames) - userData->soundBuffer[inBusNumber].numFrames;
        if (offset < inNumberFrames) {
            // copy the last bit of source
            SilenceData(ioData);
            memcpy(out, &in[sample], ((inNumberFrames - offset) * userData->soundBuffer[inBusNumber].asbd.mBytesPerFrame));
            return noErr;
        }
        else {
            // we have no source data
            SilenceData(ioData);
            *ioActionFlags |= kAudioUnitRenderAction_OutputIsSilence;
            return noErr;
        }
    }
	
    memcpy(out, &in[sample], ioData->mBuffers[0].mDataByteSize);
    return noErr;
}

// the render notification is used to keep track of the frame number position in the source audio
static OSStatus renderNotification(void *inRefCon,
                                   AudioUnitRenderActionFlags *ioActionFlags,
                                   const AudioTimeStamp *inTimeStamp,
                                   UInt32 inBusNumber,
                                   UInt32 inNumberFrames,
                                   AudioBufferList *ioData) {
    SourceAudioBufferDataPtr userData = (SourceAudioBufferDataPtr)inRefCon;
    if (*ioActionFlags & kAudioUnitRenderAction_PostRender) {
        userData->frameNum += inNumberFrames;
        if (userData->frameNum >= userData->maxNumFrames) {
            userData->frameNum = 0;
        }
    }
    return noErr;
}

@implementation AUGraphController
@synthesize mIsPlaying;

#pragma mark - Life Cycle

- (void)awakeFromNib {
    mIsPlaying = false;
    
    // clear the mSoundBuffer struct
    memset(&mUserData.soundBuffer, 0, sizeof(mUserData.soundBuffer));
    
    // create the URLs we'll use for source A and B
    NSString *sourceA = [[NSBundle mainBundle] pathForResource:@"Track1" ofType:@"mp4"];
    NSString *sourceB = [[NSBundle mainBundle] pathForResource:@"Track2" ofType:@"mp4"];
    sourceURL[0] = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (CFStringRef)sourceA, kCFURLPOSIXPathStyle, false);
    sourceURL[1] = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (CFStringRef)sourceB, kCFURLPOSIXPathStyle, false);
}

- (void)dealloc {
    DisposeAUGraph(mGraph);
    free(mUserData.soundBuffer[0].data);
    free(mUserData.soundBuffer[1].data);
    CFRelease(sourceURL[0]);
    CFRelease(sourceURL[1]);
	[super dealloc];
}

#pragma mark - Public Methods

- (void)initializeAUGraph {
    // client format audio goes into the mixer
    mClientFormat.SetCanonical(2, true);
    mClientFormat.mSampleRate = kGraphSampleRate;
    
    // output format
    mOutputFormat.SetAUCanonical(2, false);
    mOutputFormat.mSampleRate = kGraphSampleRate;
    
    // load up the audio data
    [self loadFiles];
    
    OSStatus result = noErr;
    // create a new AUGraph
    if (NewAUGraph(&mGraph))
        return;
    
    // create three Audio Component Descriptons for the AUs we want in the graph using the CAComponentDescription helper class
    // output unit
    CAComponentDescription output_desc(kAudioUnitType_Output, kAudioUnitSubType_RemoteIO, kAudioUnitManufacturer_Apple);
    // iPodEQ unit
    CAComponentDescription eq_desc(kAudioUnitType_Effect, kAudioUnitSubType_Reverb2, kAudioUnitManufacturer_Apple);
    // convert unit
    AudioComponentDescription convertUnitDescription;
    convertUnitDescription.componentManufacturer  = kAudioUnitManufacturer_Apple;
    convertUnitDescription.componentType          = kAudioUnitType_FormatConverter;
    convertUnitDescription.componentSubType       = kAudioUnitSubType_NewTimePitch;
    convertUnitDescription.componentFlags         = 0;
    convertUnitDescription.componentFlagsMask     = 0;
    // multichannel mixer unit
    CAComponentDescription mixer_desc(kAudioUnitType_Mixer, kAudioUnitSubType_MultiChannelMixer, kAudioUnitManufacturer_Apple);
    
    AUNode outputNode;
    AUNode eqNode;
    AUNode converterNode;
    AUNode mixerNode;
    // create a node in the graph that is an AudioUnit, using the supplied AudioComponentDescription to find and open that unit
    if (AUGraphAddNode(mGraph, &output_desc, &outputNode))
        return;
    if (AUGraphAddNode(mGraph, &eq_desc, &eqNode))
        return;
    if (AUGraphAddNode(mGraph, &convertUnitDescription, &converterNode))
        return;
    if (AUGraphAddNode(mGraph, &mixer_desc, &mixerNode))
        return;
    
    // connect a node's output to a node's input
    // mixer -> eq -> output
    if (AUGraphConnectNodeInput(mGraph, mixerNode, 0, converterNode, 0))
        return;
    if (AUGraphConnectNodeInput(mGraph, converterNode, 0, eqNode, 0))
        return;
    if (AUGraphConnectNodeInput(mGraph, eqNode, 0, outputNode, 0))
        return;
    
    // open the graph AudioUnits are open but not initialized (no resource allocation occurs here)
    if (AUGraphOpen(mGraph))
        return;
    
    // grab the audio unit instances from the nodes
    if (AUGraphNodeInfo(mGraph, mixerNode, NULL, &mMixer))
        return;
    if (AUGraphNodeInfo(mGraph, converterNode, NULL, &mConverter))
        return;
    if (AUGraphNodeInfo(mGraph, eqNode, NULL, &mEQ))
        return;
    
    // config audio unit
    // set bus count
    UInt32 numbuses = 2;
    if (AudioUnitSetProperty(mMixer, kAudioUnitProperty_ElementCount, kAudioUnitScope_Input, 0, &numbuses, sizeof(numbuses)))
        return;
    
    for (UInt32 i = 0; i < numbuses; ++i) {
        // setup render callback struct
        AURenderCallbackStruct rcbs;
        rcbs.inputProc = &renderInput;
        rcbs.inputProcRefCon = &mUserData;
        
        // set a callback for the specified node's specified input
        result = AUGraphSetNodeInputCallback(mGraph, mixerNode, i, &rcbs);
        if (result)
            return;
        
        // set the input stream format, this is the format of the audio for mixer input
        result = AudioUnitSetProperty(mMixer, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, i, &mClientFormat, sizeof(mClientFormat));
        if (result)
            return;
    }
    
    // set the output stream format of the mixer
    result = AudioUnitSetProperty(mMixer, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &mOutputFormat, sizeof(mOutputFormat));
    if (result)
        return;
    
    // add a render notification, this is a callback that the graph will call every time the graph renders
    // the callback will be called once before the graph’s render operation, and once after the render operation is complete
    result = AUGraphAddRenderNotify(mGraph, renderNotification, &mUserData);
    if (result)
        return;
    
    // now that we've set everything up we can initialize the graph, this will also validate the connections
    result = AUGraphInitialize(mGraph);
    if (result)
        return;
    
    CAShow(mGraph);
}

// enable or disables a specific bus
- (void)enableInput:(UInt32)inputNum isOn:(AudioUnitParameterValue)isONValue {
    OSStatus result = AudioUnitSetParameter(mMixer, kMultiChannelMixerParam_Enable, kAudioUnitScope_Input, inputNum, isONValue, 0);
    if (result)
        return;
}

// sets the input volume for a specific bus
- (void)setInputVolume:(UInt32)inputNum value:(AudioUnitParameterValue)value {
    OSStatus result = AudioUnitSetParameter(mMixer, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, inputNum, value, 0);
    if (result)
        return;
}

// sets the overall mixer output volume
- (void)setOutputVolume:(AudioUnitParameterValue)value {
    OSStatus result;
//    result = AudioUnitSetParameter(mMixer, kMultiChannelMixerParam_Volume, kAudioUnitScope_Output, 0, value, 0);
//    result = AudioUnitSetParameter(mEQ, kReverb2Param_DryWetMix, kAudioUnitScope_Global, 0, value * 100,0);
//    result = AudioUnitSetParameter(mEQ, kReverb2Param_Gain, kAudioUnitScope_Global, 0, (value - .5) * 40, 0);
    result = AudioUnitSetParameter(mConverter, kNewTimePitchParam_Pitch, kAudioUnitScope_Global, 0, (value - .5) * 4800, 0);
    if (result != noErr)
        NSAssert1(NO, @"%d", result);
}

// stars render
- (void)startAUGraph {
    OSStatus result = AUGraphStart(mGraph);
    if (result)
        return;
    mIsPlaying = true;
}

// stops render
- (void)stopAUGraph {
    Boolean isRunning = false;
    OSStatus result = AUGraphIsRunning(mGraph, &isRunning);
    if (result)
        return;
    if (isRunning) {
        result = AUGraphStop(mGraph);
        if (result)
            return;
        mIsPlaying = false;
    }
}

#pragma mark - Private Methods

// load up audio data from the demo files into mSoundBuffer.data used in the render proc
- (void)loadFiles {
    mUserData.frameNum = 0;
    mUserData.maxNumFrames = 0;
    
    for (int i = 0; i < NUMFILES && i < MAXBUFS; i++)  {
        ExtAudioFileRef xafref = 0;
        // open one of the two source files
        OSStatus result = ExtAudioFileOpenURL(sourceURL[i], &xafref);
        if (result || 0 == xafref) {
            printf("ExtAudioFileOpenURL result %ld %08X %4.4s\n", result, (unsigned int)result, (char*)&result);
            return;
        }
        
        // get the file data format, this represents the file's actual data format
        // for informational purposes only -- the client format set on ExtAudioFile is what we really want back
        CAStreamBasicDescription fileFormat;
        UInt32 propSize = sizeof(fileFormat);
        result = ExtAudioFileGetProperty(xafref, kExtAudioFileProperty_FileDataFormat, &propSize, &fileFormat);
        if (result) { printf("ExtAudioFileGetProperty kExtAudioFileProperty_FileDataFormat result %ld %08X %4.4s\n", result, (unsigned int)result, (char*)&result); return; }
        
        // set the client format to be what we want back
        // this is the same format audio we're giving to the the mixer input
        result = ExtAudioFileSetProperty(xafref, kExtAudioFileProperty_ClientDataFormat, sizeof(mClientFormat), &mClientFormat);
        if (result) { printf("ExtAudioFileSetProperty kExtAudioFileProperty_ClientDataFormat %ld %08X %4.4s\n", result, (unsigned int)result, (char*)&result); return; }
        
        // get the file's length in sample frames
        UInt64 numFrames = 0;
        propSize = sizeof(numFrames);
        result = ExtAudioFileGetProperty(xafref, kExtAudioFileProperty_FileLengthFrames, &propSize, &numFrames);
        if (result || numFrames == 0) { printf("ExtAudioFileGetProperty kExtAudioFileProperty_FileLengthFrames result %ld %08X %4.4s\n", result, (unsigned int)result, (char*)&result); return; }
        
        // keep track of the largest number of source frames
        if (numFrames > mUserData.maxNumFrames)
            mUserData.maxNumFrames = numFrames;
        
        // set up our buffer
        mUserData.soundBuffer[i].numFrames = numFrames;
        mUserData.soundBuffer[i].asbd = mClientFormat;
        
        UInt32 samples = numFrames * mUserData.soundBuffer[i].asbd.mChannelsPerFrame;
        mUserData.soundBuffer[i].data = (AudioSampleType *)calloc(samples, sizeof(AudioSampleType));
        
        // set up a AudioBufferList to read data into
        AudioBufferList bufList;
        bufList.mNumberBuffers = 1;
        bufList.mBuffers[0].mNumberChannels = mUserData.soundBuffer[i].asbd.mChannelsPerFrame;
        bufList.mBuffers[0].mData = mUserData.soundBuffer[i].data;
        bufList.mBuffers[0].mDataByteSize = samples * sizeof(AudioSampleType);
        
        // perform a synchronous sequential read of the audio data out of the file into our allocated data buffer
        UInt32 numPackets = numFrames;
        result = ExtAudioFileRead(xafref, &numPackets, &bufList);
        if (result) {
            printf("ExtAudioFileRead result %ld %08X %4.4s\n", result, (unsigned int)result, (char*)&result);
            free(mUserData.soundBuffer[i].data);
            mUserData.soundBuffer[i].data = 0;
            return;
        }
        
        // close the file and dispose the ExtAudioFileRef
        ExtAudioFileDispose(xafref);
    }
}

@end