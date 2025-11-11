# 💻 Setup Automatizado — Instalação Padrão de Máquinas

## 🧩 Visão Geral

Este projeto foi criado para **automatizar o processo de configuração e padronização de novas máquinas** na empresa.  
Através de scripts em **PowerShell** e **Batch**, o sistema executa automaticamente a instalação de softwares essenciais, aplica configurações padrão e ativa o Office 2016 utilizando códigos de licença válidos.

O principal objetivo é **reduzir o tempo de setup** de novas estações de trabalho, garantindo que todas fiquem **padronizadas, funcionais e prontas para uso** em poucos minutos.

---

## ⚙️ Estrutura do Repositório

A estrutura de pastas deve ser **mantida exatamente como descrita abaixo**, pois os scripts dependem desses caminhos fixos.  
A **alteração dos nomes** pode causar falhas na execução automática.

📦 Setup-Automatizado
├── iniciar_setup.bat
├── setup_automatizado.ps1
├── 📁 ODT
│ ├── configuration.xml
│ └── setup.exe
├── 📁 Instaladores
│ ├── 7zip.exe
│ ├── GoogleDriveSetup.exe
│ ├── Office2016
│ │ ├── setup.exe
│ │ └── configuration.xml
│ └── outros_instaladores...
└── 📁 Logs
└── (gerados automaticamente após cada execução)

## 🧩 Funções Principais

### 🧩 Função 1 — Verificação de Permissões
Garante que o script está sendo executado como **Administrador**.  
Caso contrário, ele se **reinicia com privilégios elevados** automaticamente para evitar falhas durante as instalações.

---

### 🧩 Função 2 — Criação e Organização de Logs
O script gera **logs automáticos** com data e hora, armazenados na pasta `Logs`.  
Exemplo:
Logs/Setup_2025-11-11_13-45.log

Esses logs permitem **auditar e rastrear** todo o processo de execução, identificando possíveis erros ou falhas de instalação.

---

### 🧩 Função 3 — Instalação de Programas
O script executa silenciosamente os instaladores localizados na pasta `Instaladores`.

Cada instalador pode ser **adicionado ou removido** conforme a necessidade.  
O formato padrão de execução é o seguinte:

```powershell
Start-Process "$PSScriptRoot\Instaladores\ChromeSetup.exe" -ArgumentList "/silent" -Wait
```
💡 Dica:
Para adicionar novos programas, basta incluir o instalador na pasta Instaladores e criar uma nova linha semelhante no script.

--- 

### 🧩 Função 4 — Instalação e Ativação do Office 2016
A pasta ODT contém o Office Deployment Tool, responsável pela instalação personalizada do Microsoft Office 2016.

O arquivo configuration.xml define:
* A edição do Office (Professional, Standard etc.);
* O idioma da instalação;
* Os componentes que serão incluídos.

Após a instalação, o script executa a ativação automática do Office utilizando a chave de produto configurada.

🧱 **Exemplo de Ativação:**
$OfficePath = "C:\Program Files\Microsoft Office\Office16"
cd $OfficePath
cscript ospp.vbs /inpkey:XXXXX-XXXXX-XXXXX-XXXXX-XXXXX
cscript ospp.vbs /act

📍 **Onde colocar o código de ativação?**
No arquivo setup_automatizado.ps1, procure o trecho:
 *====== INSIRA O CÓDIGO DE ATIVAÇÃO DO OFFICE AQUI ======*
Substitua o campo: XXXXX-XXXXX-XXXXX-XXXXX-XXXXX, pelo seu código de licença válido.

🧱 ***Regras Importantes***

⚠️ **Não renomeie as pastas principais**
ODT, Instaladores e Logs
Os caminhos dessas pastas são **referenciados diretamente no script**. Qualquer alteração de nome **impedirá a execução correta**.

⚠️ **Execute sempre como Administrador**
A instalação de softwares e a ativação do Office exigem permissões elevadas.

⚠️ **Mantenha a estrutura de diretórios**
Todos os arquivos devem estar no mesmo nível do script setup_automatizado.ps1.

📁 **Atualize os instaladores periodicamente**
Você pode substituir os arquivos antigos na pasta Instaladores por versões mais recentes dos programas.

### 🧾 Resultado Final

Após a execução completa do script:

✅ Todos os programas essenciais serão instalados.
✅ O Office 2016 será instalado e ativado automaticamente.
✅ Logs detalhados serão gerados em /Logs.
✅ A máquina estará padronizada, pronta para uso e configurada conforme o padrão corporativo.

💡 Benefícios:

- Instalação padronizada e automática
- Economia de tempo em setups de novas máquinas
- Redução de erros manuais
- Registro completo de logs
- Facilidade de manutenção e atualização
- Personalização

*O script pode ser editado de acordo com as necessidades da empresa*

- Adicionar novos softwares à lista de instalação;
- Alterar parâmetros de instalação silenciosa (/silent, /quiet, etc.);
- Modificar o comportamento de geração de logs;
- Adaptar o processo de ativação para versões futuras do Office (2019, 2021, 365, etc).

💡 Dica:
Sempre teste suas modificações em ambiente controlado antes de aplicar em produção.

### 🪪 Autor e Licença
Autor: André Fanelli
Licença: MIT
Sinta-se à vontade para clonar, modificar e contribuir com melhorias neste projeto.
