; Inno Setup script for the QingSpace Windows installer.
;
; Build with:
;   ISCC.exe /DAppVersion=1.1.2 windows\installer\qingspace.iss
;
; Optional defines:
;   /DSourceDir=...   built app directory   (default: build\windows\x64\runner\Release)
;   /DOutputDir=...   where the .exe lands  (default: build\installer)
;   /DOutputName=...  installer filename    (default: QingSpace-<ver>-windows-x64-setup)
;
; The release workflow ships this installer alongside the portable zip; both
; contain the same binaries.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\..\build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "..\..\build\installer"
#endif
#ifndef OutputName
  #define OutputName "QingSpace-" + AppVersion + "-windows-x64-setup"
#endif

; VersionInfoVersion only accepts a numeric x.y.z[.b] version, but release tags
; may carry a pre-release suffix (v1.2.0-beta.1). Strip it for the Win32 version
; resource while the user-visible strings keep the full version.
#if Pos("-", AppVersion) > 0
  #define NumericVersion Copy(AppVersion, 1, Pos("-", AppVersion) - 1)
#else
  #define NumericVersion AppVersion
#endif

#define AppName "QingSpace"
#define AppNameFull "QingSpace 晴空"
#define AppPublisher "Taboo725"
#define AppUrl "https://github.com/Taboo725/QingSpace"
#define AppExe "qing_space.exe"

[Setup]
; Never change AppId — it is how Windows recognises an existing install and
; upgrades it in place instead of leaving two copies behind.
AppId={{2F4CDC44-827E-4AE0-ACAB-E09C60B13ACE}
AppName={#AppNameFull}
AppVersion={#AppVersion}
AppVerName={#AppNameFull} {#AppVersion}
VersionInfoVersion={#NumericVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppUrl}
AppSupportURL={#AppUrl}/issues
AppUpdatesURL={#AppUrl}/releases

; Per-user install by default, so no UAC prompt appears for a sideloaded app.
; {autopf} then resolves to %LOCALAPPDATA%\Programs. Pass /ALLUSERS on the
; command line for a machine-wide install.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=commandline
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
UninstallDisplayName={#AppNameFull}
UninstallDisplayIcon={app}\{#AppExe}
LicenseFile=..\..\LICENSE

; The Flutter Windows build is 64-bit only.
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0

OutputDir={#OutputDir}
OutputBaseFilename={#OutputName}
SetupIconFile=..\runner\resources\app_icon.ico
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern

; Uses the Restart Manager to offer closing a running QingSpace rather than
; failing on a locked qing_space.exe mid-upgrade.
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "chinese"; MessagesFile: "ChineseSimplified.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#SourceDir}\{#AppExe}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\*"; DestDir: "{app}"; Excludes: "{#AppExe}"; \
  Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppNameFull}"; Filename: "{app}\{#AppExe}"
Name: "{group}\{cm:UninstallProgram,{#AppNameFull}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppNameFull}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; \
  Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Flutter writes its engine cache beside the executable at runtime; without
; this the install directory survives uninstallation as an empty shell.
Type: filesandordirs; Name: "{app}"

; Deliberately *not* removed on uninstall: %APPDATA%\com.qingspace\qing_space,
; where SharedPreferences keeps the couple profile, tokens and theme. Reinstalling
; should not wipe someone's settings, and their content lives in their own
; repository anyway.
