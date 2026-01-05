; Inno Setup script for Avanco Missionario
#define MyAppName "Avanço Missionário"
#define MyAppVersion "0.0.0"
#define MyAppPublisher "Wieth Tecnologia"
#define MyAppURL "http://kelvin.sh"
#define MyAppExeName "advance.exe"

[Setup]
AppId={{AAFC44A9-73A6-4F1B-A142-1561E06B9349}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\AvancoMissionario
UninstallDisplayIcon={app}\{#MyAppExeName}
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
PrivilegesRequiredOverridesAllowed=dialog
OutputDir=..\\dist
OutputBaseFilename=AvancoMissionario-{#MyAppVersion}-Setup
SetupIconFile=..\\assets\\acev-icon.ico
SolidCompression=yes
WizardStyle=modern dynamic

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\\build\\windows\\x64\\runner\\Release\\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\\build\\windows\\x64\\runner\\Release\\file_selector_windows_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\\build\\windows\\x64\\runner\\Release\\flutter_windows.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\\build\\windows\\x64\\runner\\Release\\msvcp140.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\\build\\windows\\x64\\runner\\Release\\msvcp140_1.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\\build\\windows\\x64\\runner\\Release\\msvcp140_2.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\\build\\windows\\x64\\runner\\Release\\sqlite3.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\\build\\windows\\x64\\runner\\Release\\sqlite3_flutter_libs_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\\build\\windows\\x64\\runner\\Release\\vcruntime140.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\\build\\windows\\x64\\runner\\Release\\vcruntime140_1.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\\build\\windows\\x64\\runner\\Release\\data\\*"; DestDir: "{app}\\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
