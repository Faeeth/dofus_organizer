; Installateur de Dofus Organizer, pour Inno Setup 6.
;
; A construire depuis la racine du depot, une fois l'application compilee :
;
;   flutter build windows --release
;   iscc installer\dofus_organizer.iss /DVersion=1.0.0
;
; L'installateur sort dans `dist\`.
;
; CE QU'IL NE TOUCHE JAMAIS : la configuration. Elle vit dans
; %LOCALAPPDATA%\DofusOrganizer et n'apparait nulle part ci-dessous — ni dans
; [Files], ni dans [UninstallDelete]. Une mise a jour laisse donc les equipes
; et les raccourcis en place ; une desinstallation aussi, pour qu'une
; reinstallation les retrouve.
;
; PrivilegesRequired=lowest : installation pour l'utilisateur courant, sans
; invite d'administrateur et sans ecriture hors de chez lui.

#ifndef Version
  #define Version "0.0.0"
#endif

; `VersionInfoVersion` n'accepte que des nombres : un tag `v1.0.0-beta`
; ferait echouer la compilation. On coupe au premier tiret pour la ressource
; de version, et on garde le libelle entier pour l'affichage.
#define VersionNumerique Copy(Version, 1, Pos("-", Version + "-") - 1)

#define Nom "Dofus Organizer"
#define Editeur "Faeeth"
#define Executable "dofus_organizer.exe"

[Setup]
AppId={{545A3798-0C31-492F-93B2-DF260B214377}
AppName={#Nom}
AppVersion={#Version}
AppVerName={#Nom} {#Version}
AppPublisher={#Editeur}
AppPublisherURL=https://github.com/Faeeth/dofus_organizer
VersionInfoVersion={#VersionNumerique}

PrivilegesRequired=lowest
DefaultDirName={autopf}\{#Nom}
DefaultGroupName={#Nom}
DisableProgramGroupPage=yes
; Le dossier est propose, mais modifiable.
DisableDirPage=no
AllowNoIcons=yes
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
OutputDir=..\dist
OutputBaseFilename=DofusOrganizer-{#Version}-installateur
; L'application est 64 bits, comme le jeu.
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayName={#Nom} {#Version}
UninstallDisplayIcon={app}\{#Executable}
SetupIconFile=..\windows\runner\resources\app_icon.ico

[Languages]
Name: "francais"; MessagesFile: "compiler:Languages\French.isl"
Name: "anglais"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "bureau"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "demarrage"; Description: "Lancer Dofus Organizer au demarrage de Windows"; GroupDescription: "Demarrage"; Flags: unchecked

[Files]
; `recursesubdirs` emporte `data\`, ou Flutter place ses ressources et ses
; polices. `portable.txt` n'a rien a faire ici : sa presence dirait a l'outil
; qu'il n'a pas ete installe.
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "portable.txt"

[Icons]
Name: "{group}\{#Nom}"; Filename: "{app}\{#Executable}"
Name: "{group}\{cm:UninstallProgram,{#Nom}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#Nom}"; Filename: "{app}\{#Executable}"; Tasks: bureau

[Registry]
; L'option de demarrage automatique de l'outil ecrit exactement cette valeur ;
; la cocher ici revient au meme, et `uninsdeletevalue` la retire proprement.
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "DofusOrganizer"; ValueData: """{app}\{#Executable}"" --minimized"; Flags: uninsdeletevalue; Tasks: demarrage

[Run]
; Sans `skipifsilent` : une mise a jour lancee depuis l'outil se fait en
; silence, et doit rendre l'outil a qui l'utilisait. Il l'avait ferme pour
; laisser la place a l'installateur, pas pour en finir avec lui.
;
; `--updated` dit a l'outil qu'il sort d'une installation : il se montre, meme
; si l'option « demarrer reduit » est cochee. Elle vaut pour les lancements
; suivants, pas pour celui-la — apres une mise a jour, on veut voir que le
; tool est revenu.
Filename: "{app}\{#Executable}"; Parameters: "--updated"; Description: "{cm:LaunchProgram,{#Nom}}"; Flags: nowait postinstall
