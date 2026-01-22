<#
    .SYNOPSIS
        Automatiza la limpieza de Máquinas Virtuales VMware mediante clonado de snapshots "Golden State".

    .DESCRIPTION
        Este script permite "resetear" una máquina virtual a un estado limpio y optimizado basándose en un snapshot
        marcado con un texto específico (por defecto "(OK)").
        
        El proceso realiza lo siguiente:
        1. Identifica el snapshot marcado.
        2. Clona la VM desde ese snapshot a una nueva ubicación temporal.
        3. Realiza un backup de la VM original.
        4. Reemplaza la original con la versión limpia.

    .NOTES
        Nombre Script:  Invoke-VMSnapshotCleanup.ps1
        Autor:          Alex Monrás
        Fecha Creación: 2026-01-21
        Versión:        1.1.0 (Encoding & Bugfixes)

    .PARAMETER Path
        Ruta completa al archivo .vmx de la máquina virtual.

    .PARAMETER SnapshotTag
        Texto que debe contener el nombre del snapshot para ser considerado el "Golden State".
        Por defecto: "(OK)"

    .PARAMETER KeepBackup
        (Reservado para futuras versiones) Si se especifica, mantiene la carpeta de la VM original.

    .EXAMPLE
        .\Invoke-VMSnapshotCleanup.ps1 -Path "D:\VMs\Cliente_TC\Cliente_TC.vmx"
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false, Position = 0)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$Path,

    [Parameter(Mandatory = $false)]
    [string]$SnapshotTag = "(OK)"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Fix encoding for special characters (accents, emojis, etc.)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Configuración
$VMRUN_PATH_X86 = "C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe"
$VMRUN_PATH_X64 = "C:\Program Files\VMware\VMware Workstation\vmrun.exe"

