<#
================================================================================
 SP GEMS — static site generator
--------------------------------------------------------------------------------
 Why this exists
   The production stack recommended in PRD §35 is Next.js + Payload CMS +
   Postgres. This repository is the DESIGN AND CONTENT DEMO that precedes it:
   its job is to settle the design system, information architecture, page
   templates and data model before that build starts. It ships as plain static
   HTML so it deploys to Vercel with no build step, needs no database, and can
   be opened straight off disk.

   This script assembles it. Sources in src/ carry a small metadata block and
   page body only; shared chrome lives in tools/partials/; the gemstone
   catalogue and detail pages are generated from data/gemstones.json, whose
   field names mirror PRD §12.3 exactly so the model transfers unchanged.

 Usage
   powershell -ExecutionPolicy Bypass -File tools/build.ps1

 Output
   Written to the repository root. Generated files are committed so that
   Vercel serves them directly.
================================================================================
#>

$ErrorActionPreference = 'Stop'

$Root     = Split-Path -Parent $PSScriptRoot
$SrcDir   = Join-Path $Root 'src'
$PartDir  = Join-Path $PSScriptRoot 'partials'
$TmplDir  = Join-Path $PSScriptRoot 'templates'
$DataDir  = Join-Path $Root 'data'

Write-Host "SP Gems — building from $SrcDir" -ForegroundColor Cyan

# ---------------------------------------------------------------- partials ----
$Partials = @{}
foreach ($f in Get-ChildItem $PartDir -Filter *.html) {
  $Partials[$f.BaseName] = (Get-Content $f.FullName -Raw -Encoding UTF8)
}

# -------------------------------------------------------------------- data ----
$GemData = (Get-Content (Join-Path $DataDir 'gemstones.json') -Raw -Encoding UTF8 | ConvertFrom-Json)
$Gems    = $GemData.gemstones
$JwlData = (Get-Content (Join-Path $DataDir 'jewellery.json') -Raw -Encoding UTF8 | ConvertFrom-Json)
$Jwl     = $JwlData.jewellery
$ArtData = (Get-Content (Join-Path $DataDir 'articles.json') -Raw -Encoding UTF8 | ConvertFrom-Json)
$Arts    = $ArtData.articles

$Bands = @(
  'Under US$5,000', 'US$5,000 - 10,000', 'US$10,000 - 25,000',
  'US$25,000 - 50,000', 'US$50,000 - 100,000', 'US$100,000+', 'Price on Request'
)

# ----------------------------------------------------------------- helpers ----
function HtmlEnc([string]$s) {
  if ($null -eq $s) { return '' }
  return $s.Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;').Replace('"','&quot;')
}

# Normalise the en-dash the JSON uses for band ranges so it matches $Bands
function BandKey([string]$b) {
  if ($null -eq $b) { return '' }
  return $b.Replace([char]0x2013, '-')
}

function BandRank([string]$b) {
  $k = BandKey $b
  for ($i = 0; $i -lt $Bands.Count; $i++) { if ($Bands[$i] -eq $k) { return $i } }
  return 99
}

# Colour facet, derived from colorPrimary for the swatch filter (§19.1)
function ColourGroup([string]$c) {
  $l = $c.ToLower()
  if ($l -match 'pink')                     { return 'pink' }
  if ($l -match 'red')                      { return 'red' }
  if ($l -match 'blue')                     { return 'blue' }
  if ($l -match 'green')                    { return 'green' }
  if ($l -match 'grey|gray')                { return 'grey' }
  if ($l -match 'colourless|colorless')     { return 'colourless' }
  return 'other'
}

# Clarity facet — descriptive tiers, never diamond clarity grades (§12.3)
function ClarityTier([string]$c) {
  $l = $c.ToLower()
  if ($l -match 'eye-clean')                { return 'eye-clean' }
  if ($l -match 'minor')                    { return 'minor' }
  if ($l -match 'translucent|semi-trans')   { return 'translucent' }
  return 'other'
}

function TypeSlug($g) {
  switch ($g.gemType) {
    'Ruby'     { return 'ruby' }
    'Sapphire' { return 'sapphire' }
    'Spinel'   { return 'spinel' }
    default    { return 'other' }
  }
}
function TypeLabel($g) {
  switch ($g.gemType) {
    'Ruby'     { return 'Ruby' }
    'Sapphire' { return 'Sapphire' }
    'Spinel'   { return 'Spinel' }
    default    { return 'Other Gemstones' }
  }
}

# Sort key standing in for createdAt in the demo: the numeric part of the
# stone ID. Production sorts on the real publishedAt timestamp.
function AddedKey($g) {
  $m = [regex]::Match($g.stoneId, '(\d+)$')
  if ($m.Success) { return [int]$m.Groups[1].Value }
  return 0
}

function CaratStr($c) { return ([decimal]$c).ToString('0.00') }
function MmStr($v)     { return ([decimal]$v).ToString('0.00') }

# Bands are typeset with an en-dash regardless of how the source JSON spells
# the range, so gemstone and jewellery prices are consistent.
function BandDisplay([string]$b) {
  return (HtmlEnc $b).Replace(' - ', ' &ndash; ').Replace([string][char]0x2013, '&ndash;')
}

# FR-CAT-003 item 6 / §12.5 — price band, exact price, or Price on Request
function PriceDisplay($g) {
  if ($g.availability -eq 'sold') { return 'Sold' }
  switch ($g.pricingModel) {
    'public-price'     { return 'US$' + ([int]$g.priceUSD).ToString('N0') }
    'price-band'       { return (BandDisplay $g.priceBand) }
    default            { return 'Price on Request' }
  }
}

function AvailLabel($g) {
  switch ($g.availability) {
    'available' { return 'Available' }
    'reserved'  { return 'Reserved' }
    'on-memo'   { return 'On memo' }
    'sold'      { return 'Sold' }
    default     { return 'Not for sale' }
  }
}

function TreatLabel($g) {
  switch ($g.treatmentStatus) {
    'unheated'             { return 'Unheated' }
    'heated'               { return 'Heated' }
    'heated-with-residue'  { return 'Heated, with residue' }
    'other-treatment'      { return 'Treated' }
    default                { return 'Treatment undetermined' }
  }
}

# ------------------------------------------------------------- placeholders ---
# The specimen plate. PRD §28.7 forbids stock and AI-generated gemstone
# imagery outright, so this demo ships none: every image slot renders the
# gemmological neutral grey ground of FR-CAT-040 carrying its own shot brief.
function Plate {
  param([string]$Id, [string]$Shot, [string]$Spec, [string]$Variant = '')
  $cls = 'plate'
  if ($Variant) { $cls += ' plate--' + $Variant }
  $out  = '<div class="' + $cls + '">'
  $out += '<span class="plate__wm">SP GEMS</span>'
  if ($Id)   { $out += '<span class="plate__id">' + (HtmlEnc $Id) + '</span>' }
  if ($Shot) { $out += '<span class="plate__shot">' + (HtmlEnc $Shot) + '</span>' }
  if ($Spec) { $out += '<span class="plate__spec">' + (HtmlEnc $Spec) + '</span>' }
  $out += '<span class="plate__pending">Photography pending</span>'
  $out += '</div>'
  return $out
}

