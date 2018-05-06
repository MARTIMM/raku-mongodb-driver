# run 'set-executionpolicy remotesigned' in powershell once
# run as admin in powershell
# or run as admin from cmd;
#   > powershell "& ""C:\users\juhim\mt\p6\myscript.ps1"""'

choco feature enable -n allowGlobalConfirmation
choco feature enable -n allowEmptyChecksums

$workdir = "C:\projects\mongo-perl6-driver"
$mdbdir = "MDB"
$mdbname = "mongodb-win32-x86_64-2008plus-ssl-3.6.4"

# install mongodb server
# ok method 1
# choco install mongodb
#SET PATH="C:\Program Files\MongoDB\Server\3.6\bin;%PATH%"

# method 2
Invoke-WebRequest -Uri "https://downloads.mongodb.org/win32/$mdbname.zip" -OutFile "$workdir\$mdbdir\MDB\mongodb.zip"
Expand-Archive "$workdir\$mdbdir\mongodb.zip" "$workdir\$mdbdir"
mklink /J "$workdir\$mdbdir\MDB\bin" "C:\users\juhim\mt\p6\MDB\$mdbname\bin"

choco install strawberryperl
#SET PATH="C:\strawberry\c\bin;%PATH%"
#SET PATH="C:\strawberry\perl\site\bin;%PATH%"
#SET PATH="C:\strawberry\perl\bin;%PATH%"

Invoke-WebRequest -Uri "https://rakudo.org/latest/star/win64" -OutFile "C:\users\juhim\mt\p6\rakudo.msi"
msiexec /i "C:\users\juhim\mt\p6\rakudo.msi" /quiet /qn /norestart /log "C:\users\juhim\mt\p6\rakudo-install.log"


$path = "C:\users\juhim\mt\p6\MDB\$mdbname\bin;"

<#
$path = "C:\Program Files\MongoDB\Server\3.6\bin;" +
  "C:\strawberry\c\bin;" +
  "C:\strawberry\perl\site\bin;" +
  "C:\strawberry\perl\bin;" +
  "C:\rakudo\bin;" +
  "C:\rakudo\share\perl6\site\bin"
#>

[Environment]::SetEnvironmentVariable( "PATH", "$path%PATH%", "User")
