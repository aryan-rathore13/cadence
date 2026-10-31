#include "AudioDSP.h"
#include <stdatomic.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>
#include <stddef.h>

struct CadenceDSP {
    _Atomic(float) target;
    _Atomic(float) peak;
    _Atomic(float) outputPeak;
    _Atomic(uint64_t) callbacks;
    float current;
    UInt32 tapBuffers;
};

CadenceDSP *cadence_dsp_create(float gain) {
    CadenceDSP *state = calloc(1, sizeof(CadenceDSP));
    if (!state) return NULL;
    atomic_init(&state->target, gain);
    atomic_init(&state->peak, 0);
    atomic_init(&state->outputPeak, 0);
    atomic_init(&state->callbacks, 0);
    state->current = gain;
    state->tapBuffers = 1;
    return state;
}
void cadence_dsp_destroy(CadenceDSP *state) { free(state); }
void cadence_dsp_set_gain(CadenceDSP *state, float gain) {
    atomic_store_explicit(&state->target, fminf(1, fmaxf(0, gain)), memory_order_relaxed);
}
float cadence_dsp_peak(CadenceDSP *state) {
    return atomic_exchange_explicit(&state->peak, 0, memory_order_relaxed);
}
uint64_t cadence_dsp_callbacks(CadenceDSP *state) {
    return atomic_load_explicit(&state->callbacks, memory_order_relaxed);
}
float cadence_dsp_output_peak(CadenceDSP *state) {
    return atomic_exchange_explicit(&state->outputPeak, 0, memory_order_relaxed);
}

// Configure before starting IO: disable physical inputs, enabling only the tap.
OSStatus cadence_prepare_input(AudioObjectID device, AudioDeviceIOProcID proc,
    CadenceDSP *state, UInt32 tapBuffers) {
    state->tapBuffers = tapBuffers;
    AudioObjectPropertyAddress key = { kAudioDevicePropertyStreams,
        kAudioObjectPropertyScopeInput, kAudioObjectPropertyElementMain };
    UInt32 bytes = 0;
    OSStatus status = AudioObjectGetPropertyDataSize(device, &key, 0, NULL, &bytes);
    if (status) return status;
    UInt32 streams = bytes / sizeof(AudioObjectID);
    if (streams == 0) return kAudioHardwareBadStreamError;
    if (streams == 1) return noErr;
    bytes = (UInt32)(offsetof(AudioHardwareIOProcStreamUsage, mStreamIsOn) + streams * sizeof(UInt32));
    AudioHardwareIOProcStreamUsage *usage = calloc(1, bytes);
    if (!usage) return kAudioHardwareUnspecifiedError;
    usage->mIOProc = (void *)proc;
    usage->mNumberStreams = streams;
    usage->mStreamIsOn[streams - 1] = 1;
    key.mSelector = kAudioDevicePropertyIOProcStreamUsage;
    status = AudioObjectSetPropertyData(device, &key, 0, NULL, bytes, usage);
    free(usage);
    return status;
}

// No locks, allocations, logging, Objective-C, or Swift on the real-time thread.
OSStatus cadence_audio_callback(AudioObjectID device, const AudioTimeStamp *now,
    const AudioBufferList *input, const AudioTimeStamp *inputTime,
    AudioBufferList *output, const AudioTimeStamp *outputTime, void *context) {
    CadenceDSP *state = context;
    float target = atomic_load_explicit(&state->target, memory_order_relaxed);
    float peak = 0;
    float outputPeak = 0;
    // Tap buffers follow physical inputs. Never read a physical input buffer.
    UInt32 offset = input->mNumberBuffers >= state->tapBuffers ? input->mNumberBuffers - state->tapBuffers : 0;
    for (UInt32 b = 0; b < output->mNumberBuffers; b++) {
        AudioBuffer *dst = &output->mBuffers[b];
        if (!dst->mData) continue;
        memset(dst->mData, 0, dst->mDataByteSize);
        if (b >= state->tapBuffers || offset + b >= input->mNumberBuffers || !input->mBuffers[offset + b].mData) continue;
        const AudioBuffer *src = &input->mBuffers[offset + b];
        UInt32 count = (src->mDataByteSize < dst->mDataByteSize ? src->mDataByteSize : dst->mDataByteSize) / sizeof(float);
        const float *in = src->mData;
        float *out = dst->mData;
        float gain = state->current;
        // Smooth over one buffer to avoid discontinuities when moving a fader.
        float step = count ? (target - gain) / count : 0;
        for (UInt32 i = 0; i < count; i++) {
            gain += step;
            float sample = isfinite(in[i]) ? in[i] : 0;
            out[i] = sample * gain;
            outputPeak = fmaxf(outputPeak, fabsf(out[i]));
            peak = fmaxf(peak, fabsf(sample));
        }
    }
    state->current = target;
    float old = atomic_load_explicit(&state->peak, memory_order_relaxed);
    while (peak > old && !atomic_compare_exchange_weak_explicit(&state->peak, &old, peak, memory_order_relaxed, memory_order_relaxed)) {}
    old = atomic_load_explicit(&state->outputPeak, memory_order_relaxed);
    while (outputPeak > old && !atomic_compare_exchange_weak_explicit(&state->outputPeak, &old, outputPeak, memory_order_relaxed, memory_order_relaxed)) {}
    atomic_fetch_add_explicit(&state->callbacks, 1, memory_order_relaxed);
    return noErr;
}
