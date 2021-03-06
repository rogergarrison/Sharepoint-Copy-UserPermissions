param(
    [String]
    $siteURL
  ,
    [String]
    $subSite
  ,
    [String]
    $fromUser
  ,
    [String]
    $toUser
  )

# This script takes in 4 parameters, the site url, the particular sub site and 2 usernames
# it copies the permissions of "$fromUser" on the particular subsite to "$touser"
# It saves a lot of time trying to go through every single page and check if inheritance is broken and give rights
#
# Created by Roger Garrison

[void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SharePoint")

#Region MOSS 2007 Cmdlets 

Function global:Get-SPSite($url)
{
  if($url -ne $null)
  {
    return New-Object Microsoft.SharePoint.SPSite($url)
  }
}
  
Function global:Get-SPWeb($url)
{
  $site= Get-SPSite($url)
  if($site -ne $null)
  {
    $web=$site.OpenWeb();

  }
  return $web
}
  
#EndRegion

Function addRights
{
  param($item, $webSubSite, $user, $webRoleAssignment)
  begin{}
  process
  {
    echo $item.HasUniqueRoleAssignments
    if($item.HasUniqueRoleAssignments) # verify that the item doesn't inherit permissions from parent
    {
      foreach($binding in $webRoleAssignment.RoleDefinitionBindings)
      {
        if($binding.Name -match "Limit") # "Limited Access" isn't an assignable role binding, so skip it
        { 
          echo "$($binding.Name) on $($webSubSite.url) " 
        }
        else
        {
          $assignment = New-Object Microsoft.SharePoint.SPRoleAssignment($user)
          $type = $binding.Type
          if($type -and $type -notmatch "None")
          {
            $assignment.RoleDefinitionBindings.Add($webSubSite.RoleDefinitions.GetByType($type))
            if($assignment.RoleDefinitionBindings)
            {
               $item.RoleAssignments.Add($assignment)
            }
          }
        }
      }
    }
  }
  end{}
}

$member = ((Get-SPSite $siteURL).RootWeb.AllUsers | Where { $_.LoginName -match $toUser}) # find the user in Sharepoint

$member = if($member -is [system.array]){ $member[0]} else { $member} # sometime it matches more than 1 account, like "_username", make sure to take the first one

foreach ($web in (Get-SPSite $siteURL).AllWebs)
{
  if($web.url -match $subSite) # get only the matching sites
  {
    $webRoleAssignments = ($web.RoleAssignments | ? {$_.Member.LoginName -match $fromUser })
    $webRoleAssignments | % {addRights $web $web $member $_}

    $web.Lists | %{
      $list = $_
      $listRoleAssignments = ($_.RoleAssignments | ? {$_.Member.LoginName -match $fromUser })
      $listRoleAssignments | % {addRights $list $web $member $_}
    }
  }
} 

