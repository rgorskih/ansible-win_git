
Set-StrictMode -Version 2.0
# Set $ErrorActionPreference to what's set during Ansible execution
$ErrorActionPreference = "Stop"

# Or instead of an args file, set $complex_args to the pre-processed module args
$complex_args = @{
    _ansible_check_mode = $false
    _ansible_diff = $false
    repo = "ssh://git@bitbucket.artec-group.com:7999/clb/calibrator-scripts-and-binaries.git"
    dest = "C:\\calibrator-scripts-and-binaries"
    version = "NOJIRA-bump-scripts"
    update = $true
    force = $true
}
    # repo = "ssh://git@bitbucket.artec-group.com:7999/clb/calibrator-builds.git"
    # branch = "master"
    # clone = $false
    # update = $false
    # recursive = $true
    # replace_dest = $true
    # accept_hostkey = $false
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
        # branch = @{ type = "str"; default = "master" }
        # clone = @{ type = "bool"; default = $true } 
        # update = @{ type = "bool"; default = $false } 
        # replace_dest = @{ type = "bool"; default = $false } 
        # accept_hostkey  = @{ type = "bool"; default = $false } 
    }
    supports_check_mode = $false
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)


# # Remove dest if it exests
# function PrepareDestination {
#     [CmdletBinding()]
#     param()
#     if ((Test-Path $dest) -And (-Not $check_mode)) {
#         try {
#             Remove-Item $dest -Force -Recurse | Out-Null
#             Set-Attr $ProcessResult "cmd_msg" "Successfully removed dir $dest."
#             Set-Attr $ProcessResult "changed" $true
#         }
#         catch {
#             $ErrorMessage = $_.Exception.Message
#             Fail-Json $ProcessResult "Error removing $dest! Msg: $ErrorMessage"
#         }
#     }
# }

# # SSH Keys
# function CheckSshKnownHosts {
#     [CmdletBinding()]
#     param()
#     # Get the Git Hostrepo
#     $gitServer = $($repo -replace "^(\w+)\@([\w-_\.]+)\:(.*)$", '$2')
#     & cmd /c ssh-keygen.exe -F $gitServer | Out-Null
#     $rc = $LASTEXITCODE

#     if ($rc -ne 0) {
#         # Host is unknown
#         if ($accept_hostkey) {
#             # workaroung for disable BOM
#             # https://github.com/tivrobo/ansible-win_git/issues/7
#             $sshHostKey = & cmd /c ssh-keyscan.exe -t ecdsa-sha2-nistp256 $gitServer
#             $sshHostKey += "`n"
#             $sshKnownHostsPath = Join-Path -Path $env:Userprofile -ChildPath \.ssh\known_hosts
#             [System.IO.File]::AppendAllText($sshKnownHostsPath, $sshHostKey, $(New-Object System.Text.UTF8Encoding $False))
#         }
#         else {
#             Fail-Json -obj $ProcessResult -message  "Host is not known!"
#         }
#     }
# }

# function CheckSshIdentity {
#     [CmdletBinding()]
#     param()

#     & cmd /c git.exe ls-remote $repo | Out-Null
#     $rc = $LASTEXITCODE
#     if ($rc -ne 0) {
#         Fail-Json -obj $ProcessResult -message  "Something wrong with connection!"
#     }
# }

# function get_version {
#     # samples the version of the git repo
#     # example:  git rev-parse HEAD
#     #           output: 931ec5d25bff48052afae405d600964efd5fd3da
#     [CmdletBinding()]
#     param(
#         [Parameter(Mandatory = $false, Position = 0)] [string] $refs = "HEAD"
#     )
#     $git_opts = @()
#     $git_opts += "--no-pager"
#     $git_opts += "rev-parse"
#     $git_opts += "$refs"
#     $git_cmd_output = ""

#     [hashtable]$Return = @{}
#     Set-Location $dest; &git $git_opts | Tee-Object -Variable git_cmd_output | Out-Null
#     $Return.rc = $LASTEXITCODE
#     $Return.git_output = $git_cmd_output

