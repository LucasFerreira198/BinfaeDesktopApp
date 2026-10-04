; Script Inno Setup para Informatica - BINFAE-GL (Flutter Windows Nativo)
#ifndef MyAppVersion
#define MyAppVersion "2.0.8"
#endif

[Setup]
AppName=Informatica - BINFAE-GL
AppVersion={#MyAppVersion}
DefaultDirName={autopf}\Informatica - BINFAE-GL
DefaultGroupName=Informatica - BINFAE-GL
OutputDir=dist
OutputBaseFilename=BinfaeDesktop-Setup
Compression=lzma2
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64
WizardStyle=modern
UninstallDisplayIcon={app}\binfae_desktop.exe
CloseApplications=yes

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Informatica - BINFAE-GL"; Filename: "{app}\binfae_desktop.exe"
Name: "{autodesktop}\Informatica - BINFAE-GL"; Filename: "{app}\binfae_desktop.exe"

[Run]
Filename: "{app}\binfae_desktop.exe"; Description: "{cm:LaunchProgram,Informatica - BINFAE-GL}"; Flags: nowait postinstall
