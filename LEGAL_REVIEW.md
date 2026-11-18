# Legal review: barcode scanner

These are open questions for a lawyer to check. They are not legal conclusions.
Plan: `tasks/barcode-scanner-epic.md`.

## Ground rules followed

- Only Apple frameworks, our own code and permissively licensed open source (see
  `THIRD_PARTY_NOTICES`).
- No code from, or inspection of, Scandit, Dynamsoft, barKoder, Scanbot or any other
  commercial SDK.
- Three Scandit patent families are avoided on purpose:
  - **US 11893764**: projecting several scanlines and stitching "usable segments" to
    decode damaged codes.
  - **US 11244147**: detecting a region of interest in one image, then auto-zooming the
    camera into it to capture and decode a second image.
  - **US 11087105**: a focus/exposure control loop that detects a code at one focal
    position before decoding.

## Stage 1: why each part is believed not to overlap

| Part | What it does | Why it's believed clear |
|---|---|---|
| Startup zoom (`StartupZoom`) | Sets `videoZoomFactor` **once** when the camera starts, from the lens's `minimumFocusDistance` and a target code width, as in Apple's AVCamBarcode sample | It never reacts to a detection and never captures a second image (11244147) |
| Focus / exposure | Continuous auto focus and exposure, with a fixed point of interest at the scan-box center; `.near` range restriction | It's the system's own autofocus. There is no loop of ours that detects a code at a focal position (11087105) |
| Region of interest | A fixed scan box on screen, passed to Vision as `regionOfInterest` | It's fixed by the UI, not detected from a first image (11244147) |
| Decoding | Apple Vision `VNDetectBarcodesRequest` | We do no scanline work of our own (11893764) |
| Validation | GS1 mod-10 check digit, length and charset checks | Public GS1 standard |
| Multi-frame voting | Accept a value once it has been read N times in the last K frames, then a cooldown | A generic, long-established technique |

## Stage 2: to review before shipping

- [ ] **Preprocessing retry** (brief step 8). It re-runs Vision on Core Image variants
      of the *fixed* scan-box crop. Confirm that a digital crop of a fixed region, run on
      some frames, is clear of 11244147, which describes detecting a region and then
      zooming the camera.
- [ ] **ZXing-cpp fallback** (brief step 11, Apache-2.0). Its 1D readers scan several
      rows (`TryHarder`). Confirm that this row-by-row decoding plus agreement is not the
      "stitch usable segments" method of 11893764.
- [ ] **Torch suggestion / exposure bias** (brief step 10). The bias is a fixed user
      setting and the torch suggestion comes from mean brightness. Confirm that neither
      counts as the control loop in 11087105.