#     return $Return
# }

# function get_branch_status {
#     # returns current brunch of the git repo
#     # example:  git rev-parse --abbrev-ref HEAD
#     #           output: master
#     # [CmdletBinding()]
#     # param()

#     $git_opts = @()
#     $git_opts += "--no-pager"
#     $git_opts += "-C"
#     $git_opts += "$dest"
#     $git_opts += "rev-parse"
#     $git_opts += "--abbrev-ref"
#     $git_opts += "HEAD"
#     $branch_status = ""

#     # [hashtable]$Return = @{}
#     # Set-Location -Path $dest
#     Start-Process -FilePath git -ArgumentList $git_opts -Wait -NoNewWindow | Tee-Object -Variable branch_status | Out-Null
#     # $Return.rc = $LASTEXITCODE
#     # $Return.git_output = $branch_status

#     # return $Return
#     return $branch_status
# }

# function checkout {
#     [CmdletBinding()]
#     param()
#     [hashtable]$Return = @{}
#     $local_git_output = ""

#     $git_opts = @()
#     $git_opts += "--no-pager"
#     $git_opts += "switch"
#     $git_opts += "$branch"
#     Set-Location -Path $dest
#     Start-Process -FilePath git -ArgumentList $git_opts -Wait -NoNewWindow | Tee-Object -Variable local_git_output | Out-Null
#     $Return.rc = $LASTEXITCODE
#     $Return.git_output = $local_git_output

#     Set-Location -Path $dest; &git rev-parse --abbrev-ref HEAD | Tee-Object -Variable branch_status | Out-Null
#     Set-Attr $ProcessResult.win_git "branch_status" "$branch_status"

#     if ( $branch_status -ne "$branch" ) {
#         Fail-Json $ProcessResult "Failed to checkout to $branch"
#     }

#     return $Return
# }

# function clone {
#     # git clone command
#     [CmdletBinding()]
#     param()

#     Set-Attr $ProcessResult.win_git "method" "clone"
#     [hashtable]$Return = @{}
#     $local_git_output = ""

#     $git_opts = @()
#     $git_opts += "--no-pager"
#     $git_opts += "clone"
#     $git_opts += $repo
#     $git_opts += $dest
#     $git_opts += "--branch"
#     $git_opts += $branch
#     if ($recursive) {
#         $git_opts += "--recursive"
#     }

#     Set-Attr $ProcessResult.win_git "git_opts" "$git_opts"

#     # Only clone if $dest does not exist and not in check mode
#     if ( (-Not (Test-Path -Path $dest)) -And (-Not $check_mode)) {
#         Start-Process -FilePath git -ArgumentList $git_opts -Wait -NoNewWindow | Tee-Object -Variable local_git_output | Out-Null
#         $Return.rc = $LASTEXITCODE
#         $Return.git_output = $local_git_output
#         Set-Attr $ProcessResult "cmd_msg" "Successfully cloned $repo into $dest."
#         Set-Attr $ProcessResult "changed" $true
#         Set-Attr $ProcessResult.win_git "return_code" $LASTEXITCODE
#         Set-Attr $ProcessResult.win_git "git_output" $local_git_output
#     }
#     else {
#         $Return.rc = 0
#         $Return.git_output = $local_git_output
#         Set-Attr $ProcessResult "cmd_msg" "Skipping Clone of $repo becuase $dest already exists"
#         Set-Attr $ProcessResult "changed" $false
#     }

#     if (($update) -and (-Not $ProcessResult.changed)) {
#         update
#     }

#     # Check if branch is the correct one
#     Set-Location -Path $dest; &git rev-parse --abbrev-ref HEAD | Tee-Object -Variable branch_status | Out-Null
#     Set-Attr $ProcessResult.win_git "branch_status" "$branch_status"

#     if ( $branch_status -ne "$branch" ) {
#         Fail-Json $ProcessResult "Branch $branch_status is not $branch"
#     }

#     return $Return
# }

