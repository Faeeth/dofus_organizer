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
  ouvre l'enregistrement du raccourci, le menu permet de le modifier, de le
  déplacer vers une autre équipe ou de le supprimer. L'ordre au sein d'une
  équipe est la priorité de résolution quand plusieurs personnages partagent
  une touche.
- **Barre de statut** : nombre de raccourcis enregistrés, raccourcis refusés
  par Windows, dernière activation.
- **Paramètres** : réduction dans la zone de notification à la fermeture,
  démarrage réduit, lancement au démarrage de Windows, raccourci d'affichage
  de la fenêtre, raccourci de fermeture.

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

## Limites connues

`RegisterHotKey` refuse les touches déjà réservées par le système ou par une
autre application. **F12 est réservé par le débogueur Windows** et ne peut
donc pas servir de raccourci, contrairement au script AutoHotkey d'origine
qui passait par un hook clavier bas niveau. Les raccourcis refusés sont
signalés en rouge dans l'interface : il suffit d'en choisir un autre.

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
          "shortcut": { "keyCode": 112, "modifiers": 0 }
        }
      ]
    }
  ]
}
```

`keyCode` est un code de touche virtuelle Win32 (`VK_F1` = `0x70`),
`modifiers` un masque `MOD_ALT` (1), `MOD_CONTROL` (2), `MOD_SHIFT` (4),
`MOD_WIN` (8).

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
tool/generate_icons.py génération des icônes
```

Le canal `dofus_organizer/native` expose `hotkeys.apply`,
`hotkeys.setSuspended`, `window.focus`, `app.startedHidden`,
`startup.isEnabled`, `startup.setEnabled`, et émet `onHotkey` et
`onSecondInstance`.

## Licence

GPL-3.0, voir [LICENSE](LICENSE).
