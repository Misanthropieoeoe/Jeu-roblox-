# Outils de fusion

Le jeu (Jojo Test Game) est aussi modifié directement dans Studio par un
ami qui ne passe pas par GitHub. Pour ne jamais écraser son travail, chaque
fichier `.rbxlx` du jeu poussé sur GitHub est fusionné AVANT toute autre
modification :

1. `git checkout -b import-ami jeu-ami`
   (`jeu-ami` = dernière version connue des scripts du jeu)
2. `python3 -I tools/extraire_scripts.py <fichier.rbxlx> .`
   (réécrit les scripts de `src/` avec ceux du fichier ; repérer aussi les
   scripts nouveaux / supprimés)
3. `python3 -I tools/generer_projet.py` si des scripts ont été ajoutés,
   puis commit sur `import-ami`
4. `git checkout dev && git merge import-ami` : les conflits sont réglés à
   la main en gardant les deux côtés
5. `git branch -f jeu-ami import-ami && git push origin jeu-ami dev`
6. Supprimer le `.rbxlx` du dépôt (il reste sur le PC)

Ensuite seulement : Pull dans GitHub Desktop puis Rojo → Connect.

## Identifiants Lemonade

L'ami utilise Lemonade (IA dans Studio), qui marque chaque script avec un
attribut caché `_lemonadeUniqueId`. Rojo effacerait ces attributs à la
synchronisation : ils sont donc enregistrés dans `tools/attributs_studio.json`
(mis à jour par `extraire_scripts.py`) et `generer_projet.py` les remet dans
`default.project.json` (`$attributes`), pour que Rojo les conserve.

**Ne pas modifier `default.project.json` à la main** : lancer
`python3 -I tools/generer_projet.py` après avoir ajouté / supprimé un script.
