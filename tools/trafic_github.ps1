<#
.SYNOPSIS
  Archive le trafic GitHub du dépôt Écluse dans des fichiers CSV locaux.

.DESCRIPTION
  GitHub ne conserve les statistiques de trafic que 14 jours. Ce script les
  récupère avec la CLI `gh` (authentifiée sur un compte ayant les droits
  d'écriture sur le dépôt) et les ajoute à des CSV, sans doublon.

  Pourquoi en local plutôt qu'en GitHub Action : les sites de provenance
  peuvent révéler l'intranet ou le domaine d'un établissement qui consulte le
  projet. Ces données ne doivent pas atterrir dans le dépôt public ni dans un
  artefact téléchargeable. Par défaut, elles vont dans `docs/trafic/`, qui est
  gitignoré.

  À lancer au moins une fois tous les 14 jours, idéalement chaque jour via le
  Planificateur de tâches Windows. Compatible Windows PowerShell 5.1 et
  PowerShell 7.

.PARAMETER Depot
  Dépôt au format compte/nom.

.PARAMETER Dossier
  Dossier de sortie. Doit rester gitignoré.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\trafic_github.ps1
#>
[CmdletBinding()]
param(
  [string]$Depot = 'ecluse-dev/ecluse',
  [string]$Dossier = (Join-Path $PSScriptRoot '..\docs\trafic')
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
  throw "La CLI GitHub 'gh' est introuvable. Installe-la puis lance 'gh auth login'."
}

function Invoke-GhJson([string]$Chemin) {
  $url = if ($Chemin) { "repos/$Depot/$Chemin" } else { "repos/$Depot" }
  $brut = & gh api $url 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "Échec de 'gh api $url' : $brut"
  }
  return ($brut | Out-String | ConvertFrom-Json)
}

# Ajoute des lignes à un CSV en ignorant celles dont la clé existe déjà.
# Une journée récupérée pendant qu'elle est en cours est complétée au passage
# suivant : la dernière valeur connue remplace l'ancienne pour cette clé.
function Merge-Csv([string]$Fichier, [object[]]$Lignes, [string[]]$Cle) {
  $existantes = @()
  if (Test-Path $Fichier) { $existantes = @(Import-Csv $Fichier) }
  $index = @{}
  foreach ($l in $existantes) { $index[(($Cle | ForEach-Object { $l.$_ }) -join '|')] = $l }
  foreach ($l in $Lignes) { $index[(($Cle | ForEach-Object { $l.$_ }) -join '|')] = $l }
  $tout = @($index.Values | Sort-Object -Property $Cle)
  if ($tout.Count -gt 0) {
    $tout | Export-Csv -Path $Fichier -NoTypeInformation -Encoding UTF8
  }
  return $tout.Count
}

New-Item -ItemType Directory -Force -Path $Dossier | Out-Null
$Dossier = (Resolve-Path $Dossier).Path
$aujourdhui = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd')

$vues = Invoke-GhJson 'traffic/views'
$clones = Invoke-GhJson 'traffic/clones'
$sources = Invoke-GhJson 'traffic/popular/referrers'
$pages = Invoke-GhJson 'traffic/popular/paths'
$infoDepot = Invoke-GhJson ''

# Les horodatages GitHub sont en UTC ; ConvertFrom-Json les convertit parfois
# en DateTime local, d'où la normalisation explicite en date UTC.
function Get-JourUtc($t) {
  if ($t -is [datetime]) { return $t.ToUniversalTime().ToString('yyyy-MM-dd') }
  return ([string]$t).Substring(0, 10)
}

$quotidien = @{}
foreach ($v in $vues.views) {
  $j = Get-JourUtc $v.timestamp
  $quotidien[$j] = [ordered]@{ jour = $j; vues = $v.count; visiteurs_uniques = $v.uniques; clones = 0; cloneurs_uniques = 0 }
}
foreach ($c in $clones.clones) {
  $j = Get-JourUtc $c.timestamp
  if (-not $quotidien.ContainsKey($j)) {
    $quotidien[$j] = [ordered]@{ jour = $j; vues = 0; visiteurs_uniques = 0; clones = 0; cloneurs_uniques = 0 }
  }
  $quotidien[$j].clones = $c.count
  $quotidien[$j].cloneurs_uniques = $c.uniques
}
$lignesJour = @($quotidien.Values | ForEach-Object { [pscustomobject]$_ })
$nJours = Merge-Csv (Join-Path $Dossier 'quotidien.csv') $lignesJour @('jour')

# Les provenances et pages populaires sont des cumuls sur 14 jours glissants :
# on les horodate par date de relevé.
$lignesSources = @($sources | ForEach-Object {
  [pscustomobject]@{ releve = $aujourdhui; source = $_.referrer; vues = $_.count; uniques = $_.uniques }
})
$nSources = Merge-Csv (Join-Path $Dossier 'provenances_14j.csv') $lignesSources @('releve', 'source')

$lignesPages = @($pages | ForEach-Object {
  [pscustomobject]@{ releve = $aujourdhui; page = $_.path; vues = $_.count; uniques = $_.uniques }
})
$nPages = Merge-Csv (Join-Path $Dossier 'pages_14j.csv') $lignesPages @('releve', 'page')

$ligneDepot = [pscustomobject]@{
  releve = $aujourdhui; stars = $infoDepot.stargazers_count; forks = $infoDepot.forks_count; watchers = $infoDepot.subscribers_count
}
$nDepot = Merge-Csv (Join-Path $Dossier 'compteurs.csv') @($ligneDepot) @('releve')

Write-Host "Trafic archivé dans $Dossier : $nJours jours, $nSources relevés de provenance, $nPages relevés de pages, $nDepot relevés de compteurs."
Write-Host "Rappel : les clones incluent ceux des GitHub Actions et des agents ; les visiteurs uniques sont l'indicateur humain."
