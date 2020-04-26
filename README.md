# Intune Documentation

<img align="right" src="https://github.com/ThomasKur/IntuneDocumentation/raw/master/Logo/IntuneDocumentationLogo.png" width="300px" alt="Automatic Intune Documentation Logo">Automatic Intune Documentation to simplify the life of admins and consultants.

This Script will document:

- Configuration Policies
- Compliance Policies
- Device Enrollment Restrictions
- Terms and Conditions
- Applications (Only Assigned)
- Application Protection Policies
- AutoPilot Configuration
- Enrollment Page Configuration
- Apple Push Certificate
- Apple VPP
- Device Categories
- Exchange Connector
- Application Configuration
- PowerShell Scripts
- ADMX backed Configuration Profiles

## Usage

Since version 2.0.0 the Automatic Intune Documentation script is available in th PowerShell Gallery and therefore its much simpler to install and use it. You can just use these two commands:

```powershell

Install-Module IntuneDocumentation
Invoke-IntuneDocumentation -FullDocumentationPath c:\temp\IntuneDoc.docx

```

**Important:** Before using the Script the first time, you have to ensure, that you have installed the Microsoft.Graph.Intune and PSWord Module. To do that, you have to start PowerShell as an Adminstrator and install them:

```powershell

Install-Module Microsoft.Graph.Intune
Install-Module PSWord

```

## Additional Options

### UseTranslationBeta

When using this parameter the API names will be translated to the labels used in the Intune Portal. 
Note:
These Translations need to be created manually, only a few are translated yet. If you are willing 
to support this project. You can do this by [translating the json files](https://github.com/ThomasKur/IntuneDocumentation/blob/master/AddTranslation.md) which are mentioned to you when you generate the documentation in your tenant.

```powershell

Invoke-IntuneDocumentation -FullDocumentationPath c:\temp\IntuneDoc.docx -UseTranslationBeta

```

## Issues / Feedback

For any issues or feedback related to this module, please register for GitHub, and post your inquiry to this project's issue tracker.

## Thanks to

@Microsoftgraph for the PowerShell Examples: <https://github.com/microsoftgraph/powershell-intune-samples>

@guidooliveira for the PSWord Module, which enables the creation of the Word file. <https://github.com/guidooliveira/PSWord>

@joslieben for extending and improving the script

@dads07a for adding Application protection Policies to the documentation

@mirkocolemberg for the help and testing of the script.

![Created by baseVISION](https://www.basevision.ch/wp-content/uploads/2015/12/baseVISION-Logo_RGB.png)
