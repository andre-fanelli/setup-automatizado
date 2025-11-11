<#
.SYNOPSIS
    Script de configuração totalmente automatizado para novos PCs.
.DESCRIPTION
    Executa uma sequência linear de limpeza, instalação e configuração de domínio,
    sobrevivendo a reinicializações para completar o processo com o mínimo de intervenção.
.AUTHOR
    André Fanelli
.VERSION
    1.0 (Automatizado)
#>

param(
    # Parâmetro para controlar em qual etapa da automação o script está.
    [Parameter(Mandatory=$false)]
    [string]$Stage = "1"
)

# --- INÍCIO: Configuração do Log (Transcript) ---

$logPath = Join-Path -Path $PSScriptRoot -ChildPath "Logs"
if (-NOT (Test-Path $logPath)) { New-Item -Path $logPath -ItemType Directory | Out-Null }
$logFile = Join-Path -Path $logPath -ChildPath "Config-PC-$(Get-Date -Format 'yyyy-MM-dd').log"

# Usa -Append para continuar no mesmo log após reinicializações
Start-Transcript -Path $logFile -Append

# --- FIM: Configuração do Log ---

#================================================================================
# ÁREAS DE PERSONALIZAÇÃO (Configure suas listas aqui)
#================================================================================
function Get-ProgramasPadraoWinget {
    $programas = @{
        "Google Chrome" = "Google.Chrome";
        "Adobe Reader" = "Adobe.Acrobat.Reader.64-bit";
    }
    return $programas
}

# ----- LISTA DE PROGRAMAS INSTALADOS A PARTIR DE INSTALADORES LOCAIS COM ARGUMENTOS PARA INSTALAÇÃO SILENCIOSA -----
function Get-ProgramasPadraoExecutavel {
    $programas = @(
        [pscustomobject]@{
            Nome       = "7-zip"
            Arquivo    = "7z2405-x64.exe"
            Argumentos = "/S"
        },
        [pscustomobject]@{
            Nome       = "Google Drive"
            Arquivo    = "GoogleDriveSetup.exe"
            Argumentos = "--silent --desktop_shortcut --skip_launch_new --gsuite_shortcuts=false"
        }
    )
    return $programas
}

function Get-BloatwareAppxLista {
    $listaDeBloatware = @(

        # Lista universal e segura de bloatware para W10/W11

        # --- Aplicativos de Parceiros e Terceiros ---
        "SpotifyAB.SpotifyMusic"
        "Disney.37853FC22B2CE" # Disney+
        "Clipchamp.Clipchamp"

        # --- Aplicativos de Mídia e Jogos da Microsoft ---
        "Microsoft.MicrosoftSolitaireCollection"
        "Microsoft.Xbox.TCUI"
        "Microsoft.XboxApp"
        "Microsoft.GamingApp"
        #"Microsoft.XboxGameOverlay"
        #"Microsoft.XboxGamingOverlay"
        "Microsoft.XboxIdentityProvider"
        "Microsoft.XboxSpeechToTextOverlay"
        #"Microsoft.ZuneMusic" # Groove Music
        #"Microsoft.ZuneVideo" # Filmes e TV
        
        # --- Aplicativos 3D e Realidade Mista ---
        "Microsoft.Microsoft3DViewer"
        "Microsoft.MSPaint" # Paint 3D
        "Microsoft.MixedReality.Portal"

        # --- Utilitários e Ferramentas Pré-instaladas ---
        "Microsoft.BingNews"
        "Microsoft.BingSearch"
        "Microsoft.BingWeather"
        "Microsoft.GetHelp"
        "Microsoft.Getstarted"
        "Microsoft.MicrosoftOfficeHub" # App "Office/Microsoft 365" (atalho web)
        #"Microsoft.MicrosoftStickyNotes"
        "Microsoft.Office.OneNote" # OneNote para Windows 10
        "Microsoft.OutlookForWindows" # Novo Outlook (prévia)
        "Microsoft.People"
        "Microsoft.PowerAutomateDesktop"
        "Microsoft.Office.OneNote"
        "Microsoft.SkypeApp"
        "Microsoft.Todos"
        "Microsoft.Wallet"
        "Microsoft.WindowsFeedbackHub"
        "Microsoft.WindowsMaps"
        "Microsoft.YourPhone"
        "MicrosoftWindows.Client.WebExperience" # Widgets / Notícias e Interesses
        "Microsoft.Copilot" 
	"Microsoft.WindowsCopilot"
        "Microsoft.Windows.DevHome"
	"Microsoft.Linkedin"
	"MSTeams"
	"Microsoft.Windows.Family"
	"Microsoft.Windows.ParentalControls"

        # --- Potencialmente Úteis (Descomente para remover) ---
        # "Microsoft.ScreenSketch" # Ferramenta de Captura e Esboço
        # "Microsoft.WindowsAlarms" # Alarmes e Relógio
        # "Microsoft.WindowsCamera"
        # "microsoft.windowscommunicationsapps" # Email e Calendário
        # "Microsoft.WindowsSoundRecorder" # Gravador de Voz
        # "Microsoft.WindowsCalculator" # Calculadora
        # "Microsoft.WindowsNotepad" # Bloco de Notas (versão da loja)
        # "Microsoft.Windows.Photos" # App de Fotos padrão
    )
    return $listaDeBloatware
}

