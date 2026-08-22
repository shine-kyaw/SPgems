<#
 Minimal static file server for local preview.
 There is no Node on this machine, and file:// breaks relative asset paths in
 some browsers, so this serves the built site over HTTP instead.

   powershell -ExecutionPolicy Bypass -File tools/serve.ps1 -Port 8787

 Ctrl-C to stop. This is a development convenience only — Vercel serves the
 built files directly and never runs this.
#>
param([int]$Port = 8787)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot

$types = @{
  '.html' = 'text/html; charset=utf-8'
  '.css'  = 'text/css; charset=utf-8'
  '.js'   = 'text/javascript; charset=utf-8'
  '.json' = 'application/json; charset=utf-8'
  '.svg'  = 'image/svg+xml'
  '.png'  = 'image/png'
  '.jpg'  = 'image/jpeg'
  '.webp' = 'image/webp'
  '.woff2'= 'font/woff2'
  '.txt'  = 'text/plain; charset=utf-8'
  '.xml'  = 'application/xml; charset=utf-8'
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
Write-Host "SP Gems preview on http://localhost:$Port/  (root: $Root)" -ForegroundColor Cyan

while ($listener.IsListening) {
  try {
    $ctx = $listener.GetContext()
    $rel = [uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath).TrimStart('/')
    if ($rel -eq '') { $rel = 'index.html' }
    $path = Join-Path $Root $rel

    # Clean-URL support, matching Vercel's behaviour
    if (-not (Test-Path $path -PathType Leaf)) {
      if (Test-Path (Join-Path $Root ($rel + '.html')) -PathType Leaf) {
        $path = Join-Path $Root ($rel + '.html')
      } elseif (Test-Path $path -PathType Container) {
        $path = Join-Path $path 'index.html'
      }
    }

    if (Test-Path $path -PathType Leaf) {
      $ext = [System.IO.Path]::GetExtension($path).ToLower()
      if ($types.ContainsKey($ext)) { $ctx.Response.ContentType = $types[$ext] }
      else { $ctx.Response.ContentType = 'application/octet-stream' }
      $bytes = [System.IO.File]::ReadAllBytes($path)
      $ctx.Response.StatusCode = 200
      $ctx.Response.ContentLength64 = $bytes.Length
      $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    } else {
      $ctx.Response.StatusCode = 404
      $ctx.Response.ContentType = 'text/plain; charset=utf-8'
      $msg = [System.Text.Encoding]::UTF8.GetBytes("404 — not found: /$rel")
      $ctx.Response.OutputStream.Write($msg, 0, $msg.Length)
      Write-Host "  404 /$rel" -ForegroundColor DarkYellow
    }
    $ctx.Response.OutputStream.Close()
  } catch {
    Write-Host "  error: $($_.Exception.Message)" -ForegroundColor Red
  }
}
