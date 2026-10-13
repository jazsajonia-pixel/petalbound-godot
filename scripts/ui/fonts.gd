extends RefCounted
## Game fonts (both SIL Open Font License 1.1, see assets/fonts/OFL_*.txt):
##  - Nunito (bold weight) for all menus, HUD text and dialogue: rounded,
##    open letterforms that stay readable at small sizes on phones.
##  - Pixelify Sans for titles and floating combat numbers, matching the
##    pixel-art world.

static var _ui: Font
static var _title: Font


static func ui() -> Font:
	if _ui == null:
		var base: FontFile = load("res://assets/fonts/Nunito.ttf")
		base.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		base.hinting = TextServer.HINTING_LIGHT
		var v := FontVariation.new()
		v.base_font = base
		v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 750}
		_ui = v
	return _ui


static func title() -> Font:
	if _title == null:
		var base: FontFile = load("res://assets/fonts/PixelifySans.ttf")
		base.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		var v := FontVariation.new()
		v.base_font = base
		v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 600}
		_title = v
	return _title
