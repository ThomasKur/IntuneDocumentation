Function Convert-CamelCaseToDisplayName(){
    <#
    .SYNOPSIS
    This function to convert camel case to normal case
    .DESCRIPTION
    This function to convert camel case to normal case
    .EXAMPLE
    Convert-CamelCaseToDisplayName -Value "androidOsRestriction"
    Returns "Android Os Restriction"
    .NOTES
    NAME: Convert-CamelCaseToDisplayName
    #>
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        $Value
    )
    $newString = ""
    $stringChars = $value.GetEnumerator()
    $charIndex = 0
    foreach ($char in $stringChars) {
      # If upper and not first character, add a space
      if ([char]::IsUpper($char) -eq "True" -and $charIndex -gt 0) {
        $newString = $newString + " " + $char.ToString()
      } elseif ($charIndex -eq 0) {
        # If the first character, make it a capital always
        $newString = $newString + $char.ToString().ToUpper()
      } else {
        $newString = $newString + $char.ToString()
      }
      $charIndex++
    }
    return $newString
  }