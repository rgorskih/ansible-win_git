
Set-StrictMode -Version 2.0
# Set $ErrorActionPreference to what's set during Ansible execution
$ErrorActionPreference = "Stop"

# Or instead of an args file, set $complex_args to the pre-processed module args
$complex_args = @{
    _ansible_check_mode = $false
    _ansible_diff = $false
    repo = "ssh://git@bitbucket.artec-group.com:7999/clb/test-repo.git"
    dest = "C:\test-repo"
    version = "master"
    update = $true
    force = $true
    recursive = $true
}

# Import any C# utils referenced with '#AnsibleRequires -CSharpUtil' or 'using Ansible.;
# The $_csharp_utils entries should be the context of the C# util files and not the path
Import-Module -Name "$($pwd.Path)\powershell\Ansible.ModuleUtils.AddType.psm1"
$_csharp_utils = @(
    [System.IO.File]::ReadAllText("$($pwd.Path)\csharp\Ansible.Basic.cs")
)
Add-CSharpType -References $_csharp_utils -IncludeDebugInfo

#!powershell
##AnsibleRequires -CSharpUtil Ansible.Basic
##AnsibleRequires -PowerShell Ansible.ModuleUtils.AddType

$spec = @{
    options = @{
        repo = @{ type = "str"; required = $true }
        dest = @{ type = "str"; required = $true }
        recursive = @{ type = "bool"; default = $true }
        version = @{ type = "str"; default = "HEAD" } 
        remote = @{ type = "str"; default = "origin"}
        update = @{ type = "bool"; default = $false }
        force = @{ type = "bool"; default = $false }
    }
    supports_check_mode = $false
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$repo = $module.Params.repo
$dest = $module.Params.dest
$recursive = $module.Params.recursive
$version = $module.Params.version
$remote = $module.Params.remote
$update = $module.Params.update
$force = $module.Params.force

$module.Result.changed = $false
$module.Result.msg = ""
$module.Result.before = $null
$module.Result.after = $null

function Invoke-Process {
    [CmdletBinding(SupportsShouldProcess)]
    param
        (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$FilePath,

        [Parameter()]
        [array]$ArgumentList,

        [Parameter()]
        [string]$WorkingDir
       )

    $ErrorActionPreference = 'Stop'

    $ProcessResult = @{}
    try {
        $ProcessStartInfo = New-Object System.Diagnostics.ProcessStartInfo
        $ProcessStartInfo.FileName = $FilePath
        $ProcessStartInfo.RedirectStandardError = $true
        $ProcessStartInfo.RedirectStandardOutput = $true
        $ProcessStartInfo.UseShellExecute = $false
        if ($WorkingDir) {
           $ProcessStartInfo.WorkingDirectory = $WorkingDir   
        }
        $ProcessStartInfo.WindowStyle = 'Hidden'
        $ProcessStartInfo.CreateNoWindow = $true
        if ($ArgumentList) {
            $ProcessStartInfo.Arguments = $ArgumentList
        }
        $Process = New-Object System.Diagnostics.Process
        $Process.StartInfo = $ProcessStartInfo
        $Process.Start() | Out-Null
        $Process.WaitForExit()
        $ProcessResult.Command = $FilePath
        $ProcessResult.Arguments = $ArgumentList
        $ProcessResult.StdOut = $Process.StandardOutput.ReadToEnd()
        $ProcessResult.StdErr = $Process.StandardError.ReadToEnd()
        $ProcessResult.ExitCode = $Process.ExitCode

        return $ProcessResult 

    }
    catch {
        exit
    }
}


function Add-GitRemote {
    $cmd_opts = @("remote", "add", "$remote", "$repo") 
    $ProcessResult  = $(Invoke-Process -FilePath git -ArgumentList $cmd_opts -WorkingDir $dest)
    if ( $ProcessResult.ExitCode -ne 0 ){
        $module.FailJson("Unable to add repo as a source: $($ProcessResult.StdErr)")
    } else {
        return $true
    }
}

function Clone-GitRepository {
    $cmd_opts = @()
    $cmd_opts += "clone"
    if ( $version -ne "master" ){
        $cmd_opts += "--branch"
        $cmd_opts += $version
    }
    $cmd_opts += "--origin"
    $cmd_opts += $remote
    $cmd_opts += $repo
    $cmd_opts += $dest
    $ProcessResult = Invoke-Process -FilePath git -ArgumentList $cmd_opts
    if ( $ProcessResult.ExitCode -ne 0 ){
        $module.FailJson("Unable to clone repository: $($ProcessResult.StdErr)")
    } else {
        return $true
    }
}

function Fetch-GitRepository {
    $cmd_opts = @("fetch")
    $ProcessResult  = $(Invoke-Process -FilePath git -ArgumentList $cmd_opts -WorkingDir $dest)
    if ( $ProcessResult.ExitCode -ne 0 ){
        $module.FailJson("Unable to fetch updates: $($ProcessResult.StdErr)")
    } else {
        return $true
    }  
}
function Check-GitBranches {
    $cmd_opts = @("branch")
    $ProcessResult  = $(Invoke-Process -FilePath git -ArgumentList $cmd_opts -WorkingDir $dest) 
    if ( $ProcessResult.ExitCode -ne 0 ){
        $module.FailJson("Unable to get local branches: $($ProcessResult.StdErr)")
    } else {
        return $ProcessResult.StdOut.contains("$version")
    }
}

function Check-RemoteBranchExists {
    $cmd_opts = @("ls-remote", "$repo", "refs/heads/$version")
    $ProcessResult  = $(Invoke-Process -FilePath git -ArgumentList $cmd_opts)
    if ( $ProcessResult.ExitCode -ne 0 ){
        $module.FailJson("Unable to get remote branches: $($ProcessResult.StdErr)")
    } else {
        return $ProcessResult.StdOut.contains("$version")
    }
}

function Check-RemoteExists {
    $cmd_opts = @("remote", "-v")
    $ProcessResult  = $(Invoke-Process -FilePath git -ArgumentList $cmd_opts -WorkingDir $dest)
    if ( $ProcessResult.ExitCode -ne 0 ){
        $module.FailJson("Unable to get list of remote sources: $($ProcessResult.StdErr)")
    } else {
        return $ProcessResult.StdOut.contains("$repo")
    }
}

function Get-GitRepositoryVersion {
   [CmdletBinding()]
    
    $cmd_opts = @("rev-parse", "HEAD")
    $ProcessResult  = $(Invoke-Process -FilePath git -ArgumentList $cmd_opts -WorkingDir $dest)
    if ( $ProcessResult.ExitCode -ne 0 ){
        $module.FailJson("Unable to get sha1 from local repository: $($ProcessResult.StdErr)")
    } else {
        return $ProcessResult.StdOut.Replace("`n", "")
    }
}

function Get-GitRepositoryVersionRemote {
    [CmdletBinding()]
    $cmd_opts = @("ls-remote", "$repo", "$version")
    $ProcessResult  = $(Invoke-Process -FilePath git -ArgumentList $cmd_opts)
    if ( $ProcessResult.ExitCode -ne 0 ){
        $module.FailJson("Unable to get branches from remote repository: $($ProcessResult.StdErr)")
    } else {
        return $ProcessResult.StdOut.Split()[0]
    }

}

function Get-GitUncommited {
    [CmdletBinding()]
    param (
        [Parameter()]
        [String]
        $FolderPath = $dest
    )
    Write-Host "here" $FolderPath
    $cmd_opts = @("status", "--porcelain")
    $ProcessResult  = $(Invoke-Process -FilePath git -ArgumentList $cmd_opts -WorkingDir $FolderPath)
    Write-Host "here"

    if ( $ProcessResult.ExitCode -ne 0 ){
        $module.FailJson("Unable to get list of uncommited work: $($ProcessResult.StdErr)")
    } else {
        return $ProcessResult.StdOut.Replace("`n", "")
    }
}

function Reset-GitRepository {
    [CmdletBinding()]
    param (
        [Parameter()]
        [String]
        $FolderPath = $dest
    )
    $cmd_opts = @("reset", "--hard", "HEAD")
    $ProcessResult  = $(Invoke-Process -FilePath git -ArgumentList $cmd_opts -WorkingDir $FolderPath)
    if ( $ProcessResult.ExitCode -ne 0 ){
        $module.FailJson("Unable to reset repository: $($ProcessResult.StdErr)")
    } else {
        return $true
    }
}

function Get-SubmodulePaths {
    $cmd_opts = @("config", "--file .gitmodules", "--get-regexp", "path" )
    # Get submodule configuration from .gitmodules file
    $submoduleConfig = Invoke-Process -FilePath "git" -ArgumentList $cmd_opts -WorkingDir $dest

    if ($submoduleConfig.ExitCode -eq 0) {
        # Extract submodule paths from the output
        $submodulePaths = $submoduleConfig.StdOut -split "`n" | ForEach-Object {
            if ($_ -match "submodule\..*\.path (.*)") {
                $matches[1]
            }
        }
        return $submodulePaths
    } else {
        $module.FailJson("Error retrieving submodule paths: $($submoduleConfig.StdErr)")
    }
}

function Update-Submodule {
    param
        (
        [Parameter(Mandatory)]
        [string]$Submodule
        )
    $cmd_opts = @("submodule", "update", "--init", "--recursive", "$Submodule")
    $ProcessResult = Invoke-Process -FilePath "git" -ArgumentList $cmd_opts -WorkingDir $dest

    if ($ProcessResult.ExitCode -ne 0) {
        $matches = [regex]::Matches($ProcessResult.StdErr, "clone of '.*?' into submodule path '.*?' failed\n")
        $FailedSubs = ""
        foreach ($match in $matches) {
            $FailedSubs += $match.Value
        }
        $module.FailJson("Error updating submodule: $FailedSubs")
    } else {
        return $true
    }
}

# =================================================

if ( -Not $(Check-RemoteBranchExists)) {
    $module.FailJson("Unable to find branch $version in the $repo")
}

$IsCloned = $false
$IsUrlChanged = $false
$IsSubmoduleUpdated = $false

if ( -Not $(Test-Path -Path $dest) ) {
    $IsCloned = $(Clone-GitRepository)
    $module.Result.after = Get-GitRepositoryVersion
} elseif ( -Not $(Test-Path -Path "$dest\.git\config") ) {
    $module.FailJson("Path $dest exists, but not a valid git repository")
} elseif ( -not $update ) {
    $module.Result.msg = "No update flag, just printing version"
    $module.Result.before = Get-GitRepositoryVersion
    $module.Result.after = $module.Result.before
} else {
    if ($(Get-GitUncommited) -ne "") {
        if ($force) {
            if($(Reset-GitRepository)){
                $module.Result.changed = $true
            }
        } else {
            $module.Result.msg = "Skipping submodule update, because of uncommited changes (force = false)"
            $module.Result.before = Get-GitRepositoryVersion
            $module.Result.after = $module.Result.before
            $module.ExitJson()
        }

    }

    if (-Not $(Check-RemoteExists)) {
        $IsUrlChanged = Add-GitRemote
    }


    $LocalVersion = $(Get-GitRepositoryVersion)
    $RemoteVersion = $(Get-GitRepositoryVersionRemote)
    
    if ( $LocalVersion -ne $RemoteVersion) {
        Fetch-GitRepository | Out-Null

        if ($(Check-GitBranches) ){
            $git_checkout_opts =  @("checkout", "--force" ,"$version")
        } else {
            $git_checkout_opts = @("checkout", "--track", "-b", "$version", "$remote/$version")
        }

        $ProcessResult = $(Invoke-Process -FilePath git -ArgumentList $git_checkout_opts -WorkingDir $dest)

        if ( $ProcessResult.ExitCode -ne 0 ){
            $module.FailJson("Unable to checkout branch ${version}: $($ProcessResult.StdErr)")
        }

        $ProcessResult = Invoke-Process -FilePath git -ArgumentList @("reset", "--hard", "$remote/$version") -WorkingDir $dest
        if ( $ProcessResult.ExitCode -ne 0 ){
            $module.FailJson("Unable to reset branch $version to HEAD: $($ProcessResult.StdErr)")
        }
     
    } else {
        $module.Result.msg = "Skipping repository update, because already at HEAD. "
    }
    
    $module.Result.before = $LocalVersion
    $module.Result.after = $RemoteVersion
}


if ($recursive -And $(Test-Path -Path "$dest\.gitmodules") -And ($update -Or $IsCloned)){
    $SubmodulePaths = Get-SubmodulePaths
    $SubmodulesToUpdate = @()
    $RequiresUpdate = $false
    foreach ($SubmodulePath in $SubmodulePaths) {
        if (Test-Path -Path "$dest\$SubmodulePath"){
            $SubmoduleCurrentCommit = $(Invoke-Process -FilePath git -ArgumentList @("rev-parse", "HEAD") -WorkingDir "$dest\$SubmodulePath").StdOut
            $SubmoduleExpectedCommitUnparsed = $(Invoke-Process -FilePath git -ArgumentList @("ls-tree", "HEAD", "$SubmodulePath") -WorkingDir "$dest").StdOut
            $SubmoduleExpectedCommit = if ( $SubmoduleExpectedCommitUnparsed -match "commit (\w+)") { $matches[1] }

            if ($(Get-GitUncommited -FolderPath "$dest\$SubmodulePath") -ne "") {
                if ($force) {
                    if($(Reset-GitRepository $SubmodulePath)){
                        $module.Result.changed = $true
                    }
                } else {
                    $module.Result.msg += "Skipping submodule update, because of uncommited changes (force = false)"
                    $module.ExitJson()
                }
        
            }
            
            if ( $SubmoduleCurrentCommit -ne $SubmoduleExpectedCommit) {
                $IsSubmoduleUpdated = Update-Submodule -Submodule "$SubmodulePath"           
            }
        } else {
            $IsSubmoduleUpdated = Update-Submodule -Submodule "$SubmodulePath" 
        }
    
        $module.Result.msg += " Submodules updated."
    }
}

if ( $module.Result.before -ne $module.Result.after -Or $IsCloned -Or $IsUrlChanged -Or $IsSubmoduleUpdated){
    $module.Result.changed = $true
}

$module.ExitJson()
