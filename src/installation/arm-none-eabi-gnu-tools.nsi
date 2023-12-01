;-------------------------------
; Variables used in Command Line:
;
; BaseDir
; AppName
; AppNameStr
; AppRootNameStr
; PackageName
; InstallDirBase
; InstallDirVer


;-------------------------------
;Setup Variables:

    !define company "ARM Holdings"
    !define companyShort "ARM"

    !define notefile "${BaseDir}/share/doc/gcc-arm-none-eabi/readme.txt"
    !define licensefile "${BaseDir}/share/doc/gcc-arm-none-eabi/license.txt"

    !define regkey "SOFTWARE\${companyShort}\${AppNameStr}"
    !define regunverkey "SOFTWARE\${companyShort}\${AppRootNameStr}"
    !define uninstkey "Software\Microsoft\Windows\CurrentVersion\Uninstall\${AppName}"
    !define uninstaller "uninstall.exe"

    !define setup "${PackageName}.exe"


;-------------------------------
; Include Modern UI, EnvVarUpdate and File tools

    !include "MUI2.nsh"
    !addincludedir "${IncDir}"
    !include "EnvVarUpdate.nsh"
    !include "FileFunc.nsh"

;-------------------------------
; Macros for handling command line options

    !insertmacro GetParameters
    !insertmacro GetOptions

;-------------------------------
; System parameters

    ShowInstDetails hide
    ShowUninstDetails hide
    SetCompressor lzma

    Name "${AppName}"
    Caption "${AppNameStr}"

    InstallDir "$PROGRAMFILES\${InstallDirBase}\${InstallDirVer}"
    InstallDirRegKey HKLM "${regkey}" ""

;--------------------------------
; Interface Settings

    !define MUI_ABORTWARNING
    !define MUI_LANGDLL_ALLLANGUAGES


; ------------------
; Custom functions and var:

    var gcc_var_checkbox
    var env_path_checkbox
    var reg_key_checkbox
    var gcc_var_state
    var env_path_state
    var reg_key_state

    Function UpdatePath
        ReadEnvStr $0 PATH
        StrLen $1 $0
        StrLen $2 "$INSTDIR\bin"
        IntOp $3 $1 + $2
        IntOp $4 $3 + 1

        ${If} $4 > ${NSIS_MAX_STRLEN}
            MessageBox MB_OK|MB_ICONINFORMATION "Current PATH length ($1) too long to modify in installer; set manually if needed" /SD IDOK
        ${Else}
            ${EnvVarUpdate} $0 "PATH" "P" "HKCU" "$INSTDIR\bin"
        ${EndIf}
    FunctionEnd

    Function PostInstallTasks
        ${If} $gcc_var_state <> 0
            Exec '"$INSTDIR\bin\gccvar.bat"'
        ${EndIf}
        ${If} $env_path_state <> 0
            Call UpdatePath
        ${EndIf}
        ${If} $reg_key_state <> 0
            WriteRegStr HKLM "${regkey}" "InstallFolder" "$INSTDIR"
            WriteRegStr HKLM "${regunverkey}" "InstallFolder" "$INSTDIR"
        ${EndIf}
    FunctionEnd

    Function customFinishShow
        ${NSD_CreateCheckbox} 120u 110u 100% 10u "Launch gccvar.bat"
        Pop $gcc_var_checkbox
        ${NSD_Check} $gcc_var_checkbox
        ${NSD_CreateCheckbox} 120u 120u 100% 10u "Add path to environment variable"
        Pop $env_path_checkbox
        ${If} $env_path_state <> 0
            ${NSD_Check} $env_path_checkbox
        ${EndIf}
        ${NSD_CreateCheckbox} 120u 130u 100% 10u "Add registry information"
        Pop $reg_key_checkbox
        ${NSD_Check} $reg_key_checkbox
        SetCtlColors $env_path_checkbox "" "ffffff"
        SetCtlColors $gcc_var_checkbox "" "ffffff"
        SetCtlColors $reg_key_checkbox "" "ffffff"
    FunctionEnd

    Function customFinishCall
        ${NSD_GetState} $gcc_var_checkbox $gcc_var_state
        ${NSD_GetState} $env_path_checkbox $env_path_state
        ${NSD_GetState} $reg_key_checkbox $reg_key_state
        Call PostInstallTasks
    FunctionEnd

