# Asset scope

The framework's LICENSE covers original Harbor code and authored primitive content. Files under assets/local_source, selected payloads under assets/local_models, and derivatives under assets/converted originate from user attachments and retain their original ownership. This package does not grant rights to redistribute them. The public source repository excludes those folders and derived preview images. No original game C++ or third-party conversion-tool implementation is bundled.

The supplied models.zip was processed selectively. Only four model roots, four small IMG texture dictionary roots and 25 selected PNGs are used; the complete IMG is not bundled or unpacked into a full asset tree. Descriptive labels were inferred from embedded metadata because no matching directory index was provided.

The external DragonFF build dependency at 54baca8ea2ed95fe5a86917f44399ce677379c59 is GPL-3.0-or-later. Obtain its code and license from its own repository when rebuilding; no DragonFF implementation is redistributed in Harbor. Rebuilding also uses Pillow. The native Godot project runs without these conversion tools.
