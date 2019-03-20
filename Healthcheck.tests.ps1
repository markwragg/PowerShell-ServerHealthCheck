
Describe "Server Health -- $Env:COMPUTERNAME" {

    Context "Disk Health" {

        $Disks = Get-Disk

        ForEach ($Disk in $Disks) {
            It "Disk $($Disk.FriendlyName) should be healthy" {
                $Disk.HealthStatus | Should Be 'Healthy'
            }
        }
    }

    Context "Drive Health" {

        $Drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Name -ne 'TestDrive' -And ($_.Free + $_.Used) -gt 0 }

        ForEach ($Drive in $Drives) {
            $DrivePercentFree = ($Drive.Free / ($Drive.Free + $Drive.Used)) * 100 
            
            It "Drive $($Drive.Name) should have at least 10% freespace" {
                $DrivePercentFree | Should BeGreaterThan 10
            }
        }
    }

    Context "CPU Health" {
        
        $Processors = Get-WmiObject Win32_Processor

        ForEach ($Processor in $Processors) {
            It "$($Processor.Name) should have less than 95% CPU load" {
                $Processor.LoadPercentage | Should Not BeGreaterThan 95
            }
        }
    }

    Context "Memory Health" {
        
        $Memory = Get-WmiObject -Class Win32_OperatingSystem -Property 'TotalVisibleMemorySize','FreePhysicalMemory'
        $MemoryPercentFree = ($Memory.FreePhysicalMemory / $Memory.TotalVisibleMemorySize) * 100
        
        It "Should have at least 10% free memory" {
            $MemoryPercentFree | Should BeGreaterThan 10
        }
    }

    Context "Network Health" {
        $NetworkConfig = Get-wmiObject Win32_networkAdapterConfiguration | Where-Object { $_.IPEnabled }

        ForEach ($DNSServer in $NetworkConfig.DNSServerSearchOrder) {
            It "Should be able to resolve google.com in DNS via server $DNSServer" {
                (Resolve-DnsName -Name google.com -Server $DNSServer).Count | Should BeGreaterThan 0
            }
        }

        It "Should be able to connect to google.com via HTTP" {
            (Test-NetConnection google.com -CommonTCPPort HTTP).TcpTestSucceeded | Should Be $true
        }

        ForEach ($DNSDomainSuffix in $NetworkConfig.DNSDomainSuffixSearchOrder) {
            It "Should be able to resolve the DNS Domain suffix $DNSDomainSuffix" {
                (Resolve-DnsName -Name $DNSDomainSuffix).Count | Should BeGreaterThan 0
            }
        }
        

    }

    Context "Service Health" {

        $Services = Get-WmiObject -Query "Select * From Win32_Service Where StartMode='Auto'" | Where-Object { -not ($_.State -eq 'Stopped' -And $_.ExitCode -eq 0) }

        ForEach ($Service in $Services) {
            It "Service $($Service.Name) should be running" {
                $Service.State | Should Be 'Running'
            }
        }
    }

    Context "Event Log Health" {

        ForEach ($EventLog in 'System','Application') {

            $EventLogErrors = Get-EventLog -LogName $EventLog -After (Get-Date).AddHours(-3) -EntryType Error

            It "$EventLog Event Log should not have errors from the last 3 hours" {
                $EventLogErrors.Count | Should Be 0
            }

            If ($EventLogErrors) {
                Write-Host -ForegroundColor Yellow ($EventLogErrors | Format-Table | Out-String)
            }
        }
    }
}