function Get-Office2016KeyList {
    $listaDeChaves = @(
        "XXXXX-XXXXX-XXXXX-XXXXX-XXXXX",
        "YYYYY-YYYYY-YYYYY-YYYYY-YYYYY",
        "ZZZZZ-ZZZZZ-ZZZZZ-ZZZZZ-ZZZZZ"
        # Adicione mais chaves aquI
    )
    return $listaDeChaves
}

#================================================================================
# SEÇÃO: FUNÇÕES AUXILIARES (O "Motor" do Script)
#================================================================================

function Remove-Bloatware {
    Write-Host "`n--- Removendo Bloatware (Metodo Preciso) ---" -ForegroundColor Cyan
    $listaBloatware = Get-BloatwareAppxLista
    foreach ($packageName in $listaBloatware) {
        Write-Host " - Processando: $packageName"
        Get-AppxProvisionedPackage -Online | Where-Object { $_.PackageName -like "$packageName*" } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
        Get-AppxPackage -AllUsers -Name $packageName | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
    }
    # Remoção do OneDrive
    Write-Host " - Removendo OneDrive..."
    try { taskkill /f /im OneDrive.exe 2>$null } catch {}
    $uninstaller_x64 = "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"
    if (Test-Path $uninstaller_x64) { Start-Process $uninstaller_x64 "/uninstall /silent" -Wait }
}

# --- FUNÇÃO APRIMORADA PARA LIMPEZA PROFUNDA DE APPS INTEGRADOS ---
function DeepSystemCleanup {
    Write-Host "`n--- Iniciando Limpeza Profunda de Apps Integrados (OneDrive, Outlook, Teams) ---" -ForegroundColor Magenta
    
    # Cria uma lista para armazenar os resultados da limpeza
    $relatorioLimpeza = [System.Collections.ArrayList]@()

    # --- Remoção Agressiva do OneDrive ---
    Write-Host " - Processando OneDrive (multi-metodo)..." -ForegroundColor Yellow
    try {
        Stop-Process -Name "OneDrive" -Force -ErrorAction SilentlyContinue
        taskkill /f /im OneDrive.exe 2>$null | Out-Null
        $uninstaller_x64 = "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"
        if (Test-Path $uninstaller_x64) {
            Start-Process $uninstaller_x64 "/uninstall /silent" -Wait
        }
        Get-AppxProvisionedPackage -Online | Where-Object { $_.PackageName -like "*OneDriveSync*" } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
        Get-AppxPackage -AllUsers -Name "*OneDriveSync*" | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
        
        # Lógica de verificação para o relatório
        if (-not (Get-AppxPackage -AllUsers -Name "*OneDriveSync*") -and -not (Test-Path "$env:USERPROFILE\OneDrive")) {
            $relatorioLimpeza.Add([pscustomobject]@{ Aplicativo = 'OneDrive'; Status = 'Removido com Sucesso'; Cor = 'Green' }) | Out-Null
        } else {
            $relatorioLimpeza.Add([pscustomobject]@{ Aplicativo = 'OneDrive'; Status = 'Nao foi possivel remover completamente'; Cor = 'Yellow' }) | Out-Null
        }
    } catch { 
        $relatorioLimpeza.Add([pscustomobject]@{ Aplicativo = 'OneDrive'; Status = "Erro durante a remocao: $($_.Exception.Message)"; Cor = 'Red' }) | Out-Null
    }

    # --- Remoção Agressiva do Novo Outlook ---
    Write-Host " - Processando Novo Outlook (AppX)..." -ForegroundColor Yellow
    $appName = "*OutlookForWindows*"
    Get-AppxProvisionedPackage -Online | Where-Object { $_.PackageName -like $appName } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
    Get-AppxPackage -AllUsers -Name $appName | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
    
    # Lógica de verificação
    if (-not (Get-AppxPackage -AllUsers -Name $appName)) {
        $relatorioLimpeza.Add([pscustomobject]@{ Aplicativo = 'Novo Outlook'; Status = 'Removido com Sucesso'; Cor = 'Green' }) | Out-Null
    } else {
        $relatorioLimpeza.Add([pscustomobject]@{ Aplicativo = 'Novo Outlook'; Status = 'Nao foi possivel remover'; Cor = 'Yellow' }) | Out-Null
    }

    # --- Remoção Agressiva do Teams Pessoal ---
    Write-Host " - Processando Teams para uso pessoal (AppX)..." -ForegroundColor Yellow
    $appName = "*MSTeams*"
    Get-AppxProvisionedPackage -Online | Where-Object { $_.PackageName -like $appName } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
    Get-AppxPackage -AllUsers -Name $appName | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
    
    # Lógica de verificação
    if (-not (Get-AppxPackage -AllUsers -Name $appName)) {
        $relatorioLimpeza.Add([pscustomobject]@{ Aplicativo = 'Teams Pessoal'; Status = 'Removido com Sucesso'; Cor = 'Green' }) | Out-Null
    } else {
        $relatorioLimpeza.Add([pscustomobject]@{ Aplicativo = 'Teams Pessoal'; Status = 'Nao foi possivel remover'; Cor = 'Yellow' }) | Out-Null
    }
    
    # --- CONFIRMAÇÃO FINAL E PAUSA ---
    Write-Host "`n------------------------------------------------------------"
    Write-Host "--- Relatorio Final da Limpeza Profunda ---" -ForegroundColor Cyan
    
    # Exibe o relatório formatado e colorido
    foreach ($item in $relatorioLimpeza) {
        Write-Host ("- {0,-15}: {1}" -f $item.Aplicativo, $item.Status) -ForegroundColor $item.Cor
    }
    
    Write-Host "------------------------------------------------------------"
    
    Write-Host "`nLimpeza Profunda concluida..."
}

