-- SFX. Les effets sonores originaux du jeu (assets/sons/*.wav, fabriqués
-- par tools/generer_sons.py). Une fois un son importé dans Roblox, mettre
-- son ID ici ("rbxassetid://123..."). Tant qu'un ID est vide, le jeu garde
-- l'ancien son de Roblox (le "secours" donné à SFX.Get).
local SFX = {
	PunchHit = "",    -- punch_hit.wav   : coups de poing, barrage
	HeavyHit = "",    -- heavy_hit.wav   : gros coups, coup final
	Impact = "",      -- impact.wav      : impact des sorts
	Whoosh = "",      -- whoosh.wav      : saut du Stand, mouvements rapides
	Projectile = "",  -- projectile.wav  : tir de projectile
	Block = "",       -- block.wav       : coup bloqué en garde
	Parry = "",       -- parry.wav       : parade parfaite
	GuardBreak = "",  -- guard_break.wav : garde brisée
	DoubleJump = "",  -- double_jump.wav : double saut
	Summon = "",      -- summon.wav      : arrêt du temps (petit éclat sous le cri)
	Menace = "",      -- menace.wav      : grondement ゴゴゴ des emotes
	Coin = "",        -- coin.wav        : argent ramassé (+30)
	Chest = "",       -- chest.wav       : ouverture d'un coffre de skins
}

-- Renvoie l'ID du son, ou le son de secours si l'ID est encore vide
local Get = function(name, fallback)
	local id = SFX[name]
	if type(id) == "string" and id ~= "" then return id end
	return fallback or ""
end

return setmetatable({ Get = Get }, { __index = SFX })
