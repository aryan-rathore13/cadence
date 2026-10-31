import XCTest
import AudioDSP
import CoreAudio
@testable import Cadence

final class AudioDSPTests: XCTestCase {
    private func render(_ samples: [Float], state: OpaquePointer, outputCount: Int? = nil) -> [Float] {
        var input = samples
        var output = [Float](repeating: 99, count: outputCount ?? samples.count)
        input.withUnsafeMutableBytes { source in
            output.withUnsafeMutableBytes { destination in
                var inList = AudioBufferList(mNumberBuffers: 1, mBuffers: AudioBuffer(mNumberChannels: 2, mDataByteSize: UInt32(source.count), mData: source.baseAddress))
                var outList = AudioBufferList(mNumberBuffers: 1, mBuffers: AudioBuffer(mNumberChannels: 2, mDataByteSize: UInt32(destination.count), mData: destination.baseAddress))
                var time = AudioTimeStamp()
                withUnsafePointer(to: &time) { stamp in
                    _ = cadence_audio_callback(0, stamp, &inList, stamp, &outList, stamp, UnsafeMutableRawPointer(state))
                }
            }
        }
        return output
    }

    func testAppliesExactGainAndReportsPeak() {
        let state = cadence_dsp_create(0.25)!
        defer { cadence_dsp_destroy(state) }
        let output = render([1, -1, 0.5, -0.5], state: state)
        XCTAssertEqual(output, [0.25, -0.25, 0.125, -0.125])
        XCTAssertEqual(cadence_dsp_peak(state), 1)
        XCTAssertEqual(cadence_dsp_output_peak(state), 0.25)
        XCTAssertEqual(cadence_dsp_peak(state), 0)
        XCTAssertEqual(cadence_dsp_callbacks(state), 1)
    }

    func testMuteRampsThenProducesSilence() {
        let state = cadence_dsp_create(1)!
        defer { cadence_dsp_destroy(state) }
        cadence_dsp_set_gain(state, 0)
        let ramp = render([1, 1, 1, 1], state: state)
        XCTAssertEqual(ramp, [0.75, 0.5, 0.25, 0])
        XCTAssertEqual(render([1, -1, 1, -1], state: state), [0, 0, 0, 0])
    }

    func testNonfiniteInputAndShortBufferAreSafe() {
        let state = cadence_dsp_create(1)!
        defer { cadence_dsp_destroy(state) }
        XCTAssertEqual(render([.nan, .infinity, -.infinity, 0.5], state: state, outputCount: 6), [0, 0, 0, 0.5, 0, 0])
    }

    func testGainCannotAmplifyOrInvert() {
        let state = cadence_dsp_create(1)!
        defer { cadence_dsp_destroy(state) }
        cadence_dsp_set_gain(state, 10)
        XCTAssertEqual(render([0.5, -0.5], state: state), [0.5, -0.5])
        cadence_dsp_set_gain(state, -1)
        _ = render([1, 1], state: state)
        XCTAssertEqual(render([1, 1], state: state), [0, 0])
    }

    func testPhysicalInputsAreNeverRendered() {
        let state = cadence_dsp_create(1)!
        defer { cadence_dsp_destroy(state) }
        let raw = UnsafeMutableRawPointer.allocate(byteCount: MemoryLayout<AudioBufferList>.size + MemoryLayout<AudioBuffer>.size, alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { raw.deallocate() }
        let list = raw.bindMemory(to: AudioBufferList.self, capacity: 1)
        list.pointee.mNumberBuffers = 2
        let buffers = UnsafeMutableAudioBufferListPointer(list)
        var microphone: [Float] = [0.9, 0.9]
        var tap: [Float] = [0.2, -0.2]
        var output: [Float] = [0, 0]
        microphone.withUnsafeMutableBytes { mic in
            tap.withUnsafeMutableBytes { source in
                output.withUnsafeMutableBytes { destination in
                    buffers[0] = AudioBuffer(mNumberChannels: 2, mDataByteSize: UInt32(mic.count), mData: mic.baseAddress)
                    buffers[1] = AudioBuffer(mNumberChannels: 2, mDataByteSize: UInt32(source.count), mData: source.baseAddress)
                    var outList = AudioBufferList(mNumberBuffers: 1, mBuffers: AudioBuffer(mNumberChannels: 2, mDataByteSize: UInt32(destination.count), mData: destination.baseAddress))
                    var time = AudioTimeStamp()
                    withUnsafePointer(to: &time) { stamp in
                        _ = cadence_audio_callback(0, stamp, list, stamp, &outList, stamp, UnsafeMutableRawPointer(state))
                    }
                }
            }
        }
        XCTAssertEqual(output, [0.2, -0.2])
        XCTAssertEqual(cadence_dsp_peak(state), 0.2)
    }

    func testSavedChannelSettingsClampAndRoundTrip() throws {
        var settings = ChannelSettings(volume: 5, muted: false)
        XCTAssertEqual(settings.gain, 1)
        settings.volume = -2
        XCTAssertEqual(settings.gain, 0)
        settings.volume = 0.4
        settings.muted = true
        XCTAssertEqual(settings.gain, 0)
        let data = try JSONEncoder().encode(settings)
        XCTAssertEqual(try JSONDecoder().decode(ChannelSettings.self, from: data), settings)
    }

    func testHelpersResolveToOutermostApplication() {
        let helper = URL(fileURLWithPath: "/Applications/Browser.app/Contents/Frameworks/Helper.app/Contents/MacOS/Helper")
        XCTAssertEqual(Hardware.outerApplication(helper)?.path, "/Applications/Browser.app")
        XCTAssertNil(Hardware.outerApplication(URL(fileURLWithPath: "/usr/bin/afplay")))
    }
}
