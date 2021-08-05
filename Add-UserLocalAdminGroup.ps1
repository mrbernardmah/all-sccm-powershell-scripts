Param(
[Parameter(Mandatory=$True)]
[string]$UserName
)
Add-LocalGroupMember -Group "Administrators" -Member $UserName