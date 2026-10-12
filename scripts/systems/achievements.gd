extends RefCounted
## Feats: small achievements tracked by main.gd, toasted by the HUD and saved with the journey.

const DEFS := {
	"first_thorn": {"name": "First Thorn", "desc": "Defeat your first monster."},
	"bane_of_blight": {"name": "Bane of the Blight", "desc": "Defeat 100 monsters."},
	"seedbearer": {"name": "Seedbearer", "desc": "Return your first Moonseed."},
	"waker_of_wells": {"name": "Waker of Wells", "desc": "Wake the Moonwell."},
	"arsenal": {"name": "Full Arsenal", "desc": "Carry all four weapons."},
	"chestnut": {"name": "Chestnut", "desc": "Open every chest in the valley."},
	"welltraveled": {"name": "Well Traveled", "desc": "Awaken every waystone."},
	"first_cast": {"name": "First Cast", "desc": "Catch your first fish."},
	"moonangler": {"name": "Moonangler", "desc": "Catch every species of fish."},
	"night_gardener": {"name": "Night Gardener", "desc": "Gather five moonpetals."},
	"petal_step": {"name": "Petal Step", "desc": "Land your first perfect parry."},
	"untouchable": {"name": "Untouchable", "desc": "Land ten perfect parries."},
	"tiny_guide": {"name": "Tiny Guide", "desc": "Befriend the moth companion."},
	"depths_daring": {"name": "Depths Daring", "desc": "Clear five waves of the Blighted Depths."},
	"depths_delver": {"name": "Depths Delver", "desc": "Clear ten waves of the Blighted Depths."},
	"star_walker": {"name": "Star Walker", "desc": "Reach Starfall Rise."},
	"coin_hoard": {"name": "Coin Hoard", "desc": "Hold 500 Petalcoins at once."},
	"fullbloom": {"name": "Full Bloom", "desc": "Grow to ten hearts."},
}


static func def_of(id: String) -> Dictionary:
	return DEFS.get(id, {})
