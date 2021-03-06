$script:resourceModulePath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$script:modulesFolderPath = Join-Path -Path $script:resourceModulePath -ChildPath 'Modules'

$script:localizationModulePath = Join-Path -Path $script:modulesFolderPath -ChildPath 'xActiveDirectory.Common'
Import-Module -Name (Join-Path -Path $script:localizationModulePath -ChildPath 'xActiveDirectory.Common.psm1')

$script:localizedData = Get-LocalizedData -ResourceName 'MSFT_xADDomainTrust'

function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [String]$SourceDomainName,

        [Parameter(Mandatory = $true)]
        [String]$TargetDomainName,

        [Parameter(Mandatory = $true)]
        [PSCredential]$TargetDomainAdministratorCredential,

        [Parameter(Mandatory = $true)]
        [ValidateSet("External","Forest")]
        [String]$TrustType,

        [Parameter(Mandatory = $true)]
        [ValidateSet("Bidirectional","Inbound","Outbound")]
        [String]$TrustDirection,

        [Parameter()]
        [ValidateSet("Present","Absent")]
        [String]$Ensure = 'Present'
    )

#region Input Validation

    # Load the .NET assembly
    try
    {
        Add-type -AssemblyName System.DirectoryServices
    }
    # If not found, means ADDS role is not installed
    catch
    {
        $missingRoleMessage = $($script:localizedData.MissingRoleMessage) -f 'AD-Domain-Services'
        New-TerminatingError -errorId ActiveDirectoryRoleMissing -errorMessage $missingRoleMessage -errorCategory NotInstalled
    }

#endregion

    try
    {
        switch ($TrustType)
        {
            'External' {$DomainOrForest = 'Domain'}
            'Forest' {$DomainOrForest = 'Forest'}
        }
        # Create the target object
        $trgDirectoryContext = New-Object System.DirectoryServices.ActiveDirectory.DirectoryContext($DomainOrForest,$TargetDomainName, $TargetDomainAdministratorCredential.UserName, $TargetDomainAdministratorCredential.GetNetworkCredential().Password)
        $trgDomain = ([type]"System.DirectoryServices.ActiveDirectory.$DomainOrForest")::"Get$DomainOrForest"($trgDirectoryContext)
        # Create the source object
        $srcDirectoryContext = New-Object System.DirectoryServices.ActiveDirectory.DirectoryContext($DomainOrForest,$SourceDomainName)
        $srcDomain = ([type]"System.DirectoryServices.ActiveDirectory.$DomainOrForest")::"Get$DomainOrForest"($srcDirectoryContext)

        # Find trust between source & destination.
        Write-Verbose -Message ($script:localizedData.CheckingTrustMessage -f $SourceDomainName, $TargetDomainName)
        $trust = $srcDomain.GetTrustRelationship($trgDomain)

        Write-Verbose -Message ($script:localizedData.TrustPresentMessage -f  $SourceDomainName, $TargetDomainName)
        $Ensure = 'Present'
    }
    catch
    {
        Write-Verbose -Message ($script:localizedData.TrustAbsentMessage -f  $SourceDomainName, $TargetDomainName)
        $Ensure = 'Absent'
    }

    # return a credential object without password
    $CIMCredential = New-CimInstance -ClassName MSFT_Credential -ClientOnly `
                                     -Namespace root/microsoft/windows/desiredstateconfiguration `
                                     -Property @{
                                                  UserName = [string]$TargetDomainAdministratorCredential.UserName
                                                  Password = [string]$null
                                                }

    @{
        SourceDomainName = $SourceDomainName
        TargetDomainName = $TargetDomainName
        Ensure           = $Ensure
        TrustType        = $trust.TrustType
        TrustDirection   = $trust.TrustDirection
        TargetDomainAdministratorCredential = $CIMCredential
    }

}

function Set-TargetResource
{
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSDSCUseVerboseMessageInDSCResource", "",
        Justification = 'Verbose messaging in helper function')]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [String]$SourceDomainName,

        [Parameter(Mandatory = $true)]
        [String]$TargetDomainName,

        [Parameter(Mandatory = $true)]
        [PSCredential]$TargetDomainAdministratorCredential,

        [Parameter(Mandatory = $true)]
        [ValidateSet("External","Forest")]
        [String]$TrustType,

        [Parameter(Mandatory = $true)]
        [ValidateSet("Bidirectional","Inbound","Outbound")]
        [String]$TrustDirection,

        [Parameter()]
        [ValidateSet("Present","Absent")]
        [String]$Ensure = 'Present'
    )

    if($PSBoundParameters.ContainsKey('Debug')){$null = $PSBoundParameters.Remove('Debug')}
    Confirm-ResourceProperties @PSBoundParameters -Apply
}

