#pragma once
#include <CoreAudio/CoreAudio.h>

typedef struct CadenceDSP CadenceDSP;
CadenceDSP * _Nullable cadence_dsp_create(float gain);
void cadence_dsp_destroy(CadenceDSP * _Nonnull state);
void cadence_dsp_set_gain(CadenceDSP * _Nonnull state, float gain);
float cadence_dsp_peak(CadenceDSP * _Nonnull state);
float cadence_dsp_output_peak(CadenceDSP * _Nonnull state);
uint64_t cadence_dsp_callbacks(CadenceDSP * _Nonnull state);
OSStatus cadence_prepare_input(AudioObjectID device, AudioDeviceIOProcID _Nonnull proc,
    CadenceDSP * _Nonnull state, UInt32 tapBuffers);
OSStatus cadence_audio_callback(AudioObjectID device, const AudioTimeStamp * _Nonnull now,
    const AudioBufferList * _Nonnull input, const AudioTimeStamp * _Nonnull inputTime,
    AudioBufferList * _Nonnull output, const AudioTimeStamp * _Nonnull outputTime, void * _Nullable context);
