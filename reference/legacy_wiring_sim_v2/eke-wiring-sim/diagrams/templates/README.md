# diagrams/templates/

Vehicle diagram templates for starting new projects.

## Planned templates (Phase 3)

- `motorcycle-basic/`     — single-cylinder DC-CDI motorcycle
- `atv-basic/`            — ATV with lighting and starter circuit
- `marine-basic/`         — outboard motor with ignition and charging
- `automotive-basic/`     — 4-cylinder with OBD2 connector stubs
- `industrial-basic/`     — 3-phase equipment with control logic

## Template structure

Each template contains:

```
templates/<name>/
  project.json       — metadata (id, label, platform)
  modules.json       — starter module set
  wires.json         — starter wire set
  measurements.json  — default meter readings
  layout.json        — default positions
```

To use a template, copy its folder to `diagrams/<new-vehicle>/`
and update `project.json` with the new vehicle's details.
