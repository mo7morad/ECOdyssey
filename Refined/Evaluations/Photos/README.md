# Labelled photo set

Drop photos of real waste in here. The file name is the label:

```
<binID>__<anything>.jpg
```

for example

```
anorganik__botol-air-mineral.jpg
organik__kulit-pisang.jpg
residu__gelas-kopi-berlapis.jpg
b3__baterai-aa.jpg
```

`.jpg`, `.jpeg`, `.png` and `.heic` are read; anything else here is ignored, so this
file and any notes you leave are harmless.

Valid bin IDs come from `DefaultRuleset.json` — currently `organik`, `anorganik`, `b3`
and `residu`. A photo labelled with anything else fails `labelsResolveToRealBins`, which
is there to catch labels left over from an older ruleset.

## What to photograph

Aim for the cases that decide whether the station is actually useful, not the easy ones:

- **Hazards**, because `HazardRecall` is asserted at 1.0: baterai, power bank, vape,
  lampu, kaleng aerosol, obat, kabel/charger.
- **The look-alikes**: gelas kopi berlapis plastik (looks like paper, is not), struk
  belanja (thermal, not paper), gelas plastik bening vs kaca, sedotan.
- **Dirty and messy**, since that is what a real bin sees: kotak makan with rice still
  in it, nasi bungkus, kardus pizza berminyak, a half-full bottle.
- **The Bali-banned three**: kantong plastik, styrofoam, sedotan plastik.
- **Ordinary items too** — without them `FalseHazard` and overall accuracy measure
  nothing, and a station that calls everything hazardous is its own failure.

Photograph them the way the station sees them: held up at arm's length, against the
background the kiosk actually has, in the light it actually has. A dataset shot cleanly
on a white desk will score well and tell you nothing.

Twenty to thirty photos is enough to start and enough to expose real problems. Run the
`Bin routing evaluation` suite on a device — never the simulator, which has no
Apple Intelligence — and write the numbers down before changing any prompt or rule.
