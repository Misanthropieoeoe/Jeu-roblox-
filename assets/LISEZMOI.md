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
| zone      | à importer (cercle des attaques Zone) |

Pour modifier une texture : la redessiner, la réimporter, puis remplacer son
ID dans `TEXTURES`.
