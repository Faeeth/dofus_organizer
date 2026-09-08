# Dofus Organizer

Gestionnaire de fenêtres pour le jeu multi-comptes sous Windows. Chaque
personnage est associé à un raccourci global qui met sa fenêtre au premier
plan. Les personnages sont regroupés en équipes que l'on active ou désactive
d'un clic, ce qui permet à plusieurs équipes de partager les mêmes touches
sans se marcher dessus.

Remplace le script AutoHotkey d'origine (`old_dofus_organizer.ahk`, conservé
comme référence fonctionnelle).

## Fonctionnement

Le chemin critique — appui sur la touche jusqu'à l'activation de la fenêtre —
est intégralement en C++ Win32 :

1. `RegisterHotKey` enregistre les raccourcis sur une fenêtre *message-only* ;
2. `WM_HOTKEY` est traité dans la boucle de messages du runner ;
3. la fenêtre cible est résolue par sous-chaîne de titre puis activée.

Dart n'intervient pas dans cette séquence : il pousse la configuration vers le
natif et reçoit un événement *a posteriori* pour l'affichage. Les handles de
fenêtres résolus sont mis en cache et revalidés (handle vivant *et* titre
toujours correspondant), si bien qu'un appui n'énumère les fenêtres que
lorsque le cache est froid ou périmé.

Les personnages désactivés ne sont pas envoyés au natif : réduire une équipe
réduit d'autant le travail fait à chaque appui.

## Interface

- **Équipe** : interrupteur d'activation, action « solo » qui n'active que
  cette équipe, ajout de personnage, renommage, suppression. Les équipes se
  réordonnent par glisser-déposer.
- **Personnage** : un clic sur la ligne l'active ou le désactive, le badge
  ouvre l'enregistrement du raccourci, le menu permet de le modifier ou de le
  supprimer. Chaque personnage peut porter le portrait de sa classe, choisi
  dans une grille des dix-neuf classes, masculin ou féminin. L'ordre au sein
  d'une équipe est la priorité de résolution quand plusieurs personnages
  partagent une touche.
- **Barre de statut** : nombre de raccourcis enregistrés, raccourcis refusés
  par Windows, dernière activation.
- **Paramètres** : réduction dans la zone de notification à la fermeture,
  démarrage réduit, lancement au démarrage de Windows.

La fenêtre se réduit dans la zone de notification. Le menu contextuel de
l'icône propose « Ouvrir le menu » et « Fermer ». Une seule instance peut
tourner : lancer le tool une seconde fois ramène la fenêtre existante au
premier plan.

## Correspondance des titres

Le fragment saisi est recherché dans le titre des fenêtres, sans tenir compte
de la casse — le comportement de `SetTitleMatchMode(2)` en AutoHotkey. Les
fenêtres invisibles, sans titre, masquées par DWM ou appartenant au tool
lui-même sont ignorées. Le bouton **Tester** de l'éditeur de personnage
active la fenêtre correspondante sans passer par le raccourci.

## Raccourcis

L'enregistreur accepte toutes les touches — fonction, lettres, chiffres, pavé
numérique, navigation, ponctuation, multimédia — avec ou sans `Ctrl`, `Alt`,
`Maj` et `Win`. Seule `Échap` est réservée, elle ferme la capture. Le code de
touche virtuelle des touches de ponctuation dépend de la disposition du
clavier : il est résolu via `VkKeyScanEx` sur la disposition courante, et le
libellé affiché est celui de la touche telle qu'elle a été pressée.

C'est ensuite Windows qui arbitre : `RegisterHotKey` refuse les touches déjà
réservées par le système ou détenues par une autre application. **F12 seul est
réservé par le débogueur Windows** et ne peut pas être enregistré,
contrairement au script AutoHotkey d'origine qui passait par un hook clavier
bas niveau ; `Ctrl + F12` en revanche fonctionne, comme toute combinaison de
F12 avec un modificateur. Les raccourcis refusés sont signalés en rouge dans
l'interface : ajouter un modificateur suffit le plus souvent.

## Configuration

`%APPDATA%\DofusOrganizer\config.json`, écrit de façon atomique.

```json
{
  "version": 1,
  "settings": { "closeToTray": true, "startMinimized": false },
  "groups": [
    {
      "id": "…",
      "name": "Kaska",
      "enabled": true,
      "characters": [
        {
          "id": "…",
          "name": "Kaska-yopette",
          "windowTitle": "Kaska-yopette",
          "enabled": true,
          "classIcon": "iop_m",
          "shortcut": { "keyCode": 112, "modifiers": 0, "keyName": "F1" }
        }
      ]
    }
  ]
}
```

`classIcon` désigne le portrait, sous la forme `<classe>_<m|f>` ; une valeur
inconnue est ignorée plutôt que de faire échouer l'affichage.

`keyCode` est un code de touche virtuelle Win32 (`VK_F1` = `0x70`),
`modifiers` un masque `MOD_ALT` (1), `MOD_CONTROL` (2), `MOD_SHIFT` (4),
`MOD_WIN` (8). `keyName` est le libellé de la touche au moment de la capture,
conservé parce qu'un code de touche seul ne permet pas de retrouver le
caractère d'une touche de ponctuation sur une disposition arbitraire.

## Développement

Prérequis : Flutter (canal stable, desktop Windows activé) et Visual Studio
Build Tools 2022 avec la charge de travail C++.

```
flutter pub get
flutter run -d windows      # exécution en développement
flutter test                # tests de la couche métier
flutter analyze             # analyse statique
flutter build windows --release
```

Le binaire est produit dans `build\windows\x64\runner\Release\`.

### Organisation

```
lib/src/models/        personnages, équipes, raccourcis, configuration
lib/src/services/      persistance JSON, pont vers le natif
lib/src/state/         contrôleur : configuration et synchronisation
lib/src/ui/            interface et widgets
windows/runner/        couche Win32
  window_focus.*         résolution par titre, cache, mise au premier plan
  hotkey_service.*       fenêtre message-only, RegisterHotKey, dispatch
  native_bridge.*        canal de méthodes vers Dart
  single_instance.*      mutex nommé et réveil de l'instance existante
  startup_registration.* entrée Run de l'utilisateur courant
tool/generate_icons.py      icônes dérivées de assets/logo.png
tool/extract_class_icons.py portraits de classe
```

Les portraits de `assets/classes/` proviennent des fichiers du jeu, extraits
par le projet compagnon `dtracker` ; `tool/extract_class_icons.py` les
normalise en carrés transparents. Ils appartiennent à Ankama et ne sont pas
couverts par la licence du code.

Le canal `dofus_organizer/native` expose `hotkeys.apply`,
`hotkeys.setSuspended`, `window.focus`, `window.setStartHidden`,
`keys.virtualKeyForCharacter`, `app.startedHidden`, `startup.isEnabled`,
`startup.setEnabled`, et émet `onHotkey` et `onSecondInstance`.

La géométrie de la fenêtre — taille, taille minimale, centrage, premier
affichage — est entièrement gérée par le runner : la convertir depuis Dart
demanderait un rapport de pixels que la vue n'expose pas encore avant la
première image.

## Licence

GPL-3.0, voir [LICENSE](LICENSE).
