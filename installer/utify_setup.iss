; ============================================================
; Utify - Windows Installer Script (Inno Setup 6)
; ============================================================

#define AppName      "Utify"
#define AppVersion   "1.0.0"
#define AppPublisher "Utify"
#define AppURL       "https://utify.app"
#define AppExeName   "utify.exe"
#define AppId        "{{A7B3C2D1-E4F5-4A6B-8C9D-0E1F2A3B4C5D}"

[Setup]
AppId={#AppId}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}
AppUpdatesURL={#AppURL}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
AllowNoIcons=yes
; Installer output (relative to .iss file location = installer/)
OutputDir=output
OutputBaseFilename=Utify_Setup_{#AppVersion}
; Compression
Compression=lzma2/ultra64
SolidCompression=yes
; Appearance
WizardStyle=modern
WizardSizePercent=120
; Icon (go up one level from installer/ to project root)
SetupIconFile=..\windows\runner\resources\app_icon.ico
; Require admin for Program Files install
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog
; Minimum Windows version: Windows 10
MinVersion=10.0.17763
; Installer bitmap (optional, 164x314 bmp)
; WizardImageFile=installer\assets\wizard_side.bmp
; WizardSmallImageFile=installer\assets\wizard_top.bmp
UninstallDisplayIcon={app}\{#AppExeName}
UninstallDisplayName={#AppName}
VersionInfoVersion={#AppVersion}
VersionInfoCompany={#AppPublisher}
VersionInfoDescription={#AppName} Setup
VersionInfoProductName={#AppName}
VersionInfoProductVersion={#AppVersion}
; Create uninstall entry in Windows "Add or Remove Programs"
CreateUninstallRegKey=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon";     Description: "{cm:CreateDesktopIcon}";     GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "startmenuicon";   Description: "Create a Start Menu shortcut"; GroupDescription: "{cm:AdditionalIcons}"; Flags: checkedonce
Name: "autostart";       Description: "Launch Utify on Windows startup"; GroupDescription: "Startup:"; Flags: unchecked

[Files]
; Main executable
Source: "..\build\windows\x64\runner\Release\{#AppExeName}"; DestDir: "{app}"; Flags: ignoreversion

; Flutter engine DLLs
Source: "..\build\windows\x64\runner\Release\flutter_windows.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\*.dll";               DestDir: "{app}"; Flags: ignoreversion recursesubdirs

; Data folder (contains app's Flutter assets)
Source: "..\build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
; Start Menu
Name: "{group}\{#AppName}";          Filename: "{app}\{#AppExeName}"; Tasks: startmenuicon
Name: "{group}\Uninstall {#AppName}"; Filename: "{uninstallexe}";       Tasks: startmenuicon

; Desktop
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Registry]
; Windows Startup (optional task)
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "{#AppName}"; ValueData: """{app}\{#AppExeName}"""; Flags: uninsdeletevalue; Tasks: autostart

[Run]
; Offer to launch app after install
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(AppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Clean up any user data / cache created by the app inside AppData
Type: filesandordirs; Name: "{localappdata}\utify"

[Code]
// ── Welcome page custom text ────────────────────────────────────────────────
procedure InitializeWizard();
begin
  WizardForm.WelcomeLabel2.Caption :=
    'This will install Utify {#AppVersion} on your computer.' + #13#10#13#10 +
    'Utify is a free music player that streams and downloads songs from YouTube.' + #13#10#13#10 +
    'Click Next to continue, or Cancel to exit Setup.';
end;

// ── Simple uninstall initializer ─────────────────────────────────────────────
function InitializeUninstall(): Boolean;
begin
  Result := True;
end;
