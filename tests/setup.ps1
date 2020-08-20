icacls data /grant:r "${env:UserName}:F" /T
Remove-Item -Path "data" -Recurse
New-Item -Path "data" -ItemType "directory"

New-Item -Path "data\file" -ItemType "file"
New-Item -Path "data\dir" -ItemType "directory"

New-Item -Path "data\file_access_denied" -ItemType "file"
icacls data\file_access_denied /deny "${env:UserName}:F"

New-Item -Path "data\file_read_only" -ItemType "file"
icacls data\file_read_only /deny "${env:UserName}:W"


New-Item -Path "data\dir_access_denied" -ItemType "directory"
icacls data\dir_access_denied /deny "${env:UserName}:F"

New-Item -Path "data\dir_read_only" -ItemType "directory"
icacls data\dir_read_only /deny "${env:UserName}:W"

New-Item -Path "data\mru_ok.json" -ItemType "file" -Value '{"Video" : ["Entry One", "Entry Two"]}'

New-Item -Path "data\mru_invalid.json" -ItemType "file" -Value '{"Video" : [1, 3]}'

New-Item -Path "data\ten_bytes" -ItemType "file" -Value "1234567890"
New-Item -Path "data\touch_mod_time" -ItemType "file"
(Get-ChildItem -Path "data\touch_mod_time").LastWriteTime = (Get-ChildItem -Path "data\touch_mod_time").LastWriteTime.AddSeconds(-1)

New-Item -Path "data\dir_iterator" -ItemType "directory"
New-Item -Path "data\dir_iterator\1.a" -ItemType "file"
New-Item -Path "data\dir_iterator\2.a" -ItemType "file"
New-Item -Path "data\dir_iterator\1.b" -ItemType "file"
New-Item -Path "data\dir_iterator\2.b" -ItemType "file"

Copy-Item -Path "${PSScriptRoot}\options" -Destination "data\options" -Recurse

New-Item -Path "data\vfr" -ItemType "directory"
Copy-Item -Path "${PSScriptRoot}\vfr" -Destination "data\vfr\in" -Recurse
New-Item -Path "data\vfr\out" -ItemType "directory"

Copy-Item -Path "${PSScriptRoot}\keyframe" -Destination "data\keyframe" -Recurse
