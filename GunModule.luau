local GunsModule = {}

GunsModule.ValidGuns = {
	"UMP","AWM"
}

GunsModule.GunSettings = {
	["UMP"] = {
		["Damage"] = 5,
		["Rate"] = 0.08,
		["Spread"] = 0.1,
		["Speed"] = 500,
		["Recoil"] = Vector2.new(.1,- .1), -- First value is horizontal recoil, second value is vertical recoil
		["RecoilMult"] = 1.02, -- At Every Shoot the recoil will increase by this rate
		["Lifetime"] = 1,
		["AmmoCapacity"] = 30,
	},
	["AWM"] = {
		["Damage"] = 70,
		["Rate"] = 1.5,
		["Spread"] = 0.1,
		["Speed"] = 850,
		["Recoil"] = Vector2.new(.5,- .5), -- First value is horizontal recoil, second value is vertical recoil
		["RecoilMult"] = 1, -- At Every Shoot the recoil will increase by this rate
		["Lifetime"] = 3,
		["AmmoCapacity"] = 10,
	},
	
}

GunsModule.Players = {
	["Default"] = {
		GunEquipped = "",
		GunDebounce = false,
		State = "",
		GunsAmmo = {}
	},
}


return GunsModule