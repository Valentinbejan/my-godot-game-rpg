# Cloister art kit · v0.2

Eighteen original Blender assets now appear throughout the playable dungeon. The priority was repeated, prominent forms: architecture first, then landmarks, enemies and the first-person weapon. Carved limestone, dark masonry, aged bronze and teal cloth share the existing texture library. Warm votive lights and cool windows establish the room lighting.

## Reuse in Godot

Drag a `.tscn` from `tullianum-carcer/scenes/props/cloister_kit/` into a level. These wrappers show the shared textures in the editor. Columns, arch jambs, floor tiles, sarcophagi, braziers and gates have simple collision shapes. Other wrappers are decorative; character wrappers do not contain AI. Add lights beside candles and braziers as appropriate for the room. The playable demo manages its own collision, lighting and enemy logic.

`demo/art.gd` is the common material resolver and cached model loader. Its `place()` method supports position, scale and yaw. Change its palette to adjust all copies together. Models export material names such as `cloister_carving`; their UVs use meter-scaled planar projection. They reference the original images at runtime and contain no embedded texture copies.

Units are meters. Most assets have an origin at floor center. The sword and gauntlet share an origin at the guard; parent the gauntlet under the sword with an identity transform. Blender Z becomes Godot Y; character fronts face Godot +Z. The enemy controller turns the visual root by 180 degrees to match its forward direction.

| Asset | Main reuse | Triangles |
| --- | --- | ---: |
| fluted_column | 6 m column; scale vertically for halls and bridge supports | 4,476 |
| pointed_arch | Entrance surround, nominal 4.6 m clear width | 3,512 |
| tracery_bay | Window, wall niche or luminous recess | 4,394 |
| ribbed_vault | 8 m span × 4 m deep ceiling bay | 1,728 |
| flagstone_floor | 4 × 4 m paving module with mosaic strips | 704 |
| pilgrim_sarcophagus | Crypt tomb, gallery monument, spell pedestal | 2,900 |
| votive_brazier | Tall light fixture, fallen prop | 3,270 |
| votive_candles | Merged candle cluster for ledges and shrines | 1,726 |
| masonry_rubble | Small broken-stone cluster | 396 |
| ritual_banner | Wall or column dressing with a celestial seal | 1,532 |
| celestial_shrine | Carved resting place and crystal landmark | 2,586 |
| vow_gate | Ornate shortcut gate | 3,106 |
| drowned_pilgrim | Hooded armored enemy and hooked glaive | 7,668 |
| bell_keeper | Crowned boss, chain mantle and bell hammer | 12,568 |
| sister_vale | Ivory-robed guide and candle staff | 7,902 |
| glass_moth | Glass-winged enemy and scaled pickup | 5,526 |
| pilgrim_longsword | Forged blade, fuller, swept guard and wrapped grip | 2,440 |
| pilgrim_gauntlet | Curled armored hand, cuff and forearm | 3,428 |

The figure roots expose `WeaponArm`, `OffArm`, `LegLeft` and `LegRight` pivots. The moth exposes `WingLeft` and `WingRight`. These are rigid articulated parts animated by the game; the kit does not yet contain skinned character rigs or authored animation clips. The Keeper's broken crown reaches about 4.6 m; the combat body is shorter. The moth's body is authored at hovering height rather than on the floor.

## Edit and rebuild

Open `cloister_kit_v1.blend` and select the `Cloister_Art_Kit_v1` scene. Each asset is a separate collection. Exact bounds, material names and triangle counts are recorded in `cloister_kit_manifest.json`. The original approved bell remains separately editable in `drowned_bell_source.blend`.

The authoring definitions are preserved in `tools/art_kit_common.py`, `tools/art_kit_architecture.py` and `tools/art_kit_characters.py`. Set `ROOT` for another checkout. In a fresh Blender scene, run the common definitions, the two builder definitions, then `build_architecture()`, `build_figure('drowned_pilgrim')`, `build_figure('bell_keeper')`, `build_figure('sister_vale')`, `build_moth()`, `build_sword()` and `build_gauntlet()`. Builders refuse to overwrite an existing named collection.

Export individual collections with `export_asset(name)`, which limits export to the selected objects in the active scene and disables image embedding. `save_library()` saves an editable copy. After changing the manifest, run `tools/create_kit_scenes.py` to regenerate the editor wrappers. Keep gameplay collision independent of decorative geometry.

The texture library stays local and ignored by Git. Copy the eleven images listed in `tullianum-carcer/THIRD_PARTY_NOTICES.md` into a fresh checkout before using the kit. The Windows build includes those selected images.