# ---- FUNÇÃO PARA REMOVER VERSÕES DO MICROSOFT 365 E ONE NOTE (pt-br/es-es/fr-fr/en-us) -------
function Remove-OfficeC2R {
    Write-Host "`n--- Removendo Office Click-to-Run ---" -ForegroundColor Cyan
    $odtPath = Join-Path -Path $PSScriptRoot -ChildPath "ODT"
    $setupExe = Join-Path -Path $odtPath -ChildPath "setup.exe"
    $configFile = Join-Path -Path $odtPath -ChildPath "uninstall.xml"
    if (-not (Test-Path $setupExe) -or -not (Test-Path $configFile)) {
        Write-Warning "Ferramenta ODT não encontrada. Pulando esta etapa."
        return
    }
    Start-Process -FilePath $setupExe -ArgumentList "/configure `"$configFile`"" -Wait
}

function Install-Software {
    Write-Host "`n--- Instalando Programas Padrao (Modo Automatico) ---" -ForegroundColor Cyan
    $programasWinget = Get-ProgramasPadraoWinget
    $programasExecutavel = Get-ProgramasPadraoExecutavel
    
    # Instala todos programas da lista Winget
    foreach ($programa in $programasWinget.GetEnumerator()) {
        Write-Host "Instalando $($programa.Name) via Winget..." -ForegroundColor Green
        winget install --id $programa.Value -e --accept-source-agreements --accept-package-agreements --silent
    }
    
    # Instala todos os programas com instalador Local na pasta "Instaladores"
    foreach ($programa in $programasExecutavel) {
        $caminhoCompleto = Join-Path -Path $Global:caminhoDosExecutaveis -ChildPath $programa.Arquivo
        if (Test-Path $caminhoCompleto) {
            if ([string]::IsNullOrWhiteSpace($programa.Argumentos)) {
                Write-Host "ABRINDO INSTALADOR MANUAL para $($programa.Nome)..." -ForegroundColor Yellow
                Start-Process -FilePath $caminhoCompleto -Wait
                Write-Host "Instalacao de $($programa.Nome) finalizada. Pressione Enter para continuar..."
                Read-Host
            } else {
                Write-Host "Instalando silenciosamente $($programa.Nome)..." -ForegroundColor Green
                Start-Process -FilePath $caminhoCompleto -ArgumentList $programa.Argumentos -Wait
            }
        } else { Write-Warning "Instalador para $($programa.Nome) nao encontrado." }
    }
}


