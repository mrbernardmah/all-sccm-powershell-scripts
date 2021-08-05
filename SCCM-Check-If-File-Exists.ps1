# Enter Path to file (not directory)
Param (
    [String]$Path2File
)

Test-Path -Path $Path2File -PathType Leaf