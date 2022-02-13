Split-Path $myinvocation.mycommand.path | Set-Location

$script = {
    Write-Output "[$(Get-Date -Format G)] binary upgrader started"
    if(!(Test-Path -Path .\cfg.json)) {
        Write-Error "ConfigFileNotFoundException"
        exit 2
    }
    $config = Get-Content .\cfg.json | ConvertFrom-Json
    foreach($item in $config.PSObject.Properties) {
        switch($item.Name)
        {
            includes {
                $includes = $item.Value
            }
            excludes
            {
                $excludes = $item.Value
            }
            urls
            {
                $urls = $item.Value
            }
            regexv
            {
                $regexv = $item.Value
            }
            vcmd
            {
                $vcmd = $item.Value
            }
            regexdl
            {
                $regexdl = $item.Value
            }
            zipflags
            {
                $zipflags = $item.Value
            }
            binpath
            {
                $binpath = $item.Value
            }
            prod
            {
                $prod = $item.Value
            }
            devpath
            {
                $devpath = $item.Value
            }
        }
    }
    $bin = Get-ChildItem -Path C:\bin -Exclude $excludes -Name
    for($i=0; $i -lt $bin.Length; $i++) {
        $cmd = Invoke-Expression -Command "$($binpath)$($bin[$i]) $($vcmd[$i])"
        $version = [regex]::Match($cmd, $regexv[$i]).value
        #https://stackoverflow.com/questions/43582787/select-string-regex-in-powershell
        $web_response = (new-object System.Net.WebClient).DownloadString($urls[$i])
        $latestversion = [regex]::Match($web_response, $regexv[$i]).value
        $download_link = [regex]::Match($web_response, $regexdl[$i]).value
        if($download_link.LastIndexOf("http") -eq -1) {
            $download_link = $urls[$i] + $download_link
        }
        if($version -match $latestversion) {
            Write-Output "$($bin[$i]) latest version is installed ($($latestversion))"
        } else {
            Write-Output "New $($bin[$i]) version available (old $($version) new $($latestversion)). Downloading and installing from $($urls[$i]) now."
            #Start-Process chrome.exe $urls[$i]
            if($download_link.Substring($download_link.LastIndexOf("."),3) -match ".7z") {
                Invoke-WebRequest $download_link -OutFile "$($binpath)tmp.7z"
                if(!(Test-Path -Path "C:\Program Files\WinRAR")) {
                    Write-Error "WinRarNotFoundException"
                    exit 3
                }
                & "C:\Program Files\WinRAR\winrar" x "$($binpath)tmp.7z" $binpath
                Start-Sleep -Seconds 5
                $dir_name = (Get-ChildItem -Path $binpath | Where-Object {$_.Name -match $zipflags[0]}).Name
                Move-Item -Path "$($binpath)$($dir_name)$($zipflags[1])*.exe" -Destination $binpath -Force
                Start-Sleep -Seconds 3
                Remove-Item -Path "$binpath*" -Include $excludes -Exclude $includes  -Force -Recurse
                Remove-Item -Path "$($binpath)$($dir_name)" -Force -Recurse
                Write-Output "Installation successful."

            } else {
                Invoke-WebRequest $download_link -OutFile "$binpath\$($download_link.Substring($download_link.LastIndexOf("/") + 1))"
                Write-Output "Download successful."
                # LastIndexOf("/") +1 "app.exe" +0 "/app.exe"
            }
        }
    }
    if(-not $prod) {
        $includes = $includes | ForEach-Object { $_.Insert(0, $binpath) }
        Copy-Item -Path $includes -Destination $devpath
        #https://www.tutorialspoint.com/how-to-copy-multiple-files-in-powershell-using-copy-item
    }
}

Invoke-Command -ScriptBlock $script | Add-Content .\update_logfile.txt