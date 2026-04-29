# =====================================================
# Dump du schéma Supabase — CRM FSD
# Projet : ajukuwrznhfsfdeejdkl
# =====================================================
# Génère db/schema.sql à partir de la base de prod.
# Schema-only (pas de données — donc safe pour Git).
#
# Pré-requis :
#   - PostgreSQL client installé (pg_dump.exe accessible)
#     Téléchargement : https://www.postgresql.org/download/windows/
#   - Mot de passe DB Supabase (Dashboard > Settings > Database)
#
# Exécution depuis le dossier racine du repo :
#   .\db\dump_schema.ps1
# =====================================================

# --- Configuration ---
$ProjectRef    = "ajukuwrznhfsfdeejdkl"
$DbHost        = "db.$ProjectRef.supabase.co"
$DbPort        = "5432"
$DbName        = "postgres"
$DbUser        = "postgres"
$OutputDir     = "db"
$SchemaFile    = "$OutputDir\schema.sql"
$BackupFile    = "$OutputDir\schema_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').sql"

# --- Vérifications ---
if (-not (Get-Command pg_dump -ErrorAction SilentlyContinue)) {
    Write-Host "ERREUR : pg_dump introuvable dans le PATH." -ForegroundColor Red
    Write-Host "Installer PostgreSQL : https://www.postgresql.org/download/windows/"
    Write-Host "Et ajouter C:\Program Files\PostgreSQL\<version>\bin au PATH."
    exit 1
}

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
    Write-Host "Dossier $OutputDir créé."
}

# --- Mot de passe ---
# Soit via variable d'environnement SUPABASE_DB_PASSWORD,
# soit demandé interactivement (saisie masquée).
if ($env:SUPABASE_DB_PASSWORD) {
    Write-Host "Utilisation de SUPABASE_DB_PASSWORD depuis l'environnement."
    $env:PGPASSWORD = $env:SUPABASE_DB_PASSWORD
} else {
    $secure = Read-Host "Mot de passe DB Supabase (masqué)" -AsSecureString
    $bstr   = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    $env:PGPASSWORD = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
}

# --- Backup de l'ancien schema.sql si présent ---
if (Test-Path $SchemaFile) {
    Copy-Item $SchemaFile $BackupFile
    Write-Host "Ancien schéma sauvegardé dans $BackupFile" -ForegroundColor Yellow
}

# --- Dump ---
Write-Host "`nDump en cours depuis $DbHost ..." -ForegroundColor Cyan

pg_dump `
    --host=$DbHost `
    --port=$DbPort `
    --username=$DbUser `
    --dbname=$DbName `
    --schema=public `
    --schema-only `
    --no-owner `
    --no-privileges `
    --no-comments `
    --file=$SchemaFile

$exitCode = $LASTEXITCODE

# --- Cleanup ---
$env:PGPASSWORD = $null
Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue

# --- Verdict ---
if ($exitCode -eq 0) {
    $size = (Get-Item $SchemaFile).Length
    Write-Host "`nOK : $SchemaFile généré ($([math]::Round($size/1024, 1)) Ko)" -ForegroundColor Green
    Write-Host "`nProchaines étapes :"
    Write-Host "  1. git diff $SchemaFile          # voir ce qui a changé"
    Write-Host "  2. git add $SchemaFile"
    Write-Host "  3. git commit -m 'db: snapshot schema $(Get-Date -Format yyyy-MM-dd)'"
} else {
    Write-Host "`nERREUR : pg_dump a échoué (code $exitCode)" -ForegroundColor Red
    Write-Host "Pistes :"
    Write-Host "  - Vérifier le mot de passe (Dashboard > Settings > Database)"
    Write-Host "  - Vérifier que ton IP est autorisée (Supabase autorise tout par défaut, mais à vérifier)"
    Write-Host "  - Tester la connexion : psql -h $DbHost -U $DbUser -d $DbName"
    exit $exitCode
}