# --------------------------------------------------------------- gem cards ----
# FR-CAT-003 — card contents, in the specified order. FR-CAT-004 — no clarity
# grades, star ratings, sale flags, countdowns or stock counts.
function GemCard {
  param($g, [string]$Base)

  $slug   = $g.slug
  $type   = TypeLabel $g
  $origin = $g.originRegion
  if ($origin -eq 'Namyarseik (Kachin)') { $originShort = 'Namyarseik' } else { $originShort = $origin }

  $badges = ''
  $badges += '<span class="badge' + $(if ($g.treatmentStatus -eq 'unheated') { ' badge--key' } else { '' }) + '">' + (TreatLabel $g) + '</span>'
  if ($g.isCertified) { $badges += '<span class="badge">' + (HtmlEnc $g.certLab) + '</span>' }
  if ($g.isExceptional) { $badges += '<span class="badge badge--exceptional">Exceptional</span>' }
  if ($g.isMatchedPair) { $badges += '<span class="badge">Pair</span>' }
  if ($g.availability -eq 'sold') { $badges += '<span class="badge badge--sold">Sold</span>' }
  if ($g.availability -eq 'reserved') { $badges += '<span class="badge">Reserved</span>' }

  # FR-CAT-005 — a secondary image cross-fades in on pointer devices
  $imgA = Plate $g.stoneId $g.images[0].shot ''
  $imgB = ''
  if ($g.images.Count -gt 1) {
    $imgB = '<div class="card__img--secondary">' + (Plate $g.stoneId $g.images[1].shot '') + '</div>'
  }

  $h  = '<a class="card" data-stone'
  $h += ' data-type="' + (TypeSlug $g) + '"'
  $h += ' data-treatment="' + $g.treatmentStatus + '"'
  $h += ' data-band="' + (HtmlEnc (BandKey $g.priceBand)) + '"'
  $h += ' data-bandrank="' + (BandRank $g.priceBand) + '"'
  $h += ' data-availability="' + $g.availability + '"'
  $h += ' data-origin="' + (HtmlEnc $origin) + '"'
  $h += ' data-colour="' + (ColourGroup $g.colorPrimary) + '"'
  $h += ' data-shape="' + $g.shape.ToLower() + '"'
  $h += ' data-clarity="' + (ClarityTier $g.clarityDescription) + '"'
  $h += ' data-cert="' + (HtmlEnc $g.certLab) + '"'
  $h += ' data-exceptional="' + $(if ($g.isExceptional) { '1' } else { '0' }) + '"'
  $h += ' data-pairs="' + $(if ($g.isMatchedPair) { '1' } else { '0' }) + '"'
  $h += ' data-carat="' + $g.caratWeight + '"'
  $h += ' data-rank="' + $g.featureRank + '"'
  $h += ' data-added="' + (AddedKey $g) + '"'
  $h += ' href="' + $Base + 'gemstones/' + $slug + '.html">'
  $h += '<div class="card__media"><div class="card__img--primary">' + $imgA + '</div>' + $imgB + '</div>'
  $h += '<div class="card__body">'
  # 2. type and origin, in small caps
  $h += '<p class="eyebrow">' + (HtmlEnc $originShort) + ' ' + (HtmlEnc $type) + '</p>'
  $h += '<h3 class="mt-1" style="margin:0"><span class="card__title">' + (HtmlEnc $g.title) + '</span></h3>'
  $h += '<div class="card__meta">'
  # 3. carat weight to two decimal places
  $h += '<span class="carat small">' + (CaratStr $g.caratWeight) + ' ct</span>'
  $h += '<span class="card__price">' + (PriceDisplay $g) + '</span>'
  $h += '</div>'
  # 4./5. treatment status and certification markers
  $h += '<div class="card__badges">' + $badges + '</div>'
  $h += '</div></a>'
  return $h
}

function GemCards {
  param($list, [string]$Base)
  $sb = New-Object System.Text.StringBuilder
  foreach ($g in $list) { [void]$sb.Append((GemCard $g $Base)) }
  return $sb.ToString()
}

# ---------------------------------------------------------- jewellery cards ---
function JwlCard {
  param($p, [string]$Base)
  $badges = ''
  if ($p.isOneOfAKind) { $badges += '<span class="badge badge--key">One of a kind</span>' }
  if ($p.centreStone)  { $badges += '<span class="badge">Catalogued centre stone</span>' }
  if ($p.availability -eq 'sold') { $badges += '<span class="badge badge--sold">Sold</span>' }

  $price = 'Price on Request'
  if ($p.pricingModel -eq 'public-price') { $price = 'US$' + ([int]$p.priceUSD).ToString('N0') }
  elseif ($p.pricingModel -eq 'price-band') { $price = BandDisplay $p.priceBand }

  $imgA = Plate $p.pieceId $p.images[0].shot ''
  $imgB = ''
  if ($p.images.Count -gt 1) {
    $imgB = '<div class="card__img--secondary">' + (Plate $p.pieceId $p.images[1].shot '') + '</div>'
  }

  $h  = '<a class="card" data-piece data-type="' + (HtmlEnc $p.jewelleryType) + '"'
  $h += ' data-metal="' + (HtmlEnc $p.metal) + '"'
  $h += ' href="' + $Base + 'jewellery/' + $p.slug + '.html">'
  $h += '<div class="card__media"><div class="card__img--primary">' + $imgA + '</div>' + $imgB + '</div>'
  $h += '<div class="card__body">'
  $h += '<p class="eyebrow">' + (HtmlEnc $p.jewelleryType) + $(if ($p.collection) { ' &middot; ' + (HtmlEnc $p.collection) } else { '' }) + '</p>'
  $h += '<h3 class="mt-1" style="margin:0"><span class="card__title">' + (HtmlEnc $p.title) + '</span></h3>'
  $h += '<div class="card__meta"><span class="small">' + (HtmlEnc $p.metal) + '</span>'
  $h += '<span class="card__price">' + $price + '</span></div>'
  $h += '<div class="card__badges">' + $badges + '</div>'
  $h += '</div></a>'
  return $h
}

function JwlCards { param($list, [string]$Base)
  $sb = New-Object System.Text.StringBuilder
  foreach ($p in $list) { [void]$sb.Append((JwlCard $p $Base)) }
  return $sb.ToString()
}

# ------------------------------------------------------------ article cards ---
function ArtCard {
  param($a, [string]$Base)
  $h  = '<a class="card" data-article data-cat="' + $a.category + '" href="' + $Base + 'journal/' + $a.slug + '.html">'
  $h += '<div class="card__media" style="aspect-ratio:4/3">' + (Plate '' $a.imageShot '' 'dark') + '</div>'
  $h += '<div class="card__body">'
  $h += '<p class="eyebrow">' + $(switch ($a.category) { 'learn' { 'Learn' } 'stories' { 'Story' } default { 'News' } }) + '</p>'
  $h += '<h3 class="mt-1" style="margin:0"><span class="card__title">' + (HtmlEnc $a.title) + '</span></h3>'
  $h += '<p class="small mt-2" style="color:var(--ink-secondary)">' + (HtmlEnc $a.standfirst) + '</p>'
  $h += '<p class="caption mt-2">' + (HtmlEnc $a.dateLabel) + ' &middot; ' + $a.readMinutes + ' min read</p>'
  $h += '</div></a>'
  return $h
}
function ArtCards { param($list, [string]$Base)
  $sb = New-Object System.Text.StringBuilder
  foreach ($a in $list) { [void]$sb.Append((ArtCard $a $Base)) }
  return $sb.ToString()
}

# The remainder of the twelve-article launch set (§17.2), shown as the
# editorial plan rather than as links to pages that do not exist yet.
function PlannedRows { param($list)
  $sb = New-Object System.Text.StringBuilder
  foreach ($a in $list) {
    [void]$sb.Append('<tr><th scope="row" style="width:auto;text-transform:none;letter-spacing:0;font-size:15px;color:var(--ink)">' +
      (HtmlEnc $a.title) + '<span class="caption" style="display:block;margin-top:4px">' +
      (HtmlEnc $a.standfirst) + '</span></th>' +
      '<td style="width:90px;text-align:right"><span class="badge">' + $a.priority + '</span></td>' +
      '<td style="width:110px;text-align:right" class="caption">~' + $a.readMinutes + ' min</td></tr>')
  }
  return $sb.ToString()
}

# ------------------------------------------------------------ search index ----
# §19.3 — global search covers gemstones (title, stone ID, type, origin, colour,
# certificate number), jewellery, collections and articles, grouped in the
# results. FR-SRCH-021: an exact stone ID or certificate number resolves
# straight to that record — sales staff use this on calls constantly.
# In production this is PostgreSQL full-text search; the index below is the
# static equivalent for a catalogue of this size.
function SearchIndex {
  param([string]$Base)
  $rows = @()
  foreach ($g in $Gems) {
    $rows += [pscustomobject]@{
      g = 'gemstone'
      t = $g.title
      s = $g.stoneId
      u = $Base + 'gemstones/' + $g.slug + '.html'
      m = (CaratStr $g.caratWeight) + ' ct · ' + $g.shape + ' · ' + $g.originRegion
      k = (@($g.stoneId, $g.title, $g.gemType, $g.varietyName, $g.originRegion,
             $g.colorPrimary, $g.colorTradeTerm, $g.shape, $g.treatmentStatus,
             $g.certLab, $g.certNumber, $g.clarityDescription) -join ' ').ToLower()
    }
  }
  foreach ($p in $Jwl) {
    $rows += [pscustomobject]@{
      g = 'jewellery'
      t = $p.title
      s = $p.pieceId
      u = $Base + 'jewellery/' + $p.slug + '.html'
      m = $p.jewelleryType + ' · ' + $p.metal
      k = (@($p.pieceId, $p.title, $p.jewelleryType, $p.metal, $p.collection, $p.designer) -join ' ').ToLower()
    }
  }
  foreach ($a in ($Arts | Where-Object { $_.live })) {
    $rows += [pscustomobject]@{
      g = 'article'
      t = $a.title
      s = ''
      u = $Base + 'journal/' + $a.slug + '.html'
      m = $a.standfirst
      k = (@($a.title, $a.standfirst, $a.category) -join ' ').ToLower()
    }
  }
  # Static pages worth finding
  $pages = @(
    @{ t = 'How buying works';                    u = 'about/how-buying-works.html';        m = 'The nine steps from enquiry to delivery' },
    @{ t = 'International purchasing & compliance'; u = 'about/international.html';         m = 'The sanctions position and what we document' },
    @{ t = 'Responsible sourcing';                u = 'mogok/responsible-sourcing.html';    m = 'What we document and what we decline to claim' },
    @{ t = 'The mines';                           u = 'mogok/the-mines.html';               m = 'Mogok geology and how material reaches us' },
    @{ t = 'Cutting & craftsmanship';             u = 'mogok/craftsmanship.html';           m = 'Sorting, orienting, cutting, setting' },
    @{ t = 'The Value';                           u = 'jewellery/collections/the-value.html'; m = 'Our designer-led jewellery collection' },
    @{ t = 'Bespoke commissions';                 u = 'jewellery/bespoke.html';             m = 'Commission a piece around a stone' },
    @{ t = 'Trade & wholesale';                   u = 'trade.html';                         m = 'For designers, brands, dealers and bench jewellers' },
    @{ t = 'Arrange a consultation';              u = 'consultation.html';                  m = 'Video, phone, or in person in Yangon' }
  )
  foreach ($pg in $pages) {
    $rows += [pscustomobject]@{
      g = 'page'; t = $pg.t; s = ''; u = $Base + $pg.u; m = $pg.m
      k = ($pg.t + ' ' + $pg.m).ToLower()
    }
  }
  return ($rows | ConvertTo-Json -Compress -Depth 4)
}

