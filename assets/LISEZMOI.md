# Textures de VFX

Dessinées par `tools/dessiner_textures.py` (PNG blancs sur fond transparent,
teintés en jeu à la couleur de chaque Stand). Aperçu : `apercu_textures.png`.

Importées dans Roblox (Gestionnaire de contenus) ; leurs ID sont dans
`src/StarterPlayerScripts/SpellFX.client.luau` (tableau `TEXTURES`) :

| Texture   | ID Roblox        |
|-----------|------------------|
| glow      | 138403917480165  |
| spark     | 74912473102145   |
| impact    | 87537987778207   |
| ring      | 115337750392303  |
| slash     | 73831602916103   |
| lightning | 75208682471722   |
| smoke     | 137211278777046  |
| star      | 133511855155150  |
| shard     | 88905406839516   |
| flame     | 114860784322228  |
| petal     | 95473304233140   |
| gem       | 126447150623322  |
| zipper    | 113054516565882  |
| zone      | 128904679799878  |

Pour modifier une texture : la redessiner, la réimporter, puis remplacer son
ID dans `TEXTURES`.

## Sons (assets/sons/)

Effets sonores originaux, style anime dramatique, fabriqués par `tools/generer_sons.py`. À importer dans
Roblox (Gestionnaire d'assets → Audio), puis mettre chaque ID dans
`src/ReplicatedStorage/SFX.luau`. Tant qu'un ID est vide, le jeu garde l'ancien
son de Roblox (ou reste silencieux pour les nouveaux sons).

| fichier | nom dans SFX | quand |
|---|---|---|
| punch_hit.wav | PunchHit | coups de poing, barrage |
| heavy_hit.wav | HeavyHit | gros coups, coup final |
| impact.wav | Impact | impact des sorts |
| whoosh.wav | Whoosh | saut du Stand, mouvements rapides |
| projectile.wav | Projectile | tir de projectile |
| block.wav | Block | coup bloqué en garde |
| parry.wav | Parry | parade parfaite |
| guard_break.wav | GuardBreak | garde brisée |
| double_jump.wav | DoubleJump | double saut |
| summon.wav | Summon | éclat de l'arrêt du temps |
| menace.wav | Menace | grondement ゴゴゴ des emotes |
| coin.wav | Coin | argent ramassé |
| chest.wav | Chest | ouverture d'un coffre de skins |