# function update {
#     # git clone command
#     [CmdletBinding()]
#     param()

#     Set-Attr $ProcessResult.win_git "method" "pull"
#     [hashtable]$Return = @{}
#     $git_output = ""

#     # Build Arguments
#     $git_opts = @()
#     $git_opts += "--no-pager"
#     $git_opts += "pull"
#     $git_opts += "origin"
#     $git_opts += "$branch"

#     Set-Attr $ProcessResult.win_git "git_opts" "$git_opts"

#     # Only update if $dest does exist and not in check mode
#     if ((Test-Path -Path $dest) -and (-Not $check_mode)) {
#         # move into correct branch before pull
#         checkout
#         # perform git pull
#         Set-Location -Path $dest
#         Start-Process -FilePath git -ArgumentList $git_opts -Wait -NoNewWindow | Tee-Object -Variable git_output | Out-Null
#         $Return.rc = $LASTEXITCODE
#         $Return.git_output = $git_output
#         Set-Attr $ProcessResult "cmd_msg" "Successfully updated $repo to $branch."
#         # TODO: handle correct status change when using update
#         Set-Attr $ProcessResult "changed" $true
#         Set-Attr $ProcessResult.win_git "return_code" $LASTEXITCODE
#         Set-Attr $ProcessResult.win_git "git_output" $git_output
#     }
#     else {
#         $Return.rc = 0
#         $Return.git_output = $local_git_output
#         Set-Attr $ProcessResult "cmd_msg" "Skipping update of $repo"
#     }

#     return $Return
# }


# if ($repo -eq ($null -or "")) {
#     Fail-Json $ProcessResult "Repository cannot be empty or `$null"
# }
# Set-Attr $ProcessResult.win_git "repo" $repo
# Set-Attr $ProcessResult.win_git "dest" $dest

# Set-Attr $ProcessResult.win_git "replace_dest" $replace_dest
# Set-Attr $ProcessResult.win_git "accept_hostkey" $accept_hostkey
# Set-Attr $ProcessResult.win_git "update" $update
# Set-Attr $ProcessResult.win_git "branch" $branch


# try {

#     FindGit

# #     if ($replace_dest) {
# #         PrepareDestination
# #     }
# #     if ([system.uri]::IsWellFormedUriString($repo, [System.UriKind]::Absolute)) {
# #         # http/https repositories doesn't need Ssh handle
# #         # fix to avoid wrong usage of CheckSshKnownHosts CheckSshIdentity for http/https
# #         Set-Attr $ProcessResult.win_git "valid_url" "$repo is valid url"
# #     }
# #     else {
# #         CheckSshKnownHosts
# #         CheckSshIdentity
# #     }
# #     if ($update) {
# #         update
# #     }
# #     if ($clone) {
# #         clone
# #     }
# }
# catch {
#     $module.FailJson("Error cloning $repo to $dest!", $_.Exception.Message)
# }

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



function Clone-GitRepository {
    [CmdletBinding()]

    $cmd_opts = @()
    $cmd_opts += "clone"
    if ($recursive){
        $cmd_opts += "--recursive"
    }
    if ( $version -ne "HEAD" ){
        $cmd_opts += "--branch"
        $cmd_opts += $version
    }
    $cmd_opts += "--origin"
    $cmd_opts += $remote
    $cmd_opts += $repo
    $cmd_opts += $dest
    $ProcessResult = Invoke-Process -FilePath git -ArgumentList $cmd_opts
    if ( $ProcessResult.ExitCode -ne 0 ){
        $module.FailJson($($ProcessResult.StdErr))
    } else {
        $module.Result.changed = $true
    }
}

# function Update-GitRepository {
#     [CmdletBinding()]
   
# }

function Get-GitRepositoryVersion {
   [CmdletBinding()]
    
    $cmd_opts = @("rev-parse", "HEAD")
    $ProcessResult  = $(Invoke-Process -FilePath git -ArgumentList $cmd_opts -WorkingDir $dest)
    if ( $ProcessResult.ExitCode -ne 0 ){
        $module.FailJson($($ProcessResult.StdErr))
    } else {
        return $ProcessResult.StdOut.Replace("`n", "")
    }
}