;---------------------------------
; Pages

    !define MUI_WELCOMEPAGE_TITLE_3LINES
    !insertmacro MUI_PAGE_WELCOME
    !insertmacro MUI_PAGE_LICENSE ${licensefile}
    !insertmacro MUI_PAGE_DIRECTORY
    !insertmacro MUI_PAGE_INSTFILES
    !define MUI_FINISHPAGE_TITLE_3LINES
    !define MUI_FINISHPAGE_SHOWREADME "$INSTDIR\share\doc\gcc-arm-none-eabi\readme.txt"
    !define MUI_PAGE_CUSTOMFUNCTION_SHOW customFinishShow
    !define MUI_PAGE_CUSTOMFUNCTION_LEAVE customFinishCall
    !insertmacro MUI_PAGE_FINISH


    !insertmacro MUI_UNPAGE_CONFIRM
    !insertmacro MUI_UNPAGE_INSTFILES
    !define MUI_FINISHPAGE_TITLE_3LINES
    !insertmacro MUI_UNPAGE_FINISH

;--------------------------------
; Languages

    !insertmacro MUI_LANGUAGE "English"
    !insertmacro MUI_LANGUAGE "Afrikaans"
    !insertmacro MUI_LANGUAGE "Albanian"
    !insertmacro MUI_LANGUAGE "Arabic"
    !insertmacro MUI_LANGUAGE "Basque"
    !insertmacro MUI_LANGUAGE "Belarusian"
    !insertmacro MUI_LANGUAGE "Bosnian"
    !insertmacro MUI_LANGUAGE "Breton"
    !insertmacro MUI_LANGUAGE "Bulgarian"
    !insertmacro MUI_LANGUAGE "Catalan"
    !insertmacro MUI_LANGUAGE "Croatian"
    !insertmacro MUI_LANGUAGE "Czech"
    !insertmacro MUI_LANGUAGE "Danish"
    !insertmacro MUI_LANGUAGE "Dutch"
    !insertmacro MUI_LANGUAGE "Estonian"
    !insertmacro MUI_LANGUAGE "Farsi"
    !insertmacro MUI_LANGUAGE "Finnish"
    !insertmacro MUI_LANGUAGE "French"
    !insertmacro MUI_LANGUAGE "Galician"
    !insertmacro MUI_LANGUAGE "German"
    !insertmacro MUI_LANGUAGE "Greek"
    !insertmacro MUI_LANGUAGE "Hebrew"
    !insertmacro MUI_LANGUAGE "Hungarian"
    !insertmacro MUI_LANGUAGE "Icelandic"
    !insertmacro MUI_LANGUAGE "Indonesian"
    !insertmacro MUI_LANGUAGE "Irish"
    !insertmacro MUI_LANGUAGE "Italian"
    !insertmacro MUI_LANGUAGE "Japanese"
    !insertmacro MUI_LANGUAGE "Korean"
    !insertmacro MUI_LANGUAGE "Kurdish"
    !insertmacro MUI_LANGUAGE "Latvian"
    !insertmacro MUI_LANGUAGE "Lithuanian"
    !insertmacro MUI_LANGUAGE "Luxembourgish"
    !insertmacro MUI_LANGUAGE "Macedonian"
    !insertmacro MUI_LANGUAGE "Malay"
    !insertmacro MUI_LANGUAGE "Mongolian"
    !insertmacro MUI_LANGUAGE "Norwegian"
    !insertmacro MUI_LANGUAGE "NorwegianNynorsk"
    !insertmacro MUI_LANGUAGE "Polish"
    !insertmacro MUI_LANGUAGE "PortugueseBR"
    !insertmacro MUI_LANGUAGE "Portuguese"
    !insertmacro MUI_LANGUAGE "Romanian"
    !insertmacro MUI_LANGUAGE "Russian"
    !insertmacro MUI_LANGUAGE "SerbianLatin"
    !insertmacro MUI_LANGUAGE "Serbian"
    !insertmacro MUI_LANGUAGE "SimpChinese"
    !insertmacro MUI_LANGUAGE "Slovak"
    !insertmacro MUI_LANGUAGE "Slovenian"
    !insertmacro MUI_LANGUAGE "SpanishInternational"
    !insertmacro MUI_LANGUAGE "Spanish"
    !insertmacro MUI_LANGUAGE "Swedish"
    !insertmacro MUI_LANGUAGE "Thai"
    !insertmacro MUI_LANGUAGE "TradChinese"
    !insertmacro MUI_LANGUAGE "Turkish"
    !insertmacro MUI_LANGUAGE "Ukrainian"
    !insertmacro MUI_LANGUAGE "Uzbek"

