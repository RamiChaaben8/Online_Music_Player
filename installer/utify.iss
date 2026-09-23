; installer/utify.iss
; Inno Setup script for Utify Windows installer.
;
; Compiles to a single Setup.exe that:
;   - Installs to %LocalAppData%\Utify by default (no admin rights needed)
;   - Creates a Start Menu shortcut
;   - Creates a Desktop shortcut (optional, user can uncheck)
;   - Registers an uninstaller in Add/Remove Programs
;   - Supports silent install: Setup.exe /VERYSILENT /SUPPRESSMSGBOXES
;
; The GitHub Actions workflow compiles this with:
;   iscc installer\utify.iss
; and the output is installer\Output\utify-setup.exe

#define MyAppName      "Utify"
#define MyAppPublisher "Rami Chaaben"
#define MyAppURL       "https://github.com/RamiChaaben8/Online_Music_Player"
#define MyAppExeName   "utify.exe"

; Version is injected by the workflow via /DMyAppVersion=x.y.z
; Falls back to 1.0.0 if not provided.
#ifndef MyAppVersion
  #define MyAppVersion "1.0.0"
#endif

[Setup]
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}/releases

; Install to user's local AppData — no UAC prompt needed
DefaultDirName={localappdata}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes

; Allow upgrade over existing install silently
CloseApplications=yes
CloseApplicationsFilter=*.exe

; Output
OutputDir={#SourcePath}\Output
OutputBaseFilename=utify-setup
; Compress well but keep reasonable build time
Compression=lzma2/max
SolidCompression=yes

; Visuals
WizardStyle=modern
SetupIconFile={#SourcePath}\..\windows\runner\resources\app_icon.ico

; Minimum Windows version: Windows 10
MinVersion=10.0.17763

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Copy the entire Flutter Windows build output
Source: "{#SourcePath}\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}";        Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{commondesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; Offer to launch the app after install
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Clean up any leftover files on uninstall
Type: filesandordirs; Name: "{app}"