# ---- INSTALA O OFFICE 2016 DE FORMA SILENCIOSA
function Install-Office2016 {
    Write-Host "`n--- Instalando Office 2016 Standard ---" -ForegroundColor Cyan
    $officePath = Join-Path -Path $Global:caminhoDosExecutaveis -ChildPath "Office 2016 Standard"
    $setupFile = Join-Path -Path $officePath -ChildPath "setup.exe"
    $configFile = Join-Path -Path $officePath -ChildPath "config.xml"
    if (-not (Test-Path $setupFile) -or -not (Test-Path $configFile)) {
        Write-Warning "Arquivos de instalacao do Office 2016 nao encontrados. Pulando."
        return
    }
    Write-Host "Instalando... Por favor, aguarde." -ForegroundColor Yellow
    Start-Process -FilePath $setupFile -ArgumentList "/config `"$configFile`"" -Wait
}

function Get-OfficePath {
    $path_x64 = "$env:ProgramFiles\Microsoft Office\Office16"
    $path_x86 = "${env:ProgramFiles(x86)}\Microsoft Office\Office16"
    
    if (Test-Path -Path "$path_x64\OSPP.VBS") {
        return $path_x64
    } elseif (Test-Path -Path "$path_x86\OSPP.VBS") {
        return $path_x86
    } else {
        return $null
    }
}

# ---- ATIVA O OFFICE 2016 DE FORMA AUTOMÁTICA COM BASE NA LISTA DE CHAVES PREENCHIDA NO INÍCIO
function Invoke-Office2016Activation {
    Write-Host "`n--- Ativando o Office 2016 (Modo Automatico) ---" -ForegroundColor Cyan
    $officePath = Get-OfficePath
    if (-not $officePath) { Write-Warning "Pasta do Office nao encontrada para ativacao."; return }
    $listaDeChaves = Get-Office2016KeyList
    if ($listaDeChaves.Count -eq 0) { Write-Warning "Nenhuma chave do Office na lista. Pulando ativacao."; return }
    
    $chavesParaTestar = [System.Collections.ArrayList]$listaDeChaves
    $ativacaoBemSucedida = $false
    Push-Location -Path $officePath
    while ($chavesParaTestar.Count -gt 0 -and !$ativacaoBemSucedida) {
        $chaveAleatoria = $chavesParaTestar | Get-Random
        Write-Host "Tentando com a chave que termina em: $($chaveAleatoria.Substring($chaveAleatoria.Length - 5))"
        cscript.exe OSPP.VBS /inpkey:$chaveAleatoria | Out-Null
        $resultado = cscript.exe OSPP.VBS /act
        if ($resultado -join ' ' -match "Product activation successful|Ativacao do produto bem-sucedida") {
            Write-Host "SUCESSO! O Office foi ativado." -ForegroundColor Green
            $ativacaoBemSucedida = $true
        } else {
            Write-Host "FALHA. Tentando a proxima..." -ForegroundColor Red
            $chavesParaTestar.Remove($chaveAleatoria)
        }
    }
    Pop-Location
    if (-not $ativacaoBemSucedida) { Write-Error "Nenhuma chave da lista funcionou." }
}


# ----- FUNÇÃO PARA DEFINIR UM HOSTNAME PARA A MÁQUINA
function Set-Hostname-Auto {
    param($NewName)
    Write-Host "`n--- Alterando Hostname para '$NewName' ---" -ForegroundColor Cyan
    Rename-Computer -NewName $NewName -Force
}

# ---- FUNÇÃO PARA INGRESSAR EM UM DOMÍNIO
function Join-Domain-Auto {
    param($DomainName, $Credential)
    Write-Host "`n--- Ingressando no dominio '$DomainName' ---" -ForegroundColor Cyan
    Add-Computer -DomainName $DomainName -Credential $credential -Force
}

#================================================================================
# SEÇÃO: LÓGICA DE EXECUÇÃO AUTOMATIZADA
#================================================================================

# ----- CONFIGURANDO A PERSISTÊNCIA
$persistenceRegPath = "HKLM:\SOFTWARE\MyScriptSetup"
$runOnceRegPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"