;--------------------------------
;;Reserve Files
;
;    ;If you are using solid compression, files that are required before
;    ;the actual installation should be stored first in the data block,
;    ;because this will make your installer start faster.
     !insertmacro MUI_RESERVEFILE_LANGDLL

;--------------------------------
;;Installer Sections

Section "install" installation
    SetShellVarContext all

    ; write uninstall strings
    WriteRegStr HKLM "${uninstkey}" "DisplayName" "${AppName} (remove only)"
    WriteRegStr HKLM "${uninstkey}" "UninstallString" '"$INSTDIR\${uninstaller}"'
    WriteRegStr HKLM "${uninstkey}" "Publisher" "${company}"
    WriteRegStr HKLM "${uninstkey}" "DisplayVersion" "${InstallDirVer}"

    SetOutPath $INSTDIR

    ; Package the files
    File /r "${BaseDir}\*"

    ; The uninstaller
    WriteUninstaller "$INSTDIR\${uninstaller}"

    ; Start Menu
    createDirectory "$SMPROGRAMS\${AppName}"
    createShortCut "$SMPROGRAMS\${AppName}\GCC Command Prompt.lnk" "$INSTDIR\bin\gccvar.bat" "" ""
    createShortCut "$SMPROGRAMS\${AppName}\Documentation.lnk" "$INSTDIR\share\doc\gcc-arm-none-eabi\" "" ""
    createShortCut "$SMPROGRAMS\${AppName}\Uninstall ${AppNameStr}.lnk" "$INSTDIR\${uninstaller}" "" ""
    IfSilent 0 +2
        Call PostInstallTasks

SectionEnd

; Init function
    Function .onInit
        !insertmacro MUI_LANGDLL_DISPLAY
        ${GetParameters} $R0
        ClearErrors
        ${GetOptions} $R0 "/P" $1
        IfErrors +2 0
            StrCpy $env_path_state 1
        ${GetOptions} $R0 "/R" $1
        IfErrors +2 0
            StrCpy $reg_key_state 1
    FunctionEnd

;-------------------------------
;Uninstaller Sections
Section "Uninstall"
    SetShellVarContext all

    DeleteRegKey HKLM "${uninstkey}"
    DeleteRegKey HKLM "${regkey}"
    DeleteRegKey HKLM "${regunverkey}"
    ${un.EnvVarUpdate} $0 "PATH" "R" "HKCU" "$INSTDIR\bin"

    RMDir /r "$INSTDIR\*"
    Delete "$INSTDIR\*"
    RMDir $INSTDIR
    StrCpy $0 "$PROGRAMFILES\${InstallDirBase}"
    Call un.DeleteDirIfEmpty
    RMDir /r "$SMPROGRAMS\${AppName}"


SectionEnd

;--------------------------------
;;Uninstaller Functions

    Function un.onInit
      !insertmacro MUI_UNGETLANGUAGE
    FunctionEnd

; The function to delete empty dir
    Function un.DeleteDirIfEmpty
      FindFirst $R0 $R1 "$0\*.*"
      strcmp $R1 "." 0 NoDelete
       FindNext $R0 $R1
       strcmp $R1 ".." 0 NoDelete
        ClearErrors
        FindNext $R0 $R1
        IfErrors 0 NoDelete
         FindClose $R0
         Sleep 1000
         RMDir "$0"
      NoDelete:
       FindClose $R0
    FunctionEnd

;EOF

