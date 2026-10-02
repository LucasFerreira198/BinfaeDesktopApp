; Script Inno Setup para BINFAE Desktop (Flutter Windows Nativo)
[Setup]
AppName=BINFAE Desktop
AppVersion=1.0.0
DefaultDirName={autopf}\BINFAE Desktop
DefaultGroupName=BINFAE Desktop
OutputDir=dist
OutputBaseFilename=BinfaeDesktop-Setup
Compression=lzma2
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64
WizardStyle=modern
UninstallDisplayIcon={app}\binfae_desktop.exe

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\BINFAE Desktop"; Filename: "{app}\binfae_desktop.exe"
Name: "{autodesktop}\BINFAE Desktop"; Filename: "{app}\binfae_desktop.exe"

[Run]
Filename: "{app}\binfae_desktop.exe"; Description: "{cm:LaunchProgram,BINFAE Desktop}"; Flags: nowait postinstall skipifsilent