function Test-TargetResource
{
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSDSCUseVerboseMessageInDSCResource", "",
        Justification = 'Verbose messaging in helper function')]
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [String]$SourceDomainName,

        [Parameter(Mandatory = $true)]
        [String]$TargetDomainName,

        [Parameter(Mandatory = $true)]
        [PSCredential]$TargetDomainAdministratorCredential,

        [Parameter(Mandatory = $true)]
        [ValidateSet("External","Forest")]
        [String]$TrustType,

        [Parameter(Mandatory = $true)]
        [ValidateSet("Bidirectional","Inbound","Outbound")]
        [String]$TrustDirection,

        [Parameter()]
        [ValidateSet("Present","Absent")]
        [String]$Ensure = 'Present'
    )

#region Input Validation

    # Load the .NET assembly
    try
    {
        Add-type -AssemblyName System.DirectoryServices
    }
    # If not found, means ADDS role is not installed
    catch
    {
        $missingRoleMessage = $($script:localizedData.MissingRoleMessage) -f 'AD-Domain-Services'
        New-TerminatingError -errorId ActiveDirectoryRoleMissing -errorMessage $missingRoleMessage -errorCategory NotInstalled
    }

#endregion

    if($PSBoundParameters.ContainsKey('Debug')){$null = $PSBoundParameters.Remove('Debug')}
    Confirm-ResourceProperties @PSBoundParameters
}