function Get-GitRepositoryVersionRemote {
    [CmdletBinding()]
    $cmd_opts = @("ls-remote", "$remote", "$version")
    $ProcessResult  = $(Invoke-Process -FilePath git -ArgumentList $cmd_opts -WorkingDir $dest)
    if ( $ProcessResult.ExitCode -ne 0 ){
        $module.FailJson($($ProcessResult.StdErr))
    } else {
        return $ProcessResult.StdOut.Split()[0]
    }

}

function Get-GitUncommited {
    [CmdletBinding()]

    $cmd_opts = @("status", "--porcelain")
    $ProcessResult  = $(Invoke-Process -FilePath git -ArgumentList $cmd_opts -WorkingDir $dest)
    if ( $ProcessResult.ExitCode -ne 0 ){
        $module.FailJson($($ProcessResult.StdErr))
    } else {
        return $ProcessResult.StdOut.Replace("`n", "")
    }
}

function Reset-GitRepository {
    [CmdletBinding()]

    $cmd_opts = @("reset", "--hard", "HEAD")
    $ProcessResult  = $(Invoke-Process -FilePath git -ArgumentList $cmd_opts -WorkingDir $dest)
    if ( $ProcessResult.ExitCode -ne 0 ){
        $module.FailJson($($ProcessResult.StdErr))
    } else {
        return
    }
}

function Fetch-GitRepository {
    [CmdletBinding()]

    $cmd_opts = @("fetch")
    $ProcessResult  = $(Invoke-Process -FilePath git -ArgumentList $cmd_opts -WorkingDir $dest)
    if ( $ProcessResult.ExitCode -ne 0 ){
        $module.FailJson($($ProcessResult.StdErr))
    } else {
        return
    }  
}


function Switch-GitRepository {
    [CmdletBinding()]

    $cmd_opts = @("checkout", "-b", "$version", "$remote/$version" )
    $ProcessResult  = $(Invoke-Process -FilePath git -ArgumentList $cmd_opts -WorkingDir $dest)
    if ( $ProcessResult.ExitCode -ne 0 ){
        $module.FailJson($($ProcessResult.StdErr))
    } else {
        $module.Result.changed = $true
        $module.Result.after = $(Get-GitRepositoryVersionRemote)
    }  
}

function Get-GitBranches {
    [CmdletBinding()]
    $cmd_opts = @("branch", "--no-color", "-a" )
    $ProcessResult  = $(Invoke-Process -FilePath git -ArgumentList $cmd_opts -WorkingDir $dest)
    if ( $ProcessResult.ExitCode -ne 0 ){
        $module.FailJson($($ProcessResult.StdErr))
    } else {
        return @($ProcessResult.StdOut -split "`r?`n")
    } 
}

# $isGitAvailable = Get-Command -Name "git.exe" -ErrorAction SilentlyContinue
# if (! $isGitAvailable ) {
#     $module.FailJson("git.exe cannot be found on the system. Make sure it's installed and added to the PATH environment variable!")
# }

# $gitRegEx = "^git@[\w\-\.]+:[\w\-/]+\.git$"
# if ($repo -notmatch $gitRegEx) {
#     $module.FailJson("$repo seems to be not a valid ssh git string")
# }


if ( -Not $(Test-Path -Path $dest) ) {
    Clone-GitRepository
} elseif ( $update ) {
    $module.Result.before = Get-GitRepositoryVersion
    if ($(Get-GitUncommited) -ne "") {
        if ($force) {
            if((Reset-GitRepository)){
                $module.Result.changed = $true
            }
        } else {
            $module.Result.msg = "Skipping update, because of uncommited changes"
            $module.ExitJson()
        }

    }
    Fetch-GitRepository
    #Switch-GitRepository
    Write-Host $(Get-GitBranches)

}

$module.ExitJson()