switch ($Stage) {
    "1" {
        Write-Host "========== INICIANDO ETAPA 1 DE 3: LIMPEZA E INSTALAÇÃO ==========" -ForegroundColor Green
        
	# ---- VARIÁVEL GLOBAL QUE ARMAZENA O CAMINHO DA PASTA INSTALADORES
        $Global:caminhoDosExecutaveis = Join-Path -Path $PSScriptRoot -ChildPath "Instaladores"
        
        if (-not (Test-Path $Global:caminhoDosExecutaveis -PathType Container)) {
            Write-Error "ERRO FATAL: A pasta 'Instaladores' nao foi encontrada em '$($Global:caminhoDosExecutaveis)'."
            Write-Error "Por favor, crie a pasta e coloque os arquivos de instalacao nela antes de executar novamente."
            Read-Host "Pressione Enter para encerrar."
            Stop-Transcript
            exit
        }
        Write-Host "Pasta 'Instaladores' encontrada com sucesso: $($Global:caminhoDosExecutaveis)" -ForegroundColor Green
        Start-Sleep -Seconds 3

        if (Test-Path $persistenceRegPath) { Remove-Item -Path $persistenceRegPath -Recurse -Force }
        New-Item -Path $persistenceRegPath -Force | Out-Null
        New-ItemProperty -Path $persistenceRegPath -Name "InstallerPath" -Value $Global:caminhoDosExecutaveis -Force | Out-Null

        Remove-Bloatware
        DeepSystemCleanup
        Remove-OfficeC2R
        Install-Software
        Install-Office2016
        Invoke-Office2016Activation

        $newHostname = Read-Host "`nTAREFA FINAL DA ETAPA 1: Digite o novo nome para o computador"
        
        Write-Host "Configurando o script para continuar automaticamente apos a reinicializacao..." -ForegroundColor Yellow
        $scriptPath = $MyInvocation.MyCommand.Path
        $command = "powershell.exe -ExecutionPolicy Bypass -File `"$scriptPath`" -Stage 2"
        New-ItemProperty -Path $runOnceRegPath -Name "MyScriptSetupStage2" -Value $command -Force | Out-Null
        
        Set-Hostname-Auto -NewName $newHostname

        Write-Host "ETAPA 1 CONCLUIDA. O computador sera reiniciado em 10 segundos." -ForegroundColor Green
        Start-Sleep -Seconds 10
        Restart-Computer -Force
    }
    "2" {
        Write-Host "========== INICIANDO ETAPA 2 DE 3: INGRESSO NO DOMÍNIO ==========" -ForegroundColor Green
        
        $installerPath = (Get-ItemProperty -Path $persistenceRegPath).InstallerPath
        $Global:caminhoDosExecutaveis = $installerPath
        
        $domainName = Read-Host "`nTAREFA DA ETAPA 2: Digite o nome do dominio para ingressar (ex: suaempresa.local)"
        $credential = Get-Credential -UserName "$domainName\" -Message "Digite as credenciais com permissao para ingressar"

        Write-Host "Configurando o script para finalizar apos a proxima reinicializacao..." -ForegroundColor Yellow
        $scriptPath = $MyInvocation.MyCommand.Path
        $command = "powershell.exe -ExecutionPolicy Bypass -File `"$scriptPath`" -Stage 3"
        New-ItemProperty -Path $runOnceRegPath -Name "MyScriptSetupStage3" -Value $command -Force | Out-Null

        Join-Domain-Auto -DomainName $domainName -Credential $credential
        
        Write-Host "ETAPA 2 CONCLUIDA. O computador sera reiniciado em 10 segundos." -ForegroundColor Green
        Start-Sleep -Seconds 10
        Restart-Computer -Force
    }
    "3" {
        Write-Host "========== INICIANDO ETAPA 3 DE 3: FINALIZAÇÃO ==========" -ForegroundColor Green
        
        Write-Host "Limpando registros de automacao..." -ForegroundColor Yellow
        if (Test-Path $persistenceRegPath) {
            Remove-Item -Path $persistenceRegPath -Recurse -Force
        }
        
        Write-Host "SETUP AUTOMATIZADO CONCLUIDO COM SUCESSO!" -ForegroundColor Cyan
        Write-Host "O computador esta pronto para uso."
        Stop-Transcript
        # Remove a si mesmo do RunOnce como uma garantia extra (embora o RunOnce seja auto-destrutivo)
        Remove-ItemProperty -Path $runOnceRegPath -Name "MyScriptSetupStage3" -ErrorAction SilentlyContinue
        Read-Host "Pressione Enter para fechar esta janela."
    }
}