#region Helper Functions
function Confirm-ResourceProperties
{
    [Cmdletbinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [String]$SourceDomainName,

        [Parameter(Mandatory = $true)]
        [String]$TargetDomainName,

        [Parameter(Mandatory = $true)]
        [PSCredential]$TargetDomainAdministratorCredential,

        [Parameter(Mandatory = $true)]
        [ValidateSet("External","Forest")]
        [String]$TrustType,

        [Parameter(Mandatory = $true)]
        [ValidateSet("Bidirectional","Inbound","Outbound")]
        [String]$TrustDirection,

        [Parameter()]
        [ValidateSet("Present","Absent")]
        [String]$Ensure = 'Present',

        [Parameter()]
        [Switch]$Apply
    )

    try
    {
        $checkingTrustMessage = $($script:localizedData.CheckingTrustMessage) -f $SourceDomainName,$TargetDomainName
        Write-Verbose -Message $checkingTrustMessage

        switch ($TrustType)
        {
            'External' {$DomainOrForest = 'Domain'}
            'Forest' {$DomainOrForest = 'Forest'}
        }
        # Create the target object
        $trgDirectoryContext = New-Object System.DirectoryServices.ActiveDirectory.DirectoryContext($DomainOrForest,$TargetDomainName, $TargetDomainAdministratorCredential.UserName, $TargetDomainAdministratorCredential.GetNetworkCredential().Password)
        $trgDomain = ([type]"System.DirectoryServices.ActiveDirectory.$DomainOrForest")::"Get$DomainOrForest"($trgDirectoryContext)
        # Create the source object
        $srcDirectoryContext = New-Object System.DirectoryServices.ActiveDirectory.DirectoryContext($DomainOrForest,$SourceDomainName)
        $srcDomain = ([type]"System.DirectoryServices.ActiveDirectory.$DomainOrForest")::"Get$DomainOrForest"($srcDirectoryContext)

        # Find trust
        try
        {
            # Find trust betwen source & destination.
            $trust = $srcDomain.GetTrustRelationship($TargetDomainName)

            $TestTrustMessage = $($script:localizedData.TestTrustMessage) -f 'present',$Ensure
            Write-Verbose -Message $TestTrustMessage

            if($Ensure -eq 'Present')
            {
                #region Test for trust direction

                $CheckPropertyMessage = $($script:localizedData.CheckPropertyMessage) -f 'trust direction'
                Write-Verbose -Message $CheckPropertyMessage

                # Set the trust direction if not correct
                if($trust.TrustDirection -ne $TrustDirection)
                {
                    $notDesiredPropertyMessage = $($script:localizedData.NotDesiredPropertyMessage) -f 'Trust direction',$TrustDirection,$trust.TrustDirection
                    Write-Verbose -Message $notDesiredPropertyMessage

                    if($Apply)
                    {
                        $srcDomain.UpdateTrustRelationship($trgDomain,$TrustDirection)

                        $setPropertyMessage = $($script:localizedData.SetPropertyMessage) -f 'Trust direction'
                        Write-Verbose -Message $setPropertyMessage
                    }
                    else
                    {
                        return $false
                    }
                } # end trust direction is not correct

                # Trust direction is correct
                else
                {
                    $desiredPropertyMessage = $($script:localizedData.DesiredPropertyMessage) -f 'Trust direction'
                    Write-Verbose -Message $desiredPropertyMessage
                }
                #endregion trust direction

                #region Test for trust type

                $CheckPropertyMessage = $($script:localizedData.CheckPropertyMessage) -f 'trust type'
                Write-Verbose -Message $CheckPropertyMessage

                # Set the trust type if not correct
                if($trust.TrustType-ne $TrustType)
                {
                    $notDesiredPropertyMessage = $($script:localizedData.NotDesiredPropertyMessage) -f 'Trust type',$TrustType,$trust.TrustType
                    Write-Verbose -Message $notDesiredPropertyMessage

                    if($Apply)
                    {
                        # Only way to fix the trust direction is to delete it and create again
                        # TODO: Add a property to ask user permission to delete an existing trust
                        $srcDomain.DeleteTrustRelationship($trgDomain)
                        $srcDomain.CreateTrustRelationship($trgDomain,$TrustDirection)

                        $setPropertyMessage = $($script:localizedData.SetPropertyMessage) -f 'Trust type'
                        Write-Verbose -Message $setPropertyMessage
                    }
                    else
                    {
                        return $false
                    }
                } # end trust type is not correct

                # Trust type is correct
                else
                {
                    $desiredPropertyMessage = $($script:localizedData.DesiredPropertyMessage) -f 'Trust type'
                    Write-Verbose -Message $desiredPropertyMessage
                }

                #endregion Test for trust type

                # If both trust type and trust direction are correct, return true
                if(-not $Apply)
                {
                    return $true
                }
            } # end Ensure -eq present

            # If the trust should be absent, remove the trust
            else
            {
                if($Apply)
                {
                    $removingTrustMessage = $($script:localizedData.RemovingTrustMessage) -f $SourceDomainName,$TargetDomainName
                    Write-Verbose -Message $removingTrustMessage

                    $srcDomain.DeleteTrustRelationship($trgDomain)

                    $deleteTrustMessage = $script:localizedData.DeleteTrustMessage
                    Write-Verbose -Message $deleteTrustMessage
                }
                else
                {
                    return $false
                }
            } # end Ensure -eq absent
        } # end find trust

        # Trust does not exist between source and destination
        catch [System.DirectoryServices.ActiveDirectory.ActiveDirectoryObjectNotFoundException]
        {
            $TestTrustMessage = $($script:localizedData.TestTrustMessage) -f 'absent',$Ensure
            Write-Verbose -Message $TestTrustMessage

            if($Ensure -eq 'Present')
            {
                if($Apply)
                {
                    $addingTrustMessage = $($script:localizedData.AddingTrustMessage) -f $SourceDomainName,$TargetDomainName
                    Write-Verbose -Message $addingTrustMessage

                    $srcDomain.CreateTrustRelationship($trgDomain,$TrustDirection)

                    $setTrustMessage = $script:localizedData.SetTrustMessage
                    Write-Verbose -Message $setTrustMessage
                }
                else
                {
                    return $false
                }
            } # end Ensure -eq Present
            else
            {
                if(-not $Apply)
                {
                    return $true
                }
            }
        } # end no trust
    }# end getting directory object
    catch [System.DirectoryServices.ActiveDirectory.ActiveDirectoryObjectNotFoundException]
    {
        throw
    }
}

# Internal function to throw terminating error with specified errroCategory, errorId and errorMessage
function New-TerminatingError
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [String]$errorId,

        [Parameter(Mandatory = $true)]
        [String]$errorMessage,

        [Parameter(Mandatory = $true)]
        [System.Management.Automation.ErrorCategory]$errorCategory
    )

    $exception = New-Object System.InvalidOperationException $errorMessage
    $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception, $errorId, $errorCategory, $null
    throw $errorRecord
}

#endregion

Export-ModuleMember -Function *-TargetResource