# ------------------------------------------------------------- page assembly --
function Expand-Page {
  param([string]$Body, [hashtable]$Meta, [string]$Base)

  $extraCss = ''
  if ($Meta.css) {
    foreach ($c in ($Meta.css -split ',')) {
      $c = $c.Trim()
      if ($c) { $extraCss += '<link rel="stylesheet" href="' + $Base + 'assets/css/' + $c + '">' + "`n" }
    }
  }
  $extraJs = ''
  if ($Meta.js) {
    foreach ($j in ($Meta.js -split ',')) {
      $j = $j.Trim()
      if ($j -and $j -ne 'catalogue-none') {
        $extraJs += '<script src="' + $Base + 'assets/js/' + $j + '" defer></script>' + "`n"
      }
    }
  }

  $head = $Partials['head']
  $head = $head.Replace('{{TITLE}}', (HtmlEnc $Meta.title))
  $head = $head.Replace('{{DESC}}',  (HtmlEnc $Meta.desc))
  $head = $head.Replace('{{EXTRACSS}}', $extraCss)

  $header = $Partials['header']
  foreach ($k in @('gemstones','jewellery','mogok','journal','about','contact')) {
    $token = '{{ON_' + $k.ToUpper() + '}}'
    if ($Meta.nav -eq $k) { $header = $header.Replace($token, 'aria-current="page"') }
    else                  { $header = $header.Replace($token, '') }
  }

  $abar = ''
  if ($Meta.abar) { $abar = $Meta.abar }

  $viewer = ''
  if ($Meta.viewer -eq 'yes') { $viewer = $Partials['viewer'] }

  $doc  = '<!DOCTYPE html>' + "`n" + '<html lang="en">' + "`n" + '<head>' + "`n"
  $doc += $head + "`n" + '</head>' + "`n" + '<body>' + "`n"
  $doc += $header + "`n"
  $doc += '<main id="main">' + "`n" + $Body + "`n" + '</main>' + "`n"
  $doc += $Partials['footer'] + "`n"
  $doc += $abar + "`n"
  $doc += $Partials['modal'] + "`n"
  $doc += $viewer + "`n"
  $doc += '<script src="' + $Base + 'assets/js/site.js" defer></script>' + "`n"
  $doc += $extraJs
  $doc += '</body>' + "`n" + '</html>' + "`n"

  $doc = $doc.Replace('{{BASE}}', $Base)
  return $doc
}

function Read-Meta {
  param([string]$Raw)
  $meta = @{}
  $body = $Raw
  $m = [regex]::Match($Raw, '(?s)^\s*<!--meta\s*(.*?)-->\s*')
  if ($m.Success) {
    foreach ($line in ($m.Groups[1].Value -split "`n")) {
      $line = $line.Trim()
      if (-not $line) { continue }
      $i = $line.IndexOf(':')
      if ($i -lt 1) { continue }
      $meta[$line.Substring(0, $i).Trim()] = $line.Substring($i + 1).Trim()
    }
    $body = $Raw.Substring($m.Length)
  }
  return @{ meta = $meta; body = $body }
}

function BaseFor([string]$RelPath) {
  $depth = ($RelPath -split '[\\/]').Count - 1
  if ($depth -le 0) { return '' }
  return ('../' * $depth)
}

# Token substitution for generated collections inside page bodies
function Inject-Tokens {
  param([string]$Body, [string]$Base)

  $available   = $Gems | Where-Object { $_.availability -ne 'sold' }
  $sold        = $Gems | Where-Object { $_.availability -eq 'sold' }
  $exceptional = $Gems | Where-Object { $_.isExceptional -and $_.availability -ne 'sold' }

  # Results column shell, reused by every catalogue view with its own card set
  $shell = $Partials['catgrid']
  function CatGrid { param([string]$Cards) return $shell.Replace('{{CARDS}}', $Cards) }

  $map = @{
    '{{CAT_ALL}}'         = (CatGrid (GemCards ($Gems | Sort-Object { $_.featureRank }) $Base))
    '{{CAT_AVAILABLE}}'   = (CatGrid (GemCards (($Gems | Where-Object { $_.availability -ne 'sold' }) | Sort-Object { $_.featureRank }) $Base))
    '{{CAT_ARCHIVE}}'     = (CatGrid (GemCards (($Gems | Where-Object { $_.availability -eq 'sold' }) | Sort-Object { $_.featureRank }) $Base))
    '{{CAT_EXCEPTIONAL}}' = (CatGrid (GemCards (($Gems | Where-Object { $_.isExceptional }) | Sort-Object { $_.featureRank }) $Base))
    '{{CAT_RUBY}}'        = (CatGrid (GemCards (($Gems | Where-Object { $_.gemType -eq 'Ruby' })     | Sort-Object { $_.featureRank }) $Base))
    '{{CAT_SAPPHIRE}}'    = (CatGrid (GemCards (($Gems | Where-Object { $_.gemType -eq 'Sapphire' }) | Sort-Object { $_.featureRank }) $Base))
    '{{CAT_SPINEL}}'      = (CatGrid (GemCards (($Gems | Where-Object { $_.gemType -eq 'Spinel' })   | Sort-Object { $_.featureRank }) $Base))
    '{{CAT_OTHER}}'       = (CatGrid (GemCards (($Gems | Where-Object { $_.gemType -eq 'Other' })    | Sort-Object { $_.featureRank }) $Base))
    '{{GEM_CARDS_ALL}}'         = (GemCards ($Gems | Sort-Object { $_.featureRank }) $Base)
    '{{GEM_CARDS_AVAILABLE}}'   = (GemCards ($available | Sort-Object { $_.featureRank }) $Base)
    '{{GEM_CARDS_ARCHIVE}}'     = (GemCards ($sold | Sort-Object { $_.featureRank }) $Base)
    '{{GEM_CARDS_EXCEPTIONAL}}' = (GemCards ($exceptional | Sort-Object { $_.featureRank }) $Base)
    '{{GEM_CARDS_RUBY}}'        = (GemCards ($available | Where-Object { $_.gemType -eq 'Ruby' }     | Sort-Object { $_.featureRank }) $Base)
    '{{GEM_CARDS_SAPPHIRE}}'    = (GemCards ($available | Where-Object { $_.gemType -eq 'Sapphire' } | Sort-Object { $_.featureRank }) $Base)
    '{{GEM_CARDS_SPINEL}}'      = (GemCards ($available | Where-Object { $_.gemType -eq 'Spinel' }   | Sort-Object { $_.featureRank }) $Base)
    '{{GEM_CARDS_OTHER}}'       = (GemCards ($available | Where-Object { $_.gemType -eq 'Other' }    | Sort-Object { $_.featureRank }) $Base)
    '{{GEM_CARDS_FEATURED}}'    = (GemCards (($available | Sort-Object { $_.featureRank }) | Select-Object -First 3) $Base)
    '{{JWL_CARDS_ALL}}'         = (JwlCards $Jwl $Base)
    '{{JWL_CARDS_VALUE}}'       = (JwlCards ($Jwl | Where-Object { $_.collection -eq 'The Value' }) $Base)
    '{{JWL_CARDS_FEATURED}}'    = (JwlCards ($Jwl | Select-Object -First 3) $Base)
    # Only articles written out as real pages are linked. §36.2 forbids
    # "coming soon" placeholders; the remainder of the twelve-article launch
    # set is presented on /journal/learn as the editorial plan instead.
    '{{ART_CARDS_ALL}}'         = (ArtCards ($Arts | Where-Object { $_.live }) $Base)
    '{{ART_CARDS_LEARN}}'       = (ArtCards ($Arts | Where-Object { $_.live -and $_.category -eq 'learn' }) $Base)
    '{{ART_CARDS_FEATURED}}'    = (ArtCards (($Arts | Where-Object { $_.live -and $_.category -eq 'learn' }) | Select-Object -First 3) $Base)
    '{{ART_PLANNED_ROWS}}'      = (PlannedRows ($Arts | Where-Object { -not $_.live }))
    '{{SEARCH_DATA}}'           = (SearchIndex $Base)
    '{{FILTER_RAIL}}'           = $Partials['filters']
    '{{COUNT_GEMS}}'            = ([string]$available.Count)
    '{{COUNT_ALL_GEMS}}'        = ([string]$Gems.Count)
    '{{COUNT_JWL}}'             = ([string]$Jwl.Count)
    '{{COUNT_ARTS}}'            = ([string]$Arts.Count)
  }
  foreach ($k in $map.Keys) { $Body = $Body.Replace($k, $map[$k]) }
  return $Body
}

