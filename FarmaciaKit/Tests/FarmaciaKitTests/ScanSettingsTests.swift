import Testing
@testable import FarmaciaKit

struct ScanSettingsTests {
    @Test("given defaults, should read EAN-13, EAN-8, UPC-E, Code 128 and Code 39 (no QR, Code 93, ITF-14)")
    func defaultSymbologies() {
        // Code 39: some store labels use it (124111SP lip balm); the old scanner read it.
        #expect(ScanSettings().symbologies == [.ean13, .ean8, .upce, .code128, .code39])
    }

    @Test("given defaults, should use the brief's thresholds, with minConfidence tuned to 0.7 on device")
    func defaults() {
        let s = ScanSettings()
        #expect(s.minConfidence == 0.7)
        #expect(s.votesRequired == 2)
        #expect(s.voteWindow == 10)
        #expect(s.cooldown == 1.5)
        #expect(s.scanBoxWidth == 0.8 && s.scanBoxHeight == 0.3)
        #expect(s.targetCodeWidthMM == 35)
        #expect(s.camera == .wide && s.preset == .hd1080 && s.fps == 30)
    }

    @Test("given votes required outside 2–3, should clamp", arguments: [(1, 2), (2, 2), (3, 3), (5, 3)])
    func clampsVotes(set: Int, expected: Int) {
        var s = ScanSettings()
        s.votesRequired = set
        #expect(s.votesRequired == expected)
    }

    @Test("given camera, preset and votes, should tag metrics rows with them", arguments: [
        (ScanSettings.Camera.wide, ScanSettings.Preset.hd1080, 2, "wide-1080-v2"),
        (.triple, .hd4K, 3, "triple-4k-v3"),
    ])
    func tag(camera: ScanSettings.Camera, preset: ScanSettings.Preset, votes: Int, expected: String) {
        var s = ScanSettings()
        s.camera = camera
        s.preset = preset
        s.votesRequired = votes
        #expect(s.tag == expected)
    }
}
