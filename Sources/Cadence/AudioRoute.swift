import CoreAudio
import AudioDSP

/// Owns one application's tap, private output aggregate, and real-time gain state.
/// Lifecycle runs on the main thread; only the C callback touches audio buffers.
final class AudioRoute {
    let processIDs: [AudioObjectID]
    private var tap: AudioObjectID = 0
    private var aggregate: AudioObjectID = 0
    private var ioProc: AudioDeviceIOProcID?
    private var state: OpaquePointer?

    init(processIDs: [AudioObjectID], output: OutputDevice, gain: Float) throws {
        self.processIDs = processIDs.sorted()
        guard let state = cadence_dsp_create(gain) else {
            throw AudioFailure(operation: "Allocate audio state", status: -108)
        }
        self.state = state
        do {
            // A device-specific tap preserves the physical output stream's layout.
            let description = CATapDescription(__processes: processIDs.map { NSNumber(value: $0) }, andDeviceUID: output.uid, withStream: 0)
            description.name = "Cadence application audio"
            description.uuid = UUID()
            description.isPrivate = true
            description.muteBehavior = .mutedWhenTapped
            try Hardware.check(AudioHardwareCreateProcessTap(description, &tap), "Create application audio tap")
            let format = try Hardware.number(tap, kAudioTapPropertyFormat, initial: AudioStreamBasicDescription())
            guard format.mFormatID == kAudioFormatLinearPCM,
                  format.mFormatFlags & kAudioFormatFlagIsFloat != 0,
                  format.mBitsPerChannel == 32 else {
                throw AudioFailure(operation: "This output does not expose 32-bit float audio", status: kAudioHardwareUnsupportedOperationError)
            }
            let config: [String: Any] = [
                kAudioAggregateDeviceNameKey: "Cadence · application route",
                kAudioAggregateDeviceUIDKey: "com.aryanrathore.cadence.\(UUID().uuidString)",
                kAudioAggregateDeviceIsPrivateKey: true,
                kAudioAggregateDeviceIsStackedKey: false,
                kAudioAggregateDeviceMainSubDeviceKey: output.uid,
                kAudioAggregateDeviceSubDeviceListKey: [[
                    kAudioSubDeviceUIDKey: output.uid,
                    kAudioSubDeviceInputChannelsKey: 0
                ]],
                kAudioAggregateDeviceTapListKey: [[
                    kAudioSubTapUIDKey: description.uuid.uuidString,
                    kAudioSubTapDriftCompensationKey: true
                ]],
                kAudioAggregateDeviceTapAutoStartKey: false
            ]
            try Hardware.check(AudioHardwareCreateAggregateDevice(config as CFDictionary, &aggregate), "Create private audio route")
            try Hardware.check(AudioDeviceCreateIOProcID(aggregate, cadence_audio_callback, UnsafeMutableRawPointer(state), &ioProc), "Attach audio renderer")
            let tapBuffers: UInt32 = format.mFormatFlags & kAudioFormatFlagIsNonInterleaved != 0 ? format.mChannelsPerFrame : 1
            if let ioProc {
                try Hardware.check(cadence_prepare_input(aggregate, ioProc, state, tapBuffers), "Disable physical audio inputs")
            }
            try Hardware.check(AudioDeviceStart(aggregate, ioProc), "Start application audio")
        } catch {
            stop()
            throw error
        }
    }

    func setGain(_ value: Float) {
        if let state { cadence_dsp_set_gain(state, value) }
    }

    func takePeak() -> Float { state.map(cadence_dsp_peak) ?? 0 }
    func takeOutputPeak() -> Float { state.map(cadence_dsp_output_peak) ?? 0 }
    var callbackCount: UInt64 { state.map(cadence_dsp_callbacks) ?? 0 }

    func stop() {
        if aggregate != 0 {
            if let ioProc {
                AudioDeviceStop(aggregate, ioProc)
                AudioDeviceDestroyIOProcID(aggregate, ioProc)
            }
            ioProc = nil
            AudioHardwareDestroyAggregateDevice(aggregate)
            aggregate = 0
        }
        if tap != 0 {
            AudioHardwareDestroyProcessTap(tap)
            tap = 0
        }
        if let state { cadence_dsp_destroy(state) }
        state = nil
    }

    deinit { stop() }
}