# ============================================================ build src/ ======
$written = 0
foreach ($file in (Get-ChildItem $SrcDir -Recurse -Filter *.html)) {
  $rel  = $file.FullName.Substring($SrcDir.Length + 1)
  $base = BaseFor $rel
  $parsed = Read-Meta (Get-Content $file.FullName -Raw -Encoding UTF8)
  $body = Inject-Tokens $parsed.body $base
  $out  = Join-Path $Root $rel
  $dir  = Split-Path -Parent $out
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  Set-Content -Path $out -Value (Expand-Page $body $parsed.meta $base) -Encoding UTF8
  $written++
}
Write-Host "  $written page(s) from src/" -ForegroundColor Green

# ================================================ generate gemstone details ===
$gemTmplRaw = Get-Content (Join-Path $TmplDir 'gem-detail.html') -Raw -Encoding UTF8
$base = '../'
$gemCount = 0

foreach ($g in $Gems) {
  # ---- media set -----------------------------------------------------------
  $items = ''; $thumbs = ''; $slides = ''; $dots = ''
  for ($i = 0; $i -lt $g.images.Count; $i++) {
    $img = $g.images[$i]
    $plate = Plate $g.stoneId $img.shot $img.spec
    $items  += '<div data-media-item data-caption="' + (HtmlEnc $img.shot) + '">' + $plate + '</div>'
    $thumbs += '<button class="gem__thumb" type="button" data-thumb aria-label="' + (HtmlEnc $img.shot) + '">' + (Plate $g.stoneId '' '') + '</button>'
    $slides += '<div class="gem__slide" data-open-viewer="' + $i + '">' + $plate + '</div>'
    $dots   += '<i></i>'
  }
  # Video appears in the same strip with a distinguishing icon (§13.2 item 1).
  # It is a real entry in the media set, so the thumbnail, the carousel and the
  # viewer all address it like any other item.
  if ($g.video) {
    $vplate = Plate $g.stoneId 'Video — 12 seconds' 'Stone rotating under moving light. 1080p minimum, no music, no burned-in captions (FR-CAT-045).'
    $items  += '<div data-media-item data-caption="Video — the stone rotating under moving light">' + $vplate + '</div>'
    $thumbs += '<button class="gem__thumb" type="button" data-thumb aria-label="Video, 12 seconds">' +
               (Plate $g.stoneId '' '') +
               '<span class="badge-media"><svg width="15" height="15" viewBox="0 0 15 15" fill="currentColor" aria-hidden="true"><path d="M4 2.5v10l9-5z"/></svg></span></button>'
    $slides += '<div class="gem__slide" data-open-viewer="' + $g.images.Count + '">' + $vplate + '</div>'
    $dots   += '<i></i>'
  }
  $mediaCount = $g.images.Count
  if ($g.video) { $mediaCount = $mediaCount + 1 }

  # ---- identity ------------------------------------------------------------
  $originFull = $g.originRegion + ', ' + $g.originCountry
  $subtitle = (CaratStr $g.caratWeight) + ' ct &nbsp;&middot;&nbsp; ' + (HtmlEnc $g.shape) + ' &nbsp;&middot;&nbsp; ' + (HtmlEnc $originFull)
  if ($g.isMatchedPair) { $subtitle = (CaratStr $g.caratWeight) + ' ct total, ' + $g.pieceCount + ' stones &nbsp;&middot;&nbsp; ' + (HtmlEnc $g.shape) + ' &nbsp;&middot;&nbsp; ' + (HtmlEnc $originFull) }

  $eyebrow = (HtmlEnc $g.originRegion) + ' ' + (TypeLabel $g)
  if ($g.varietyName) { $eyebrow = (HtmlEnc $g.originRegion) + ' ' + (HtmlEnc $g.varietyName) }

  $markers = '<span class="badge' + $(if ($g.treatmentStatus -eq 'unheated') { ' badge--key' } else { '' }) + '">' + (TreatLabel $g) + '</span>'
  if ($g.isCertified) { $markers += '<span class="badge">' + (HtmlEnc $g.certLab) + ' certified</span>' }
  if ($g.isExceptional) { $markers += '<span class="badge badge--exceptional">Exceptional</span>' }
  if ($g.sourcedFromOwnMine) { $markers += '<span class="badge">Our own workings</span>' }
  if ($g.cutByShopGems) { $markers += '<span class="badge">Cut in-house</span>' }
  if ($g.isMatchedPair) { $markers += '<span class="badge">Matched pair</span>' }

  # ---- key specification table --------------------------------------------
  # FR-GEM-056 — each technical term carries an accessible disclosure, not a
  # hover-only tooltip.
  function GlossRow {
    param([string]$Label, [string]$Value, [string]$GlossTitle, [string]$GlossBody, [string]$GlossLink, [string]$Base)
    $g = ''
    if ($GlossBody) {
      $g = '<span class="gloss"><button class="gloss__btn" type="button" aria-label="What does ' + (HtmlEnc $Label) + ' mean?">?</button>' +
           '<span class="gloss__pop" hidden><strong>' + (HtmlEnc $GlossTitle) + '</strong>' + $GlossBody
      if ($GlossLink) { $g += ' <a href="' + $Base + $GlossLink + '">Read more &rarr;</a>' }
      $g += '</span></span>'
    }
    return '<tr><th scope="row">' + (HtmlEnc $Label) + $g + '</th><td>' + $Value + '</td></tr>'
  }

  $specs = ''
  $specs += GlossRow 'Carat weight' ((CaratStr $g.caratWeight) + ' ct') 'Carat weight' 'A carat is 0.2 grams. Because it measures weight rather than size, two stones of equal carat weight can look noticeably different face-up depending on how they are cut.' 'journal/carat-weight-vs-visual-size.html' $base
  $specs += GlossRow 'Dimensions' ((MmStr $g.dimensions.length) + ' &times; ' + (MmStr $g.dimensions.width) + ' &times; ' + (MmStr $g.dimensions.depth) + ' mm') '' '' '' $base
  $shapeVal = HtmlEnc $g.shape
  if ($g.cuttingStyle) { $shapeVal += ', ' + (HtmlEnc $g.cuttingStyle).ToLower() + ' cut' }
  $specs += GlossRow 'Shape & cut' $shapeVal '' '' '' $base
  $colourVal = HtmlEnc $g.colorPrimary
  if ($g.colorTradeTerm) { $colourVal += '<br><span class="caption">' + (HtmlEnc $g.colorTradeTerm) + '</span>' }
  $specs += GlossRow 'Colour' $colourVal 'Trade colour terms' 'Terms such as "Pigeon''s Blood" and "Royal Blue" are issued by specific laboratories against their own reference standards. We state them only where a laboratory has issued them, with the report attributed.' 'journal/pigeons-blood-what-the-term-means.html' $base
  $specs += GlossRow 'Clarity' (HtmlEnc $g.clarityDescription) 'Clarity in coloured stones' 'Coloured stones are not graded on the diamond clarity scale — GIA does not grade them that way, and doing so signals inexperience. Clarity is described, and read in the context of the material.' '' $base
  $originVal = HtmlEnc $originFull
  if ($g.originVerifiedByLab) { $originVal += '<br><span class="caption">Origin confirmed by laboratory</span>' }
  else { $originVal += '<br><span class="caption">House assessment; not lab-confirmed</span>' }
  $specs += GlossRow 'Origin' $originVal 'Why origin matters' 'Mogok carries a distinct premium over the broader "Burma" designation. We distinguish between an origin a laboratory has confirmed and one that is our own assessment, and never blur the two.' 'journal/what-is-a-mogok-ruby.html' $base
  $specs += GlossRow 'Treatment' (TreatLabel $g) 'Treatment' 'Most rubies and sapphires on the market are heated to improve colour and clarity. This is accepted practice and must always be disclosed. Unheated stones of comparable quality are considerably rarer and command a premium.' 'journal/heated-vs-unheated-gemstones.html' $base
  if ($g.isCertified) {
    $specs += GlossRow 'Certification' ((HtmlEnc $g.certLab) + ' report ' + (HtmlEnc $g.certNumber)) '' '' '' $base
  } else {
    $specs += GlossRow 'Certification' 'Not currently certified' '' '' '' $base
  }

  # ---- price, availability, CTA -------------------------------------------
  $priceNote = ''
  if ($g.pricingModel -eq 'price-band') {
    $priceNote = '<p class="caption mt-1">Band shown so you can self-qualify. Exact price on enquiry.</p>'
  } elseif ($g.pricingModel -eq 'price-on-request' -and $g.availability -ne 'sold') {
    $priceNote = '<p class="caption mt-1">Exceptional material is priced on enquiry against the current market.</p>'
  }

  $availClass = ''
  if ($g.availability -eq 'reserved') { $availClass = 'is-reserved' }
  if ($g.availability -eq 'sold')     { $availClass = 'is-sold' }
  $availLabel = AvailLabel $g
  if ($g.availability -eq 'available') { $availLabel += ' &middot; verified this month' }

  $ctaLabel = 'Enquire about this stone'
  if ($g.isExceptional) { $ctaLabel = 'Request information' }

  if ($g.availability -eq 'sold') {
    # FR-GEM-064 — sold stones keep their URL and specifications; the price and
    # primary CTA are replaced, never the record.
    $cta  = '<div class="soldnote mb-3"><p class="eyebrow">No longer available</p>'
    $cta += '<p class="small mt-2" style="color:var(--ink-secondary)">This stone has been sold. Its record stays here as part of our track record.</p></div>'
    $cta += '<a class="btn btn--primary btn--block" href="' + $base + 'contact.html" data-enquire data-item-kind="sourcing" data-item-id="' + $g.stoneId + '" data-item-title="Something similar to ' + (HtmlEnc $g.title) + '" data-item-meta="Sourcing request">Tell us what you are seeking</a>'
  } else {
    $cta  = '<a class="btn btn--primary btn--block" href="' + $base + 'contact.html" data-enquire'
    $cta += ' data-item-kind="gemstone" data-item-id="' + $g.stoneId + '"'
    $cta += ' data-item-title="' + (HtmlEnc $g.title) + '"'
    $cta += ' data-item-meta="' + (CaratStr $g.caratWeight) + ' ct &middot; ' + (HtmlEnc $originFull) + '">' + $ctaLabel + '</a>'
    if ($g.isExceptional) {
      $cta += '<a class="btn btn--secondary btn--block" href="' + $base + 'consultation.html?gem=' + $g.stoneId + '">Arrange a private viewing</a>'
    } else {
      $cta += '<p class="mt-2"><a class="link" href="' + $base + 'consultation.html?gem=' + $g.stoneId + '">Book a consultation <span class="arw">&rarr;</span></a></p>'
    }
    # FR-CAT-021 — messaging deep-links are secondary, and pre-populate the
    # message body with the stone ID and URL so the lead stays attributable.
    $wamsg = [uri]::EscapeDataString('Enquiry about ' + $g.title + ' (' + $g.stoneId + ')')
    $cta += '<div class="gem__msg">'
    $cta += '<span class="caption" style="margin-right:4px">Or message us</span>'
    $cta += '<a href="https://wa.me/?text=' + $wamsg + '" aria-label="WhatsApp"><svg width="16" height="16" viewBox="0 0 16 16" fill="currentColor" aria-hidden="true"><path d="M8 0a8 8 0 0 0-6.9 12L0 16l4.1-1.1A8 8 0 1 0 8 0Zm0 14.5a6.5 6.5 0 0 1-3.3-.9l-.24-.14-2.44.64.65-2.38-.15-.25A6.5 6.5 0 1 1 8 14.5Zm3.7-4.87c-.2-.1-1.2-.6-1.39-.66-.19-.07-.32-.1-.46.1-.14.2-.53.66-.65.8-.12.13-.24.15-.44.05a5.3 5.3 0 0 1-1.56-.96 5.9 5.9 0 0 1-1.08-1.34c-.11-.2-.01-.31.09-.41.09-.1.2-.24.3-.36.1-.12.13-.2.2-.34.06-.13.03-.25-.02-.35-.05-.1-.44-1.07-.6-1.46-.16-.38-.32-.33-.44-.33h-.38c-.13 0-.34.05-.52.25-.18.2-.68.66-.68 1.6 0 .95.69 1.87.79 2 .1.13 1.36 2.12 3.32 2.9 1.96.77 2.19.66 2.58.62.4-.04 1.28-.52 1.46-1.03.18-.5.18-.94.13-1.03-.05-.09-.18-.14-.38-.24Z"/></svg></a>'
    $cta += '<a href="viber://chat?number=%2B959788440929" aria-label="Viber"><svg width="16" height="16" viewBox="0 0 16 16" fill="currentColor" aria-hidden="true"><path d="M8 1C4.2 1 1 3.4 1 6.9c0 1.9 1 3.6 2.6 4.7l-.5 2.9 2.7-1.5c.7.2 1.4.3 2.2.3 3.8 0 7-2.4 7-5.9S11.8 1 8 1Z"/></svg></a>'
    $cta += '<a href="mailto:enquiries@spgems-myanmar.com?subject=' + [uri]::EscapeDataString($g.stoneId + ' — ' + $g.title) + '" aria-label="Email"><svg width="16" height="16" viewBox="0 0 18 14" fill="none" aria-hidden="true"><rect x=".7" y=".7" width="16.6" height="12.6" stroke="currentColor" stroke-width="1.2"/><path d="M1 1.5 9 7.5l8-6" stroke="currentColor" stroke-width="1.2"/></svg></a>'
    $cta += '</div>'
    $cta += '<p class="gem__reassure">Typically answered within one business day. We do not operate a checkout: every enquiry is answered by a person.</p>'
  }

  # ---- provenance block (§13.2 item 6) ------------------------------------
  $blkProv = ''
  if ($g.provenanceNarrative) {
    $flag = ''
    if ($g.sourcedFromOwnMine) {
      $flag = '<p class="prov__flag mt-4">Recovered from our own workings in Mogok.</p>'
    }
    $blkProv = @"
<section class="section">
  <div class="wrap">
    <div class="split split--offset split--top" data-reveal>
      <div>
        <p class="eyebrow eyebrow--gold">Provenance</p>
        <h2 class="h2 mt-2">Where this stone came from</h2>
        <div class="prose mt-4"><p>$(HtmlEnc $g.provenanceNarrative)</p></div>
        $flag
        <p class="mt-4"><a class="link" href="${base}mogok/the-mines.html">Our mining operations <span class="arw">&rarr;</span></a></p>
      </div>
      <div class="split__media split__media--drop">
        <div style="aspect-ratio:4/5;position:relative;overflow:hidden;background:var(--charcoal-deep)">
          $(Plate '' 'Mogok — the workings' 'Documentary photography, existing asset library' 'dark')
        </div>
      </div>
    </div>
  </div>
</section>
"@
  }

  # ---- colour analysis block (§13.2 item 7) ------------------------------
  $blkColour = ''
  if ($g.colorNotes) {
    $pair = ''
    $hasPair = $false
    foreach ($im in $g.images) { if ($im.shot -match 'Daylight') { $hasPair = $true } }
    if ($hasPair) {
      $pair = '<div class="lightpair mt-4">' +
        '<figure><div class="shot">' + (Plate $g.stoneId 'Daylight 5500K' '') + '</div><figcaption>Daylight-balanced, 5500 K</figcaption></figure>' +
        '<figure><div class="shot">' + (Plate $g.stoneId 'Incandescent 2700K' '') + '</div><figcaption>Incandescent, 2700 K</figcaption></figure>' +
        '</div>'
    }
    $tradeAttr = ''
    if ($g.colorTradeTerm) {
      $tradeAttr = '<p class="mt-3"><span class="badge badge--key">' + (HtmlEnc $g.colorTradeTerm) + '</span></p>' +
        '<p class="caption mt-2">Colour graded by the laboratory named, under report ' + (HtmlEnc $g.certNumber) +
        '. We never apply trade colour terms editorially.</p>'
    }
    $blkColour = @"
<section class="section section--ivory-deep">
  <div class="wrap wrap--text">
    <div class="split" data-reveal>
      <div>
        <p class="eyebrow eyebrow--gold">Colour</p>
        <h2 class="h2 mt-2">How the colour behaves</h2>
        <div class="prose mt-4"><p>$(HtmlEnc $g.colorNotes)</p></div>
        $tradeAttr
      </div>
      <div>$pair</div>
    </div>
  </div>
</section>
"@
  }

  # ---- cut block (§13.2 item 8) ------------------------------------------
  $blkCut = ''
  if ($g.cutByShopGems) {
    $blkCut = @"
<section class="section">
  <div class="wrap wrap--text">
    <div class="split split--offset-r split--flip-mobile" data-reveal>
      <div class="split__media">
        <div style="aspect-ratio:3/2;position:relative;overflow:hidden;background:var(--charcoal-deep)">
          $(Plate '' 'The cutting wheel, Yangon' 'Existing video asset — extract a frame or shoot stills' 'dark')
        </div>
      </div>
      <div>
        <p class="eyebrow eyebrow--gold">The cut</p>
        <h2 class="h2 mt-2">Cut in our own workshop</h2>
        <div class="prose mt-4">
          <p>This stone was cut in our Yangon workshop, from rough we sorted ourselves. Cutting
          our own material means the decision about how to treat a piece of rough — whether to
          hold weight or hold colour — is made by people who will also be answering for the
          finished stone.</p>
        </div>
        <p class="mt-4"><a class="link" href="${base}mogok/craftsmanship.html">Cutting &amp; craftsmanship <span class="arw">&rarr;</span></a></p>
      </div>
    </div>
  </div>
</section>
"@
  }

  # ---- treatment copy (FR-GEM-052) ---------------------------------------
  $treatStatus = TreatLabel $g
  if ($g.treatmentStatus -eq 'unheated') {
    $treatBody = 'This ' + $g.gemType.ToLower() + ' is unheated. It has undergone no thermal or chemical enhancement of any kind.'
    $treatStatus = 'This stone is unheated'
  } elseif ($g.treatmentStatus -eq 'heated') {
    $treatBody = 'This ' + $g.gemType.ToLower() + ' has been heated. ' + (HtmlEnc $g.treatmentDetail) + '. Heating is a long-established, accepted practice in the coloured-stone trade and is not a defect — but it must always be disclosed, and it affects value relative to comparable unheated material.'
    $treatStatus = 'This stone is heated'
  } else {
    $treatBody = 'The treatment status of this stone is ' + (HtmlEnc $g.treatmentStatus) + '.'
  }
  if ($g.treatmentVerifiedByLab) {
    $treatVerify = 'This finding is confirmed by ' + (HtmlEnc $g.certLab) + ' report ' + (HtmlEnc $g.certNumber) + '. '
  } else {
    $treatVerify = 'This is our own assessment and has not been confirmed by a laboratory. We will arrange a report before sale on request. '
  }

  # ---- certification block (§13.2 item 10) -------------------------------
  if ($g.isCertified) {
    $labLink = ''
    if ($g.certLab -eq 'GRS') { $labLink = 'https://www.gemresearch.ch/' }
    if ($g.certLab -eq 'GIA') { $labLink = 'https://www.gia.edu/report-check-landing' }
    $verifyLine = ''
    if ($labLink) {
      $verifyLine = '<p class="mt-3"><a class="link" href="' + $labLink + '" rel="noopener nofollow" target="_blank">Verify this report at ' + (HtmlEnc $g.certLab) + ' <span class="arw">&rarr;</span></a></p>' +
        '<p class="caption mt-2">Verification happens on the laboratory''s own site, not ours. That is the point.</p>'
    }
    $certDateStr = ''
    if ($g.certDate) { $certDateStr = ([datetime]$g.certDate).ToString('d MMMM yyyy') }
    $blkCert = @"
<section class="section">
  <div class="wrap wrap--text">
    <div class="sec-head">
      <div class="sec-head__title">
        <p class="eyebrow eyebrow--gold">Certification</p>
        <h2 class="h2">Laboratory report</h2>
      </div>
    </div>
    <div class="cert" data-reveal>
      <div class="cert__thumb">$(Plate '' 'Report scan' 'Watermarked, max 800px long edge (FR-GEM-061)' 'cert')</div>
      <div>
        <table class="spec-table cert__rows">
          <tbody>
            <tr><th scope="row">Laboratory</th><td>$(HtmlEnc $g.certLab)</td></tr>
            <tr><th scope="row">Report number</th><td class="tnum">$(HtmlEnc $g.certNumber)</td></tr>
            <tr><th scope="row">Report date</th><td>$certDateStr</td></tr>
          </tbody>
        </table>
        <p class="small mt-3" style="color:var(--ink-secondary)">
          The report number above is public because a buyer can verify it at the laboratory
          directly. The full scan is released on enquiry — it carries our own identity and is
          the asset most often copied.
        </p>
        <p class="mt-3"><a class="btn btn--secondary btn--sm" href="${base}contact.html" data-enquire data-item-kind="certificate" data-item-id="$($g.stoneId)" data-item-title="$(HtmlEnc $g.title)" data-item-meta="Full certificate request">Request the full certificate</a></p>
        $verifyLine
      </div>
    </div>
  </div>
</section>
"@
  } else {
    # FR-GEM-058 — silence on certification reads as concealment; state it plainly
    $certLine = 'Certification can be arranged prior to purchase.'
    if (-not $g.certificationAvailableOnRequest) { $certLine = 'We do not routinely certify material of this kind; we can advise on whether a report is worth commissioning.' }
    $blkCert = @"
<section class="section">
  <div class="wrap wrap--text">
    <div class="needsconf" data-reveal style="border-left-color:var(--ink)">
      <b>Certification</b>
      <p>This stone is not currently accompanied by a laboratory report. $certLine</p>
      <p><a class="link" href="${base}journal/how-to-read-a-gemstone-laboratory-report.html">How to read a gemstone laboratory report <span class="arw">&rarr;</span></a></p>
    </div>
  </div>
</section>
"@
  }

  # ---- detailed gallery (§13.2 item 11) ----------------------------------
  $figs = ''
  for ($i = 0; $i -lt $g.images.Count; $i++) {
    $img = $g.images[$i]
    $figs += '<figure><div class="shot" data-open-viewer="' + $i + '" role="button" tabindex="0" aria-label="Enlarge: ' + (HtmlEnc $img.shot) + '">' +
             (Plate $g.stoneId $img.shot $img.spec) + '</div>' +
             '<figcaption>' + (HtmlEnc $img.shot) + '</figcaption></figure>'
  }
  $roughNote = ''
  if ($g.roughPhotoAvailable) {
    $roughNote = '<p class="needsconf mt-6" style="border-left-color:var(--gold)"><b>Rough &rarr; cut comparison available</b>' +
      'This stone has a photograph of the rough before cutting. FR-VIEW-020 renders that as a before/after comparison — ' +
      'an asset almost no competitor can produce, because almost no competitor cuts its own material. Scheduled for Phase 2.</p>'
  }
  $blkGallery = @"
<section class="section section--ivory-deep">
  <div class="wrap wrap--text">
    <div class="sec-head">
      <div class="sec-head__title">
        <p class="eyebrow eyebrow--gold">Photography</p>
        <h2 class="h2">The full image set</h2>
      </div>
      <p class="caption" style="max-width:34ch">Shot on a neutral mid-grey ground with a colour reference target in the calibration frame. We do not saturate stones.</p>
    </div>
    <div class="dgal" data-reveal>$figs</div>
    $roughNote
  </div>
</section>
"@

  # ---- related stones (FR-GEM-070) ---------------------------------------
  $scored = @()
  foreach ($o in $Gems) {
    if ($o.stoneId -eq $g.stoneId) { continue }
    $s = 0
    if ($o.gemType -eq $g.gemType)                 { $s += 3 }
    if ($o.originRegion -eq $g.originRegion)       { $s += 2 }
    if ($o.treatmentStatus -eq $g.treatmentStatus) { $s += 2 }
    if ([math]::Abs($o.caratWeight - $g.caratWeight) -le ($g.caratWeight * 0.4)) { $s += 2 }
    if ((BandKey $o.priceBand) -eq (BandKey $g.priceBand)) { $s += 1 }
    if ($o.isExceptional -eq $g.isExceptional)     { $s += 1 }
    $sold = ($o.availability -eq 'sold')
    $scored += [pscustomobject]@{ g = $o; score = $s; sold = $sold }
  }
  $rel = @($scored | Where-Object { -not $_.sold } | Sort-Object -Property score -Descending | Select-Object -First 4)
  if ($rel.Count -lt 4) {
    $rel += @($scored | Where-Object { $_.sold } | Sort-Object -Property score -Descending | Select-Object -First (4 - $rel.Count))
  }
  $relCards = ''
  foreach ($r in $rel) { $relCards += GemCard $r.g $base }

  # §14.1 — where a piece contains this catalogued stone, the two link
  # bidirectionally. This is the on-site expression of "mine to jewel".
  $inPieces = @($Jwl | Where-Object { $_.centreStone -eq $g.stoneId })
  $blkInJewellery = ''
  if ($inPieces.Count -gt 0) {
    $pieceCards = ''
    foreach ($ip in $inPieces) { $pieceCards += JwlCard $ip $base }
    $blkInJewellery = @"
<section class="section section--ivory-deep">
  <div class="wrap wrap--text">
    <div class="sec-head">
      <div class="sec-head__title">
        <p class="eyebrow eyebrow--gold">Already set</p>
        <h2 class="h2">This stone is the centre of a finished piece</h2>
      </div>
      <a class="link" href="${base}jewellery/index.html">All jewellery <span class="arw">&rarr;</span></a>
    </div>
    <div class="grid grid--3 grid--stack-mobile" data-reveal>$pieceCards</div>
    <p class="caption mt-4" style="max-width:64ch">
      The stone and the piece are the same object described twice. Enquire about either and we
      will talk about both &mdash; including whether the stone can be supplied unset.
    </p>
  </div>
</section>
"@
  }

  $blkRelated = $blkInJewellery + @"
<section class="section">
  <div class="wrap">
    <div class="sec-head">
      <div class="sec-head__title">
        <p class="eyebrow eyebrow--gold">Related</p>
        <h2 class="h2">Comparable stones</h2>
      </div>
      <a class="link" href="${base}gemstones/$(TypeSlug $g).html">All $((TypeLabel $g).ToLower()) <span class="arw">&rarr;</span></a>
    </div>
    <div class="grid grid--4" data-reveal>$relCards</div>
  </div>
</section>
"@

  # ---- mobile action bar (FR-MOB-021) ------------------------------------
  if ($g.availability -eq 'sold') {
    $abar = '<div class="abar"><a class="btn btn--primary" href="' + $base + 'contact.html" data-enquire data-item-kind="sourcing" data-item-id="' + $g.stoneId + '" data-item-title="Something similar to ' + (HtmlEnc $g.title) + '" data-item-meta="Sourcing request">Find something similar</a></div>'
  } else {
    $abar = '<div class="abar">' +
      '<a class="btn btn--primary" href="' + $base + 'contact.html" data-enquire data-item-kind="gemstone" data-item-id="' + $g.stoneId + '" data-item-title="' + (HtmlEnc $g.title) + '" data-item-meta="' + (CaratStr $g.caratWeight) + ' ct &middot; ' + (HtmlEnc $originFull) + '">' + $ctaLabel + '</a>' +
      '<a class="abar__icon" href="https://wa.me/?text=' + [uri]::EscapeDataString('Enquiry about ' + $g.title + ' (' + $g.stoneId + ')') + '" aria-label="WhatsApp"><svg width="18" height="18" viewBox="0 0 16 16" fill="currentColor" aria-hidden="true"><path d="M8 0a8 8 0 0 0-6.9 12L0 16l4.1-1.1A8 8 0 1 0 8 0Zm0 14.5a6.5 6.5 0 0 1-3.3-.9l-.24-.14-2.44.64.65-2.38-.15-.25A6.5 6.5 0 1 1 8 14.5Z"/></svg></a>' +
      '</div>'
  }

  # ---- assemble ----------------------------------------------------------
  $body = $gemTmplRaw
  $repl = [ordered]@{
    '{{MEDIA_ITEMS}}'        = $items
    '{{THUMBS}}'             = $thumbs
    '{{SLIDES}}'             = $slides
    '{{DOTS}}'               = $dots
    '{{MEDIA_COUNT}}'        = [string]$mediaCount
    '{{EYEBROW}}'            = $eyebrow
    '{{SUBTITLE}}'           = $subtitle
    '{{STONE_ID}}'           = $g.stoneId
    '{{MARKERS}}'            = $markers
    '{{KEY_SPECS}}'          = $specs
    '{{PRICE}}'              = (PriceDisplay $g)
    '{{PRICE_NOTE}}'         = $priceNote
    '{{AVAIL_CLASS}}'        = $availClass
    '{{AVAIL_LABEL}}'        = $availLabel
    '{{CTA}}'                = $cta
    '{{BLOCK_PROVENANCE}}'   = $blkProv
    '{{BLOCK_COLOUR}}'       = $blkColour
    '{{BLOCK_CUT}}'          = $blkCut
    '{{TREAT_STATUS}}'       = $treatStatus
    '{{TREAT_BODY}}'         = $treatBody
    '{{TREAT_VERIFY}}'       = $treatVerify
    '{{BLOCK_CERT}}'         = $blkCert
    '{{BLOCK_GALLERY}}'      = $blkGallery
    '{{BLOCK_RELATED}}'      = $blkRelated
    '{{TYPE_SLUG}}'          = (TypeSlug $g)
    '{{TYPE_LABEL}}'         = (TypeLabel $g)
    '{{DESC}}'               = ((HtmlEnc $g.title) + '. ' + (CaratStr $g.caratWeight) + ' ct ' + $g.shape.ToLower() + ', ' + $originFull + ', ' + (TreatLabel $g).ToLower() + '.')
    '{{TITLE}}'              = (HtmlEnc $g.title)
  }
  foreach ($k in $repl.Keys) { $body = $body.Replace($k, $repl[$k]) }

  $parsed = Read-Meta $body
  $parsed.meta['abar'] = $abar
  $out = Join-Path $Root ('gemstones/' + $g.slug + '.html')
  Set-Content -Path $out -Value (Expand-Page $parsed.body $parsed.meta $base) -Encoding UTF8
  $gemCount++
}
Write-Host "  $gemCount gemstone detail page(s)" -ForegroundColor Green

