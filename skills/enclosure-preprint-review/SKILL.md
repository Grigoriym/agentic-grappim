---
name: enclosure-preprint-review
description: Review a 3D-printed enclosure model (OpenSCAD) before it's sent to print,
  item by item, for the small fit problems a clash check can't see — screws measured
  not labelled, pilot size and depth against the screw's reach, plastic between holes
  and edges, gaps between mating parts (with screw-hole play), anything that has to
  flex or hook, guessed dimensions doing real work, openings against the part's real
  functional area, tool access, supports. Use before ordering a print, when the user
  asks "are we ready to print", or after a print came back with fit problems.
disable-model-invocation: true
metadata:
  author: grappim
  keywords:
    - 3d printing
    - enclosure
    - openscad
    - fit
---

# Enclosure pre-print review

**Why this exists.** A clash check only finds overlaps. The first printed case
(esp32-mukklet v1, 2026-10-07) passed it and still came back with: screw holes 0.2 mm
from the plate's edge, self-tappers that snapped in too-tight pilots, a pilot shallower
than the screw's reach, a front plate sitting on the strip below it, a snap hook that
didn't catch a board whose thickness was guessed, and a screen window showing the
glass's black border. Each was findable from the model. This list is how to find them
before paying for a print.

Run it **every time** before a print is ordered, not only the first: every model change
can bring one of these back.

## Step 0. Read the project first

- The project's `enclosure/README.md` (layout, parts, its printed-part checklists) and
  `MEASUREMENTS.md` if it has one. Part facts may live elsewhere (on this machine: the
  Homebox inventory, `parts.py show <part>`).
- The shared lessons: `~/proj/grappim/grappim-watcher/docs/esp32/ENCLOSURE_PLAYBOOK.md`.
- Run the project's export/clash check first. Everything below assumes it passes.

## Step 1. Every fastener, one row each

Make a table: screw (as **measured**: thread diameter and length, not the kit's label),
which parts it joins, clearance hole, pilot diameter, pilot depth, how far the screw
reaches into the pilot, plastic between the hole and the nearest edge.

Check each row:
- **Measured, not labelled.** A kit's "M3" self-tapper measured 3.64.
- **Clearance hole ≥ thread + 0.3–0.4.** FDM holes print 0.2–0.4 undersize.
- **Self-tapping pilot ≈ 0.7–0.8 × thread.** 2.3 into 1.9 (0.83) was too tight and two
  hardened screws snapped at the neck; 2.0 into 1.6 (0.8) worked. Hardened small screws
  break rather than strip: keep them on the loose side.
- **Engagement ~2 × thread is plenty** (4 mm for a 2 mm screw). Longer only adds torque.
- **Pilot depth ≥ reach + 1–2 mm.** A tip that bottoms out in solid plastic spikes the
  torque. Compute the reach: screw length − (head seat to the joint).
- **Plastic from the hole to the part's outline ≥ max(2 mm, 0.6 × the hole's
  diameter)**, measured from the hole as it will be drilled if it may be; **≥ 1.2 mm
  round a counterbore**. In **every** part the screw passes: a plate fitted inside walls
  loses the wall thickness here (v1: a 4 mm hole 0.2 mm from the edge).

## Step 2. Every guessed value

List every dimension that wasn't measured (`grep -n ASSUMED` if the model marks them —
it should). For each, either:
- get it measured (one direct measurement, edge to edge), or
- show the design tolerates it being off by the likely error (say ±1 mm), or
- name it as a risk the print will check, with the fallback.

A guess that **positions** something (where a board sits, its thickness under a hook)
is the dangerous kind. A guess that only needs clearance is usually fine.

## Step 3. Every pair of faces that meet or nearly meet

Go through each pair of parts that touch or come within ~1 mm (plate on rails, plate
above a strip, lid on walls, board on rests). For each:
- Is the contact **meant** (it locates the part) or incidental?
- Incidental gap ≥ 0.5–1.0 mm, not 0.2: print tolerance plus **screw-hole play**
  (hole − screw diameter) lets a part shift that much when tightened. A 0.2 gap closed
  and the base wouldn't go in.
- Faces that touch in the model on purpose: say so in a comment, and keep the clash
  check from flagging them with a deliberate 0.01 offset.

## Step 4. Anything that flexes, snaps or hooks

Hooks, clips, latches, press fits. Prefer the part's own fastening when it has one (an
encoder's threaded collar and nut, a module's mounting holes). If a hook stays:
- the thickness it catches is **measured**, and the barb reaches ≥ 1–1.5 mm under it;
- it can't let the part sit off-centre (the shaft through a hole, a connector to a cutout);
- it survives being opened again.

## Step 5. Openings against the real functional area

Screen windows, connector holes, button and knob holes. Size them from the **working**
area, not the module's outline:
- A display's lit area isn't centred under its glass, and its corners may be rounded on
  one side only. Measure it on the real panel with test patterns (frames of colours 2 px
  wide from each edge; quarter circles of known radius in the corners) and set the
  window's edge ~0.2 mm outside the pixels.
- Connector holes: the plug's overmold, not the socket.
- Threaded collars: the hole about the thread + 0.5, and the thread left above the
  nut ≥ 1.5 mm (wall + washer + nut subtracted).

## Step 6. Assembly, replayed

Walk the assembly order step by step against the model:
- Each part can reach its place (tilt-in moves, nothing to pass through).
- **Tool access**: a screwdriver (or wrench) along every screw's axis clears every
  printed part. The clash check can't see this; draw the tool as a cylinder and
  intersect it.
- Cables: header + plug length behind each module, with room to route.
- The case can be opened again without breaking anything.

## Step 7. The print itself

- Print orientation of each part; where the slicer **will add support** (overhangs,
  lips), and whether it can be cut out. Tell the user beforehand.
- No knife edges (a chamfer needs ~1.2 mm straight edge before it), no posts thinner
  than ~5 mm, no eps-thin slabs in cuts.

## Step 8. Make what you can automatic

What can be computed shouldn't depend on a reviewer remembering it. In the model:
- `assert`s for edge distance, pilot depth against reach, minimum gaps, thread above
  the nut, window outside the lit area;
- the export step prints every `ASSUMED` value, so guesses are visible on every run.

## Step 9. Report

One table: item, status (ok / risk / fix), and for each risk what the user checks on
the printed part and the fallback (drill to X, file Y mm off Z). Fixes go into the
model before ordering; risks go into the project's printed-part checklist.

After the print comes back, add what it taught to `ENCLOSURE_PLAYBOOK.md`, and to this
skill when it's a check every case needs.