function Get-VMRunPath {
    if (Test-Path $VMRUN_PATH_X86) { return $VMRUN_PATH_X86 }
    if (Test-Path $VMRUN_PATH_X64) { return $VMRUN_PATH_X64 }
    throw "No se encontró vmrun.exe en las ubicaciones estándar."
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $Color = switch ($Level) {
        "INFO" { "Cyan" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR" { "Red" }
        Default { "White" }
    }
    Write-Host "[$Timestamp] [$Level] $Message" -ForegroundColor $Color
}

try {
    $VMRun = Get-VMRunPath
    Write-Log "Usando vmrun: $VMRun"
    
    # -------------------------------------------------------------------------
    # Helper Functions
    # -------------------------------------------------------------------------
    function Show-Menu {
        param (
            [Parameter(Mandatory = $true)] [array]$Items,
            [string]$Title = "Seleccione una opción"
        )
        Clear-Host
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host " $Title " -ForegroundColor White
        Write-Host "==========================================" -ForegroundColor Cyan
        
        for ($i = 0; $i -lt $Items.Count; $i++) {
            Write-Host " [$($i+1)] $($Items[$i])"
        }
        Write-Host " [Q] Salir"
        Write-Host "==========================================" -ForegroundColor Cyan
        
        while ($true) {
            $Selection = Read-Host "Elija una opción (1-$($Items.Count))"
            if ($Selection -eq 'Q' -or $Selection -eq 'q') {
                exit
            }
            if ($Selection -match '^\d+$' -and [int]$Selection -gt 0 -and [int]$Selection -le $Items.Count) {
                return $Items[[int]$Selection - 1]
            }
            Write-Warning "Opción inválida."
        }
    }

    function Get-VMList {
        param ([string]$RootPath = "$env:USERPROFILE\Documents\Virtual Machines")
        Write-Host "Buscando máquinas virtuales en: $RootPath ..." -ForegroundColor Gray
        $VMs = Get-ChildItem -Path $RootPath -Recurse -Filter *.vmx -ErrorAction SilentlyContinue | Where-Object { $_.Extension -eq '.vmx' } 
        return $VMs
    }

    function Get-VMSnapshotList {
        param ([string]$VMPath)
        Write-Host "Obteniendo snapshots para: $VMPath ..." -ForegroundColor Gray
        $SnapshotOutput = & $VMRun listSnapshots "$VMPath" 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "No se pudieron listar snapshots o no hay snapshots."
            return @()
        }
        # Skip header "Total snapshots: N"
        $Snaps = $SnapshotOutput | Select-Object -Skip 1 | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        return $Snaps
    }

    # -------------------------------------------------------------------------
    # Main Logic
    # -------------------------------------------------------------------------

    function Process-VMReset {
        param([string]$InputPath)
        
        $TargetVMPath = $InputPath
        $TargetSnapshotName = $null

        # 1. Selector de VM (si no se pasó por parámetro)
        if (-not $TargetVMPath) {
            $VMFiles = @(Get-VMList | Where-Object { $_ })
            if ($VMFiles.Count -eq 0) {
                throw "No se encontraron archivos .vmx en la ubicación por defecto."
            }
            
            # Crear lista para menú con nombres más amigables
            $MenuItems = $VMFiles | ForEach-Object { "$($_.BaseName)  ($($_.FullName))" }
            $SelectedString = Show-Menu -Items $MenuItems -Title "Selección de Máquina Virtual"
            
            $SelectedVMFile = $VMFiles | Where-Object { "$($_.BaseName)  ($($_.FullName))" -eq $SelectedString } | Select-Object -First 1
            $TargetVMPath = $SelectedVMFile.FullName
        }
    
        $SourceVM = Get-Item $TargetVMPath
        $SourceDir = $SourceVM.Directory
        $VMName = $SourceVM.BaseName
        
        Write-Log "VM Seleccionada: $($SourceVM.FullName)"
    
        # 2. Selector de Snapshot
        $AllSnapshots = @(Get-VMSnapshotList -VMPath $TargetVMPath | Where-Object { $_ })
        if ($AllSnapshots.Count -eq 0) {
            throw "La VM seleccionada no tiene snapshots."
        }
    
        $SnapshotMenuItems = $AllSnapshots
        if ($SnapshotTag -ne "(OK)") {
            $SnapshotMenuItems = $AllSnapshots | ForEach-Object {
                if ($_ -match [regex]::Escape($SnapshotTag)) { "$_  <-- RECOMENDADO ($SnapshotTag)" } else { $_ }
            }
        }
    
        $SelectedSnapString = Show-Menu -Items $SnapshotMenuItems -Title "Selección de Snapshot para Clonar"
        $TargetSnapshotName = $SelectedSnapString -replace "  <-- RECOMENDADO .*$", ""
    
        Write-Log "Snapshot seleccionado: $TargetSnapshotName" "SUCCESS"
    
        # 3. Preparar Clonación
        $ParentDir = $SourceDir.Parent
        $NewDirName = "$($SourceDir.Name)_New"
        $NewDir = Join-Path $ParentDir.FullName $NewDirName
        $NewVMPath = Join-Path $NewDir "$($SourceVM.Name)"
    
        if (Test-Path $NewDir) {
            Write-Log "El directorio temporal de destino ya existe: $NewDir. Limpiando..." "WARNING"
            Remove-Item $NewDir -Recurse -Force
        }
        
        # 4. Ejecutar Clonación
        Write-Log "Iniciando clonación FULL desde snapshot '$TargetSnapshotName'... (Esto puede tardar)"
        Write-Log "Origen: $($SourceVM.FullName)"
        Write-Log "Destino: $NewVMPath"
        
        $CloneResult = & $VMRun -T ws clone "$($SourceVM.FullName)" "$NewVMPath" full -snapshot="$TargetSnapshotName" -cloneName="$VMName" 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            throw "Error crítico durante la clonación: $CloneResult"
        }
    
        if (-not (Test-Path $NewVMPath)) {
            throw "La clonación completó pero no se encuentra el archivo .vmx destino. Salida: $CloneResult"
        }
        Write-Log "Clonación completada exitosamente." "SUCCESS"
    
        # 4. Intercambio (Swap)
        Write-Log "Realizando intercambio de carpetas..."
        
        Write-Log "Asegurando que la VM original esté detenida..."
        try {
            & $VMRun stop "$($SourceVM.FullName)" hard 2>&1 | Out-Null
        }
        catch {
            Write-Log "Nota: Intento de detener VM devolvió: $($_.Exception.Message)" "WARNING"
        }
        
        Start-Sleep -Seconds 2
    
        $OldDirName = "$($SourceDir.Name)_Trash_$((Get-Date).ToString('yyyyMMdd_HHmmss'))"
        $OldDirPath = Join-Path $ParentDir.FullName $OldDirName
        
        Write-Log "Moviendo original a: $OldDirName"
        Rename-Item -Path $SourceDir.FullName -NewName $OldDirName
        
        Write-Log "Estableciendo nueva VM como producción..."
        Rename-Item -Path $NewDir -NewName $SourceDir.Name
    
        Write-Log "---------------------------------------------------"
        Write-Log "Proceso Terminado." "SUCCESS"
        Write-Log "La nueva VM está lista en: $($SourceVM.FullName)"
        Write-Log "La VM antigua se ha movido a: $OldDirPath"
        Write-Log "Puede borrar la carpeta antigua manualmente cuando verifique que todo está correcto." "INFO"
        Write-Log "---------------------------------------------------"
    }

    function Process-Cleanup {
        $RootPath = "$env:USERPROFILE\Documents\Virtual Machines"
        Write-Host "Buscando carpetas '_Trash_' en $RootPath..." -ForegroundColor Gray
        
        if (-not (Test-Path $RootPath)) {
            Write-Warning "Ruta de VMs no encontrada: $RootPath"
            return
        }

        while ($true) {
            $TrashItems = @(Get-ChildItem -Path $RootPath -Directory | Where-Object { $_.Name -match "_Trash_\d{8}_\d{6}" } | Sort-Object CreationTime -Descending)
            
            if ($TrashItems.Count -eq 0) {
                Write-Log "No se encontraron más carpetas de respaldo antiguas." "INFO"
                return
            }

            $MenuItems = $TrashItems | ForEach-Object { "$($_.Name)  [$($_.CreationTime.ToString('yyyy-MM-dd HH:mm'))]" }
            
            $Selection = Show-Menu -Items $MenuItems -Title "Seleccione Carpeta para ELIMINAR PERMANENTEMENTE"
            
            $SelectedDir = $TrashItems | Where-Object { "$($_.Name)  [$($_.CreationTime.ToString('yyyy-MM-dd HH:mm'))]" -eq $Selection } | Select-Object -First 1
            
            if ($SelectedDir) {
                Write-Host "`n"
                Write-Warning "---------------------------------------------------------"
                Write-Warning " SE VA A ELIMINAR: $($SelectedDir.FullName)"
                Write-Warning "---------------------------------------------------------"
                
                $Confirm = Read-Host "¿Escriba 'BORRAR' para confirmar?"
                if ($Confirm -eq 'BORRAR') {
                    Write-Log "Eliminando..."
                    Remove-Item -Path $SelectedDir.FullName -Recurse -Force -ErrorAction Stop
                    Write-Log "Eliminado correctamente." "SUCCESS"
                }
                else {
                    Write-Log "Operación cancelada." "WARNING"
                }
                
                $Continue = Read-Host "¿Desea eliminar otra carpeta? (S/N)"
                if ($Continue -notmatch "S|s") {
                    break
                }
            }
        }
    }

    # -------------------------------------------------------------------------
    # Execution Flow
    # -------------------------------------------------------------------------
    
    if ($Path) {
        # Modo 'Automático/Directo' (con parámetros)
        Process-VMReset -InputPath $Path
    }
    else {
        # Modo Interactivo (Menú Principal)
        while ($true) {
            $MainOption = Show-Menu -Items @("Resetear VM (Clonar Snapshot)", "Limpiar VMs Antiguas (_Trash_)") -Title "Menú Principal - VMware Toolbox"
            
            if ($MainOption -match "Resetear") { 
                Process-VMReset -InputPath $null
                Write-Host "`nPresione ENTER para continuar..."
                Read-Host
            }
            elseif ($MainOption -match "Limpiar") { 
                Process-Cleanup
                Write-Host "`nPresione ENTER para continuar..."
                Read-Host
            }
        }
    }

}
catch {
    Write-Log "Error Crítico: $($_.Exception.Message)" "ERROR"
    exit 1
}