# =============================================== generate jewellery details ===
$jwlTmplRaw = Get-Content (Join-Path $TmplDir 'jwl-detail.html') -Raw -Encoding UTF8
$jwlCount = 0

foreach ($p in $Jwl) {
  $items = ''; $thumbs = ''; $slides = ''; $dots = ''
  for ($i = 0; $i -lt $p.images.Count; $i++) {
    $img = $p.images[$i]
    $plate = Plate $p.pieceId $img.shot $img.spec
    $items  += '<div data-media-item data-caption="' + (HtmlEnc $img.shot) + '">' + $plate + '</div>'
    $thumbs += '<button class="gem__thumb" type="button" data-thumb aria-label="' + (HtmlEnc $img.shot) + '">' + (Plate $p.pieceId '' '') + '</button>'
    $slides += '<div class="gem__slide" data-open-viewer="' + $i + '">' + $plate + '</div>'
    $dots   += '<i></i>'
  }

  $centre = $null
  if ($p.centreStone) { $centre = $Gems | Where-Object { $_.stoneId -eq $p.centreStone } | Select-Object -First 1 }

  $subtitle = HtmlEnc $p.metal
  if ($centre) { $subtitle += ' &nbsp;&middot;&nbsp; ' + (CaratStr $centre.caratWeight) + ' ct ' + $centre.gemType.ToLower() + ' centre stone' }

  $eyebrow = HtmlEnc $p.jewelleryType
  if ($p.collection) { $eyebrow = (HtmlEnc $p.collection) + ' &middot; ' + (HtmlEnc $p.jewelleryType) }

  $markers = ''
  if ($p.isOneOfAKind) { $markers += '<span class="badge badge--key">One of a kind</span>' }
  if ($p.canBeRemade)  { $markers += '<span class="badge">Can be remade</span>' }
  if ($centre)         { $markers += '<span class="badge">Catalogued centre stone</span>' }
  if ($p.sizeAdjustable) { $markers += '<span class="badge">Resizable</span>' }
  $markers += '<span class="badge">Made in Yangon</span>'

  $specs = ''
  $specs += '<tr><th scope="row">Type</th><td>' + (HtmlEnc $p.jewelleryType) + '</td></tr>'
  $specs += '<tr><th scope="row">Metal</th><td>' + (HtmlEnc $p.metal) + $(if ($p.metalWeight) { ', ' + ([decimal]$p.metalWeight).ToString('0.0') + ' g' } else { '' }) + '</td></tr>'
  if ($centre) {
    $specs += '<tr><th scope="row">Centre stone</th><td>' + (CaratStr $centre.caratWeight) + ' ct ' + (HtmlEnc $centre.gemType) + ', ' + (HtmlEnc $centre.originRegion) + '<br><span class="caption">' + (TreatLabel $centre) + '</span></td></tr>'
  }
  if ($p.additionalStones) { $specs += '<tr><th scope="row">Other stones</th><td>' + (HtmlEnc $p.additionalStones) + '</td></tr>' }
  if ($p.ringSize) { $specs += '<tr><th scope="row">Size</th><td>' + (HtmlEnc $p.ringSize) + $(if ($p.sizeAdjustable) { ' &middot; resizable' } else { '' }) + '</td></tr>' }
  if ($p.designer) { $specs += '<tr><th scope="row">Designer</th><td>' + (HtmlEnc $p.designer) + '</td></tr>' }
  if ($p.productionLeadTimeDays) { $specs += '<tr><th scope="row">Lead time</th><td>Approximately ' + $p.productionLeadTimeDays + ' days</td></tr>' }

  $price = 'Price on Request'
  $priceNote = ''
  if ($p.pricingModel -eq 'public-price') {
    $price = 'US$' + ([int]$p.priceUSD).ToString('N0')
    $priceNote = '<p class="caption mt-1">Excludes shipping, insurance and any duty payable in your country.</p>'
  } elseif ($p.pricingModel -eq 'price-band') {
    $price = BandDisplay $p.priceBand
    $priceNote = '<p class="caption mt-1">Band shown so you can self-qualify. Exact price on enquiry.</p>'
  }

  $availClass = ''
  if ($p.availability -eq 'sold') { $availClass = 'is-sold' }
  $availLabel = 'Available'
  if ($p.availability -eq 'sold') { $availLabel = 'Sold' }
  elseif ($p.isOneOfAKind) { $availLabel = 'Available &middot; this piece is unique' }

  $cta  = '<a class="btn btn--primary btn--block" href="' + $base + 'contact.html" data-enquire'
  $cta += ' data-item-kind="jewellery" data-item-id="' + $p.pieceId + '"'
  $cta += ' data-item-title="' + (HtmlEnc $p.title) + '"'
  $cta += ' data-item-meta="' + (HtmlEnc $p.metal) + '">Enquire about this piece</a>'
  $cta += '<p class="mt-2"><a class="link" href="' + $base + 'consultation.html">Book a consultation <span class="arw">&rarr;</span></a></p>'
  $cta += '<p class="gem__reassure">Typically answered within one business day. We do not operate a checkout: every enquiry is answered by a person.</p>'

  # §14.3 — the centre-stone module. Where a piece contains a catalogued stone,
  # the two link bidirectionally. This is what separates SP Gems from a
  # jewellery retailer, and it is the highest-value block on the page.
  $blkCentre = ''
  if ($centre) {
    $blkCentre = @"
<section class="section section--ivory-deep">
  <div class="wrap wrap--text">
    <div class="sec-head">
      <div class="sec-head__title">
        <p class="eyebrow eyebrow--gold">The centre stone</p>
        <h2 class="h2">This piece is built around a stone in our catalogue</h2>
      </div>
      <a class="link" href="${base}gemstones/$($centre.slug).html">Full stone record <span class="arw">&rarr;</span></a>
    </div>
    <div class="cert" data-reveal>
      <div style="aspect-ratio:4/5;position:relative;overflow:hidden;background:var(--stone)">$(Plate $centre.stoneId $centre.images[0].shot '')</div>
      <div>
        <h3 class="h3">$(HtmlEnc $centre.title)</h3>
        <p class="stone-id mt-2">$($centre.stoneId)</p>
        <table class="spec-table mt-3">
          <tbody>
            <tr><th scope="row">Carat weight</th><td>$(CaratStr $centre.caratWeight) ct</td></tr>
            <tr><th scope="row">Dimensions</th><td>$(MmStr $centre.dimensions.length) &times; $(MmStr $centre.dimensions.width) &times; $(MmStr $centre.dimensions.depth) mm</td></tr>
            <tr><th scope="row">Origin</th><td>$(HtmlEnc $centre.originRegion), $(HtmlEnc $centre.originCountry)</td></tr>
            <tr><th scope="row">Treatment</th><td>$(TreatLabel $centre)</td></tr>
            <tr><th scope="row">Certification</th><td>$(if ($centre.isCertified) { (HtmlEnc $centre.certLab) + ' report ' + (HtmlEnc $centre.certNumber) } else { 'Not currently certified' })</td></tr>
          </tbody>
        </table>
        <p class="small mt-3" style="color:var(--ink-secondary)">
          The ring and the report describe the same object. A jewellery retailer buying finished
          goods cannot show you this, because it does not know.
        </p>
      </div>
    </div>
  </div>
</section>
"@
  }

  # §14.3 — bespoke cross-sell on one-of-a-kind pieces
  $blkBespoke = ''
  if ($p.isOneOfAKind) {
    $blkBespoke = @"
<section class="section">
  <div class="wrap wrap--narrow tc" data-reveal>
    <p class="eyebrow eyebrow--gold">Commissions</p>
    <h2 class="h2 mt-2">This piece is unique</h2>
    <p class="lede mt-3" style="margin-inline:auto">
      There is only one of it. A comparable piece can be commissioned around a different stone
      from our catalogue, or around a stone of your own — start a conversation rather than a form.
    </p>
    <div class="row mt-6" style="justify-content:center">
      <a class="btn btn--primary" href="${base}jewellery/bespoke.html">Start a commission</a>
    </div>
  </div>
</section>
"@
  } elseif ($p.canBeRemade) {
    $blkBespoke = @"
<section class="section">
  <div class="wrap wrap--narrow tc" data-reveal>
    <p class="eyebrow eyebrow--gold">Made to order</p>
    <h2 class="h2 mt-2">This setting can be made around another stone</h2>
    <p class="lede mt-3" style="margin-inline:auto">
      Approximately $($p.productionLeadTimeDays) days from agreement. Choose a stone from the
      catalogue, or bring your own.
    </p>
    <div class="row mt-6" style="justify-content:center">
      <a class="btn btn--secondary" href="${base}gemstones/index.html">Browse gemstones</a>
      <a class="btn btn--primary" href="${base}jewellery/bespoke.html">Start a commission</a>
    </div>
  </div>
</section>
"@
  }

  $figs = ''
  for ($i = 0; $i -lt $p.images.Count; $i++) {
    $img = $p.images[$i]
    $figs += '<figure><div class="shot" data-open-viewer="' + $i + '" role="button" tabindex="0" aria-label="Enlarge: ' + (HtmlEnc $img.shot) + '">' +
             (Plate $p.pieceId $img.shot $img.spec) + '</div><figcaption>' + (HtmlEnc $img.shot) + '</figcaption></figure>'
  }
  $blkGallery = @"
<section class="section section--ivory-deep">
  <div class="wrap wrap--text">
    <div class="sec-head">
      <div class="sec-head__title">
        <p class="eyebrow eyebrow--gold">Photography</p>
        <h2 class="h2">The full image set</h2>
      </div>
      <p class="caption" style="max-width:36ch">Product-on-neutral is necessary but insufficient. At least one image shows the piece worn, for scale.</p>
    </div>
    <div class="dgal" data-reveal>$figs</div>
  </div>
</section>
"@

  $relPieces = @($Jwl | Where-Object { $_.pieceId -ne $p.pieceId } | Select-Object -First 3)
  $relCards = ''
  foreach ($r in $relPieces) { $relCards += JwlCard $r $base }
  $blkRelated = @"
<section class="section">
  <div class="wrap">
    <div class="sec-head">
      <div class="sec-head__title">
        <p class="eyebrow eyebrow--gold">Also in the collection</p>
        <h2 class="h2">Other pieces</h2>
      </div>
      <a class="link" href="${base}jewellery/index.html">All jewellery <span class="arw">&rarr;</span></a>
    </div>
    <div class="grid grid--3" data-reveal>$relCards</div>
  </div>
</section>
"@

  $crumbCol = ''
  if ($p.collection -eq 'The Value') {
    $crumbCol = '<a href="' + $base + 'jewellery/collections/the-value.html">The Value</a><span class="sep">/</span>'
  }

  $designNotes = $p.designNotes
  if (-not $designNotes) { $designNotes = 'Made in our Yangon workshop, around material we cut ourselves.' }

  $abar = '<div class="abar"><a class="btn btn--primary" href="' + $base + 'contact.html" data-enquire data-item-kind="jewellery" data-item-id="' + $p.pieceId + '" data-item-title="' + (HtmlEnc $p.title) + '" data-item-meta="' + (HtmlEnc $p.metal) + '">Enquire about this piece</a></div>'

  $body = $jwlTmplRaw
  $repl = [ordered]@{
    '{{MEDIA_ITEMS}}'        = $items
    '{{THUMBS}}'             = $thumbs
    '{{SLIDES}}'             = $slides
    '{{DOTS}}'               = $dots
    '{{MEDIA_COUNT}}'        = [string]$p.images.Count
    '{{EYEBROW}}'            = $eyebrow
    '{{SUBTITLE}}'           = $subtitle
    '{{PIECE_ID}}'           = $p.pieceId
    '{{MARKERS}}'            = $markers
    '{{KEY_SPECS}}'          = $specs
    '{{PRICE}}'              = $price
    '{{PRICE_NOTE}}'         = $priceNote
    '{{AVAIL_CLASS}}'        = $availClass
    '{{AVAIL_LABEL}}'        = $availLabel
    '{{CTA}}'                = $cta
    '{{BLOCK_CENTRE_STONE}}' = $blkCentre
    '{{BLOCK_BESPOKE}}'      = $blkBespoke
    '{{BLOCK_GALLERY}}'      = $blkGallery
    '{{BLOCK_RELATED}}'      = $blkRelated
    '{{CRUMB_COLLECTION}}'   = $crumbCol
    '{{DESIGN_NOTES}}'       = (HtmlEnc $designNotes)
    '{{DESC}}'               = ((HtmlEnc $p.title) + '. ' + (HtmlEnc $p.metal) + '. Made in Yangon by SP Gems.')
    '{{TITLE}}'              = (HtmlEnc $p.title)
  }
  foreach ($k in $repl.Keys) { $body = $body.Replace($k, $repl[$k]) }

  $parsed = Read-Meta $body
  $parsed.meta['abar'] = $abar
  $out = Join-Path $Root ('jewellery/' + $p.slug + '.html')
  Set-Content -Path $out -Value (Expand-Page $parsed.body $parsed.meta $base) -Encoding UTF8
  $jwlCount++
}
Write-Host "  $jwlCount jewellery detail page(s)" -ForegroundColor Green

Write-Host "Done." -ForegroundColor Cyan
