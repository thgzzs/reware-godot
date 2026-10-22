# Selective model import

`models.zip` arrived successfully. It contains `gta3.img`, `hud.txd`, `MISC.TXD`, `particle.txd` and `generic.txd`; there is no matching `.dir`. The selected model and texture import is complete for this test-build scope. No full-archive unpack was performed.

Four bounded RenderWare roots were selected by embedded metadata: the skinned `player` material character, `idaho`, `colt45` and `trashcan`. Their needed texture dictionary roots were selected by material-name coverage. Twenty-five PNGs cover those materials plus HUD, wheels, effects, target and yard surface roles. Exact offsets, lengths and DFF hashes are in assets/model_selection.json; descriptive exported names are not claimed to be recovered original archive filenames.

See [MODEL_AND_DISPLAY_MILESTONE.md](MODEL_AND_DISPLAY_MILESTONE.md) for the complete workflow, evidence, replacement bindings and remaining gaps.

`tools/inspect_rw_archive.py` performs bounded sector/root inspection inside the ZIP without writing payloads. It is a fallback when the original DIR index is absent; its recognized-root inventory is not proof that every archive entry was identified. `tools/convert_model_placeholders.py` exports only the reviewed selection and verifies its model hashes.

When a matching PC VC v1 DIR is available, the earlier explicit allowlist extractor remains available:

```bash
python3 tools/extract_selected_img.py --img /game/gta3.img --dir /game/gta3.dir --out /new/selection --entry verified_model.dff --entry verified_texture.txd --dry-run
```

Remove --dry-run to export the exact requested entries. The directory must be new. No wildcard or extract-all default exists. It does not convert DFF/TXD formats and does not support every console/compressed archive variant.

Minimal scene scope remains one shared character, one car, one pistol and one reused prop. The test yard's remaining geometry is authored. The full original world, population meshes and vehicle collection are not necessary for this milestone.
