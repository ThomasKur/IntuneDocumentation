# Release Notes

001: First Version
002: SetRegistryKey Function now allows to set empty values
003: Change CreateFolder Function to first create folder and then write the log. Otherwise whe function can fail, when the logfile folder doesn't exist.
004: Improved Log Action
005: Version is now taken from Variable, Log can be written to Windows Event, 
        ScriptName does no longer contain Script FileName, which is now available in $CurrentFileName 
006: ScriptPath not allways read correctly. Sometimes it was a relative path.
007: Better formating and Option to specify the Save As location
008: Jos Lieben: Fixed a few things and added Conditional Access Policies
009: Thomas Kurth: Adding AutoPilot Information
010: Thomas Kurth: Complete rewriting and using the Intune PowerShell module
        Added Partner Information
011: Added Application Protection Policies
        Tidied up to meet PSScriptAnalyzer Best Practice and removed some whitespace
012: Thomas Kurth: Added new sections:
        - Enrollment Page Configuration
        - Apple Push Certificate
        - Apple VPP
        - Device Categories
        - Exchange Connector
013: Thomas Kurth: Added new Sections:
        - PowerShellScripts
        - Application COnfiguration
        - Added new Template functionality

014: Thomas Kurth 
        - Document ADMX backed Profiles
