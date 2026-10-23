# Asset scope

The framework LICENSE covers original Harbor code and authored primitive content. User-supplied data under assets/local_source and assets/local_models, and derivatives under assets/converted, retain their original ownership. The public source repository excludes those folders and derived artwork captures. No original game C++, ASI binary or third-party decoder implementation is bundled.

The private build contains 32 selected native model scenes and 71 PNGs: four original scenes/25 textures retained, plus 28 scenes/46 textures from the new models.zip. The complete IMG is not bundled. All 44 IFP blocks from the supplied Stories pack, VCS/LCS gameplay tables, custom-animation metadata, readme and credits are retained under assets/local_source/stories. The active set uses VCS core/weapons and LCS bikes; every original clip remains namespaced in the converted catalog.

External rebuild dependency DragonFF at 54baca8ea2ed95fe5a86917f44399ce677379c59 is GPL-3.0-or-later. Obtain its implementation and license from its repository; it is not redistributed here. Rebuilding also uses Pillow. Running the native project requires neither tool. Framework licensing does not relicense supplied game assets.
