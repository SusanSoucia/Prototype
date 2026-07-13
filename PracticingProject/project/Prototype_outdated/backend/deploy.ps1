<#
.SYNOPSIS
    Group45 Backend — 傻瓜式部署脚本 (Windows PowerShell)
.DESCRIPTION
    一键部署 Group45 后端服务，自动检测环境、配置、编译、启动。
.PARAMETER Command
    可选命令: build, start, start-bg, stop, status, check, help
.EXAMPLE
    .\deploy.ps1              # 交互式引导部署
    .\deploy.ps1 infra-up     # 一键启动 Docker 基础设施
    .\deploy.ps1 infra-down   # 停止/销毁 Docker 基础设施
    .\deploy.ps1 build        # 只编译
    .\deploy.ps1 start        # 编译 + 前台启动
    .\deploy.ps1 start-bg     # 编译 + 后台启动
    .\deploy.ps1 stop         # 停止后台进程
    .\deploy.ps1 status       # 查看服务状态
    .\deploy.ps1 check        # 只检测环境
.NOTES
    前置依赖:
      - Docker Desktop    (运行 infra-up 时必需)
      - JDK 17+           https://adoptium.net
      - Maven 3.9+        https://maven.apache.org
      - LiteParse (可选)  PDF 解析工具
#>

param(
    [Parameter(Position = 0)]
    [ValidateSet("infra-up", "infra-down", "infra-status", "build", "start", "start-bg", "stop", "status", "check", "help")]
    [string]$Command = ""
)

# ============================== 错误处理 =====================================
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# ============================== 路径定义 =====================================
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$BackendDir = $ScriptDir
$EnvFile = Join-Path $BackendDir ".env"
$EnvExample = Join-Path $BackendDir ".env.example"
$PidDir = Join-Path $BackendDir ".runtime\pids"
$LogDir = Join-Path $BackendDir "logs"
$PidFile = Join-Path $PidDir "app.pid"
$AppLog = Join-Path $LogDir "app.log"
$LastBuildFile = Join-Path $BackendDir ".runtime\last-build.txt"
$ComposeFile = Join-Path $BackendDir "..\docs\docker-compose.yaml"

# ============================== 辅助函数 =====================================
function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Blue
}

function Write-Ok {
    param([string]$Message)
    Write-Host "    [OK] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "    [WARN] $Message" -ForegroundColor Yellow
}

function Write-Err {
    param([string]$Message)
    Write-Host "    [ERROR] $Message" -ForegroundColor Red
}

function Write-Tip {
    param([string]$Message)
    Write-Host "    [TIP] $Message" -ForegroundColor Cyan
}

function Write-Banner {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "  Group45 Backend — 部署脚本 (Windows)" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Test-Port {
    param([string]$Hostname, [int]$Port, [int]$TimeoutMs = 2000)

    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $result = $tcp.BeginConnect($Hostname, $Port, $null, $null)
        $wait = $result.AsyncWaitHandle.WaitOne($TimeoutMs, $false)
        if ($wait) {
            $tcp.EndConnect($result)
            $tcp.Close()
            return $true
        }
        $tcp.Close()
        return $false
    }
    catch {
        return $false
    }
}

# ============================== 环境检测 =====================================
function Check-Java {
    Write-Step "检测 Java 环境..."

    try {
        $javaOutput = java -version 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) {
            throw "java 命令执行失败"
        }

        # 提取主版本号
        if ($javaOutput -match 'version "(\d+)') {
            $majorVersion = [int]$Matches[1]
        }
        elseif ($javaOutput -match 'version "1\.(\d+)') {
            $majorVersion = [int]$Matches[1]
        }
        else {
            $majorVersion = 0
        }

        Write-Ok "Java 已安装 (主版本: $majorVersion)"

        if ($majorVersion -lt 17) {
            Write-Err "Java 版本过低 ($majorVersion)，需要 JDK 17+"
            Write-Host ""
            Write-Host "  请从 https://adoptium.net 下载安装 JDK 17+"
            Write-Host ""
            exit 1
        }
    }
    catch {
        Write-Err "未找到 java 命令，请先安装 JDK 17+"
        Write-Host ""
        Write-Host "  推荐从 https://adoptium.net 下载安装"
        Write-Host "  安装后需要重启终端或添加到系统 PATH"
        Write-Host ""
        exit 1
    }
}

function Check-Maven {
    Write-Step "检测 Maven 环境..."

    # 优先使用项目自带的 mvnw.cmd
    $mvnwCmd = Join-Path $BackendDir "mvnw.cmd"
    if (Test-Path $mvnwCmd) {
        $script:MVN_CMD = $mvnwCmd
        Write-Ok "使用项目自带的 Maven Wrapper (mvnw.cmd)"
        return
    }

    try {
        $mvnOutput = mvn --version 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) {
            throw "mvn 命令执行失败"
        }
        $script:MVN_CMD = "mvn"
        Write-Ok "Maven 已安装: $($mvnOutput.Split([Environment]::NewLine)[0])"
    }
    catch {
        Write-Err "未找到 mvn 命令，请先安装 Maven 3.9+"
        Write-Host ""
        Write-Host "  从 https://maven.apache.org/download.cgi 下载"
        Write-Host "  解压后将 bin 目录添加到系统 PATH 环境变量"
        Write-Host ""
        exit 1
    }
}

function Check-EnvFile {
    Write-Step "检查配置文件..."

    if (Test-Path $EnvFile) {
        Write-Ok ".env 文件已存在"
    }
    else {
        Write-Warn ".env 文件不存在，正在从 .env.example 复制..."
        Copy-Item $EnvExample $EnvFile
        Write-Ok "已创建 .env 文件"
        Write-Host ""
        Write-Host "  !!! 重要：请先编辑 .env 文件，填入真实的配置信息 !!!" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  必须修改的核心配置项:" -ForegroundColor White
        Write-Host "  - DEEPSEEK_API_KEY          (LLM API Key)" -ForegroundColor Cyan
        Write-Host "  - EMBEDDING_API_KEY         (向量服务 API Key)" -ForegroundColor Cyan
        Write-Host "  - SPRING_DATASOURCE_PASSWORD (MySQL 密码)" -ForegroundColor Cyan
        Write-Host "  - ELASTICSEARCH_PASSWORD     (ES 密码)" -ForegroundColor Cyan
        Write-Host ""

        $answer = Read-Host "  是否现在用记事本打开 .env 文件？(y/n)"
        if ($answer -eq "y" -or $answer -eq "Y") {
            notepad $EnvFile
        }
        else {
            Write-Host ""
            Write-Warn "请手动编辑 $EnvFile 后再运行部署"
        }
    }
}

function Load-EnvFile {
    # 解析 .env 文件为环境变量（简单实现）
    if (-not (Test-Path $EnvFile)) { return }

    Get-Content $EnvFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith("#")) {
            if ($line -match '^\s*([^=]+)=(.*)') {
                $key = $Matches[1].Trim()
                $value = $Matches[2].Trim()
                # 去掉可能的引号
                $value = $value -replace '^["'']|["'']$', ''
                [Environment]::SetEnvironmentVariable($key, $value, "Process")
            }
        }
    }
}

function Check-Infrastructure {
    Write-Step "检测基础设施连接..."

    Load-EnvFile

    # MySQL
    $mysqlUrl = [Environment]::GetEnvironmentVariable("SPRING_DATASOURCE_URL", "Process")
    if ($mysqlUrl -match '(?:jdbc:)?mysql://([^:/]+):?(\d+)?') {
        $mysqlHost = $Matches[1]
        $mysqlPort = if ($Matches[2]) { [int]$Matches[2] } else { 3306 }
    }
    else {
        $mysqlHost = "localhost"
        $mysqlPort = 3306
    }
    if (Test-Port $mysqlHost $mysqlPort) {
        Write-Ok "MySQL 可达 (${mysqlHost}:${mysqlPort})"
    }
    else {
        Write-Warn "MySQL 不可达 (${mysqlHost}:${mysqlPort})，请确认服务已启动"
    }

    # Redis
    $redisHost = [Environment]::GetEnvironmentVariable("SPRING_DATA_REDIS_HOST", "Process")
    if (-not $redisHost) { $redisHost = "localhost" }
    $redisPortStr = [Environment]::GetEnvironmentVariable("SPRING_DATA_REDIS_PORT", "Process")
    $redisPort = if ($redisPortStr) { [int]$redisPortStr } else { 6379 }
    if (Test-Port $redisHost $redisPort) {
        Write-Ok "Redis 可达 (${redisHost}:${redisPort})"
    }
    else {
        Write-Warn "Redis 不可达 (${redisHost}:${redisPort})，请确认服务已启动"
    }

    # Elasticsearch
    $esHost = [Environment]::GetEnvironmentVariable("ELASTICSEARCH_HOST", "Process")
    if (-not $esHost) { $esHost = "localhost" }
    $esPortStr = [Environment]::GetEnvironmentVariable("ELASTICSEARCH_PORT", "Process")
    $esPort = if ($esPortStr) { [int]$esPortStr } else { 9200 }
    if (Test-Port $esHost $esPort) {
        Write-Ok "Elasticsearch 可达 (${esHost}:${esPort})"
    }
    else {
        Write-Warn "Elasticsearch 不可达 (${esHost}:${esPort})，请确认服务已启动"
    }

    # Kafka
    $kafkaServer = [Environment]::GetEnvironmentVariable("SPRING_KAFKA_BOOTSTRAP_SERVERS", "Process")
    if (-not $kafkaServer) { $kafkaServer = "127.0.0.1:9092" }
    $kafkaParts = $kafkaServer -split ":"
    $kafkaHost = $kafkaParts[0]
    $kafkaPort = if ($kafkaParts.Length -gt 1) { [int]$kafkaParts[1] } else { 9092 }
    if (Test-Port $kafkaHost $kafkaPort) {
        Write-Ok "Kafka 可达 (${kafkaServer})"
    }
    else {
        Write-Warn "Kafka 不可达 (${kafkaServer})，请确认服务已启动"
    }

    # MinIO
    $minioUrl = [Environment]::GetEnvironmentVariable("MINIO_ENDPOINT", "Process")
    if (-not $minioUrl) { $minioUrl = "http://localhost:9000" }
    if ($minioUrl -match '://([^:/]+):?(\d+)?') {
        $minioHost = $Matches[1]
        $minioPort = if ($Matches[2]) { [int]$Matches[2] } else { 9000 }
    }
    else {
        $minioHost = "localhost"
        $minioPort = 9000
    }
    if (Test-Port $minioHost $minioPort) {
        Write-Ok "MinIO 可达 (${minioHost}:${minioPort})"
    }
    else {
        Write-Warn "MinIO 不可达 (${minioHost}:${minioPort})，请确认服务已启动"
    }
}

function Check-LiteParse {
    Write-Step "检测 LiteParse (PDF 解析工具)..."

    try {
        $litOutput = lit --help 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0) {
            Write-Ok "lit 命令可用: $(Get-Command lit | Select-Object -ExpandProperty Source)"
            return
        }
    }
    catch { }

    try {
        $liteOutput = lite --help 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0) {
            Write-Ok "lite 命令可用: $(Get-Command lite | Select-Object -ExpandProperty Source)"
            return
        }
    }
    catch { }

    Write-Warn "LiteParse 未安装（PDF 解析功能将不可用）"
    Write-Tip "安装方法: pip install 'mineru[core]' 详见 https://github.com/opendatalab/MinerU"
}

# ============================== Docker 基础设施 ===============================
function Check-Docker {
    $dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
    if (-not $dockerCmd) {
        Write-Err "未找到 Docker，请先安装 Docker Desktop"
        Write-Host ""
        Write-Host "  下载地址: https://www.docker.com/products/docker-desktop"
        Write-Host "  安装后需要重启终端"
        Write-Host ""
        exit 1
    }

    try {
        docker info 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Docker 未运行"
        }
    }
    catch {
        Write-Err "Docker 未运行，请先启动 Docker Desktop"
        exit 1
    }

    Write-Ok "Docker 已就绪"
}

function Invoke-InfraUp {
    Write-Banner
    Write-Step "一键启动 Docker 基础设施..."

    Check-Docker

    $composePath = Resolve-Path $ComposeFile -ErrorAction SilentlyContinue
    if (-not $composePath) {
        Write-Err "找不到 docker-compose 文件: $ComposeFile"
        exit 1
    }

    Write-Ok "使用配置: $ComposeFile"
    Write-Host ""
    Write-Host "  即将启动以下服务:"
    Write-Host "  - MySQL 8.0       (端口 3306, root/prototype2025, 库 prototype_db)"
    Write-Host "  - Redis 7          (端口 6379, 密码 prototype2025)"
    Write-Host "  - Kafka (KRaft)    (端口 9092, 无需 ZooKeeper)"
    Write-Host "  - Elasticsearch 8  (端口 9200, elastic/prototype2025, HTTP 无 SSL)"
    Write-Host "  - MinIO            (端口 9000/9001, minioadmin/minioadmin)"
    Write-Host ""

    $composeDir = Split-Path -Parent $composePath
    $composeFileName = Split-Path -Leaf $composePath
    Push-Location $composeDir
    try {
        docker compose -f $composeFileName up -d

        Write-Host ""
        Write-Step "等待所有容器健康检查通过..."

        $waited = 0
        $maxWait = 120
        while ($waited -lt $maxWait) {
            $psOutput = docker compose -f $composeFileName ps --format json 2>&1 | Out-String
            if (-not $psOutput) {
                Start-Sleep -Seconds 2
                $waited += 2
                continue
            }

            $allHealthy = $true
            $lines = $psOutput -split "`n" | Where-Object { $_.Trim() }
            foreach ($line in $lines) {
                try {
                    $obj = $line | ConvertFrom-Json
                    if ($obj.Health -ne "healthy" -and $obj.Name -ne "prototype-minio-init") {
                        $allHealthy = $false
                    }
                }
                catch { }
            }

            if ($allHealthy) {
                Write-Host ""
                Write-Ok "所有基础设施已就绪！"
                Write-Host ""
                Invoke-InfraStatus
                Write-Host ""
                Write-Tip "现在可以运行: .\deploy.ps1 start-bg"
                return
            }

            Start-Sleep -Seconds 3
            $waited += 3
            Write-Host "." -NoNewline
        }

        Write-Host ""
        Write-Warn "等待超时，请手动检查: docker compose -f $ComposeFile ps"
        Write-Tip "部分服务可能仍在初始化中（首次拉取镜像较慢），稍后会自动就绪"
    }
    finally {
        Pop-Location
    }
}

function Invoke-InfraDown {
    Write-Step "停止 Docker 基础设施..."

    Check-Docker

    $composePath = Resolve-Path $ComposeFile -ErrorAction SilentlyContinue
    if (-not $composePath) {
        Write-Err "找不到 docker-compose 文件: $ComposeFile"
        exit 1
    }

    $composeDir = Split-Path -Parent $composePath
    $composeFileName = Split-Path -Leaf $composePath
    Push-Location $composeDir
    try {
        Write-Host ""
        Write-Host "  选择操作:"
        Write-Host "  1) 停止容器（保留数据卷，下次 infra-up 恢复数据）"
        Write-Host "  2) 停止并销毁（删除所有数据卷，不可恢复！）"
        Write-Host ""
        $choice = Read-Host "  请输入选项 (1/2) [默认: 1]"
        if (-not $choice) { $choice = "1" }

        switch ($choice) {
            "1" {
                docker compose -f $composeFileName stop
                Write-Ok "容器已停止，数据卷保留"
            }
            "2" {
                $confirm = Read-Host "  确认删除所有数据？输入 yes 继续"
                if ($confirm -eq "yes") {
                    docker compose -f $composeFileName down -v
                    Write-Ok "容器已销毁，数据卷已删除"
                }
                else {
                    Write-Warn "已取消"
                }
            }
            default { Write-Err "无效选项" }
        }
    }
    finally {
        Pop-Location
    }
}

function Invoke-InfraStatus {
    Write-Step "Docker 基础设施状态..."

    Check-Docker

    $composePath = Resolve-Path $ComposeFile -ErrorAction SilentlyContinue
    if (-not $composePath) {
        Write-Err "找不到 docker-compose 文件: $ComposeFile"
        return
    }

    $composeDir = Split-Path -Parent $composePath
    $composeFileName = Split-Path -Leaf $composePath
    Push-Location $composeDir
    try {
        Write-Host ""
        docker compose -f $composeFileName ps 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Warn "没有运行中的容器，请先执行 infra-up"
        }
    }
    finally {
        Pop-Location
    }
}

# ============================== 编译 =========================================
function Invoke-Build {
    Write-Step "开始编译项目 (Maven)..."

    Push-Location $BackendDir
    try {
        $mavenOpts = @("clean", "package")
        $skipTests = [Environment]::GetEnvironmentVariable("SKIP_TESTS", "Process")
        if ($skipTests -ne "false") {
            $mavenOpts += "-DskipTests"
            Write-Tip "跳过单元测试 (设置 `$env:SKIP_TESTS='false' 可启用)"
        }

        $mvnOutput = & $script:MVN_CMD @mavenOpts 2>&1 | Out-String
        $mvnExitCode = $LASTEXITCODE

        if ($mvnExitCode -eq 0) {
            Write-Ok "编译成功"

            # 找到生成的 jar 包
            $jarFile = Get-ChildItem (Join-Path $BackendDir "target") -Filter "*.jar" |
                Where-Object { $_.Name -notmatch "sources|javadoc" } |
                Select-Object -First 1

            if ($jarFile) {
                Write-Ok "产物: $($jarFile.Name)"
                $jarFile.FullName | Out-File -FilePath $LastBuildFile -Encoding utf8
            }
        }
        else {
            Write-Err "编译失败 (退出码: $mvnExitCode)！以下是最近错误信息："
            # 输出 Maven 日志的最后错误行
            $errorLines = ($mvnOutput -split "`n" | Where-Object { $_ -match "ERROR|FAILURE|BUILD FAILURE" })
            if ($errorLines) {
                Write-Host ""
                $errorLines | Select-Object -Last 15 | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
            }
            exit 1
        }
    }
    finally {
        Pop-Location
    }
}

# ============================== 启动 =========================================
function Start-App {
    param([string]$Mode = "foreground")

    Write-Step "启动应用..."

    Push-Location $BackendDir

    # 确保运行时目录存在
    if (-not (Test-Path $PidDir)) { New-Item -ItemType Directory -Force -Path $PidDir | Out-Null }
    if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Force -Path $LogDir | Out-Null }

    # 检查是否已在运行
    if (Test-Path $PidFile) {
        $oldPid = Get-Content $PidFile -Raw
        $proc = Get-Process -Id $oldPid -ErrorAction SilentlyContinue
        if ($proc) {
            Write-Warn "应用已在运行中 (PID: $oldPid)"
            $answer = Read-Host "  是否重启？(y/n)"
            if ($answer -eq "y" -or $answer -eq "Y") {
                Stop-App
            }
            else {
                Pop-Location
                return
            }
        }
        else {
            Remove-Item $PidFile -Force
        }
    }

    Load-EnvFile

    # 确定 JAR 文件
    $jarFile = $null
    if (Test-Path $LastBuildFile) {
        $cachedJar = Get-Content $LastBuildFile -Raw
        if (Test-Path $cachedJar.Trim()) {
            $jarFile = $cachedJar.Trim()
        }
    }
    if (-not $jarFile) {
        $jarFile = Get-ChildItem (Join-Path $BackendDir "target") -Filter "*.jar" |
            Where-Object { $_.Name -notmatch "sources|javadoc" } |
            Select-Object -First 1
        if ($jarFile) { $jarFile = $jarFile.FullName }
    }

    if (-not $jarFile) {
        Write-Err "未找到 JAR 文件，请先执行 build"
        Pop-Location
        exit 1
    }

    $port = [Environment]::GetEnvironmentVariable("SERVER_PORT", "Process")
    if (-not $port) { $port = "8081" }
    $profile = [Environment]::GetEnvironmentVariable("SPRING_PROFILES_ACTIVE", "Process")
    if (-not $profile) { $profile = "dev" }

    Write-Host ""
    Write-Host "  启动配置:"
    Write-Host "  JAR      : $(Split-Path $jarFile -Leaf)"
    Write-Host "  端口     : $port"
    Write-Host "  Profile  : $profile"
    Write-Host ""

    if ($Mode -eq "background") {
        # 创建一个后台运行的进程
        $procInfo = New-Object System.Diagnostics.ProcessStartInfo
        $procInfo.FileName = "java"
        $procInfo.Arguments = "-jar `"$jarFile`" --spring.profiles.active=$profile"
        $procInfo.UseShellExecute = $false
        $procInfo.RedirectStandardOutput = $true
        $procInfo.RedirectStandardError = $true
        $procInfo.WorkingDirectory = $BackendDir

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $procInfo
        $process.Start() | Out-Null

        # 保存 PID
        $process.Id | Out-File -FilePath $PidFile -Encoding utf8

        Write-Ok "应用已在后台启动 (PID: $($process.Id))"
        Write-Tip "停止服务: .\deploy.ps1 stop"
        Write-Tip "查看进程: Get-Process -Id $($process.Id)"
    }
    else {
        Write-Ok "前台启动中... (按 Ctrl+C 停止)"
        Write-Host ""
        & java -jar $jarFile --spring.profiles.active=$profile
    }

    Pop-Location
}

# ============================== 停止 =========================================
function Stop-App {
    Write-Step "停止应用..."

    if (Test-Path $PidFile) {
        $pid = Get-Content $PidFile -Raw
        $pid = $pid.Trim()
        $proc = Get-Process -Id $pid -ErrorAction SilentlyContinue
        if ($proc) {
            $proc.Kill()
            Write-Ok "应用已停止 (PID: $pid)"
        }
        else {
            Write-Ok "进程已不存在 (PID: $pid)"
        }
        Remove-Item $PidFile -Force
    }
    else {
        # 尝试查找 Java 进程
        $procs = Get-CimInstance Win32_Process -Filter "name='java.exe'" -ErrorAction SilentlyContinue |
            Where-Object { $_.CommandLine -match "group45-backend" }
        if ($procs) {
            Write-Warn "发现运行中的进程但无 PID 文件:"
            $procs | ForEach-Object {
                Write-Host "    PID: $($_.ProcessId)  $($_.Name)"
            }
            $answer = Read-Host "  是否终止这些进程？(y/n)"
            if ($answer -eq "y" -or $answer -eq "Y") {
                $procs | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
                Write-Ok "已终止所有相关进程"
            }
        }
        else {
            Write-Ok "没有运行中的进程"
        }
    }
}

# ============================== 状态 =========================================
function Show-Status {
    Write-Step "服务状态..."

    if (Test-Path $PidFile) {
        $pid = Get-Content $PidFile -Raw
        $pid = $pid.Trim()
        $proc = Get-Process -Id $pid -ErrorAction SilentlyContinue
        if ($proc) {
            Write-Ok "运行中 (PID: $pid, 内存: $([math]::Round($proc.WorkingSet64/1MB, 1)) MB)"
            Write-Host ""

            Load-EnvFile
            $port = [Environment]::GetEnvironmentVariable("SERVER_PORT", "Process")
            if (-not $port) { $port = "8081" }

            # 健康检查
            try {
                $healthUrl = "http://localhost:${port}/actuator/health"
                $response = Invoke-WebRequest -Uri $healthUrl -TimeoutSec 5 -UseBasicParsing
                if ($response.StatusCode -eq 200) {
                    Write-Ok "健康检查通过 (HTTP $($response.StatusCode))"
                }
                else {
                    Write-Warn "健康检查返回 HTTP $($response.StatusCode)"
                }
            }
            catch {
                Write-Warn "健康检查失败（可能还在启动中）"
            }
        }
        else {
            Write-Err "PID 文件存在但进程已死 (PID: $pid)"
            Remove-Item $PidFile -Force
        }
    }
    else {
        $procs = Get-CimInstance Win32_Process -Filter "name='java.exe'" -ErrorAction SilentlyContinue |
            Where-Object { $_.CommandLine -match "group45-backend" }
        if ($procs) {
            Write-Warn "发现运行中的进程但无 PID 文件:"
            $procs | ForEach-Object { Write-Host "    PID: $($_.ProcessId)" }
        }
        else {
            Write-Warn "应用未运行"
        }
    }
}

# ============================== 帮助 =========================================
function Show-Help {
    Write-Banner
    Write-Host "用法: .\deploy.ps1 [命令]"
    Write-Host ""
    Write-Host "命令:" -ForegroundColor White
    Write-Host "  infra-up      一键启动 Docker 基础设施 (MySQL/Redis/ES/Kafka/MinIO)"
    Write-Host "  infra-down    停止/销毁 Docker 基础设施"
    Write-Host "  infra-status  查看 Docker 容器运行状态"
    Write-Host "  build         只编译项目"
    Write-Host "  start         编译 + 前台启动（适合调试，Ctrl+C 停止）"
    Write-Host "  start-bg      编译 + 后台启动（适合长期运行）"
    Write-Host "  stop          停止后台运行的应用"
    Write-Host "  status        查看服务运行状态"
    Write-Host "  check         只检测环境（不等启动）"
    Write-Host "  help          显示此帮助"
    Write-Host ""
    Write-Host "环境变量:" -ForegroundColor White
    Write-Host "  `$env:SKIP_TESTS='false'  编译时运行测试（默认跳过）"
    Write-Host ""
    Write-Host "前置依赖:" -ForegroundColor White
    Write-Host "  - Docker Desktop  (运行 infra-up 时必需)"
    Write-Host "  - JDK 17+         https://adoptium.net"
    Write-Host "  - Maven 3.9+      https://maven.apache.org"
    Write-Host "  - LiteParse        (可选，pip install 'mineru[core]')"
    Write-Host ""
    Write-Host "示例 (首次部署):" -ForegroundColor White
    Write-Host "  .\deploy.ps1 infra-up     # 1. 启动 Docker 基础设施"
    Write-Host "  .\deploy.ps1 start-bg     # 2. 编译 + 后台启动应用"
    Write-Host "  .\deploy.ps1 status       # 3. 看状态"
}

# ============================== 交互式引导 ===================================
function Start-Interactive {
    Write-Banner
    Write-Host "  此脚本将引导你完成 Group45 Backend 的部署" -ForegroundColor Yellow
    Write-Host ""

    # Step 0: Docker 基础设施
    Write-Host "--- Step 0/4: Docker 基础设施 ---" -ForegroundColor White
    $dockerAvailable = $false
    try {
        docker info 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { $dockerAvailable = $true }
    }
    catch { }

    if ($dockerAvailable) {
        Write-Ok "Docker 可用"

        $runningContainers = docker ps --format '{{.Names}}' 2>&1 | Out-String
        if ($runningContainers -match "prototype") {
            Write-Ok "检测到 prototype 相关容器已在运行"
            Write-Host ""
            $restartInfra = Read-Host "  是否重新启动基础设施？(y/n) [默认: n]"
            if ($restartInfra -eq "y" -or $restartInfra -eq "Y") {
                Invoke-InfraUp
            }
        }
        else {
            Write-Host ""
            Write-Tip "检测到你还没有启动基础设施（MySQL/Redis/ES/Kafka/MinIO）"
            $startInfra = Read-Host "  是否用 Docker 一键启动？(y/n) [默认: y]"
            if (-not $startInfra) { $startInfra = "y" }
            if ($startInfra -eq "y" -or $startInfra -eq "Y") {
                Invoke-InfraUp
            }
            else {
                Write-Warn "跳过基础设施，请确保 MySQL/Redis/ES/Kafka/MinIO 已手动启动"
            }
        }
    }
    else {
        Write-Warn "Docker 不可用，跳过基础设施自动部署"
        Write-Tip "请确保 MySQL/Redis/ES/Kafka/MinIO 已手动启动"
    }
    Write-Host ""

    # Step 1: 环境检测
    Write-Host "--- Step 1/4: 环境检测 ---" -ForegroundColor White
    Check-Java
    Check-Maven
    Check-LiteParse
    Write-Host ""

    # Step 2: 配置文件
    Write-Host "--- Step 2/4: 配置文件 ---" -ForegroundColor White
    Check-EnvFile
    Write-Host ""

    # Step 3: 基础设施检查
    Write-Host "--- Step 3/4: 基础设施连接 ---" -ForegroundColor White
    Check-Infrastructure
    Write-Host ""

    # Step 4: 编译与启动
    Write-Host "--- Step 4/4: 编译与启动 ---" -ForegroundColor White

    if (-not (Test-Path $EnvFile)) {
        Write-Err ".env 文件不存在，无法继续"
        exit 1
    }

    Invoke-Build

    Write-Host ""
    Write-Host "  请选择启动模式:"
    Write-Host "  1) 前台启动（适合调试，Ctrl+C 停止）"
    Write-Host "  2) 后台启动（适合长期运行）"
    Write-Host "  3) 跳过启动（只编译）"
    Write-Host ""
    $choice = Read-Host "  请输入选项 (1/2/3) [默认: 1]"
    if (-not $choice) { $choice = "1" }

    switch ($choice) {
        "1" { Start-App -Mode "foreground" }
        "2" { Start-App -Mode "background" }
        "3" { Write-Ok "编译完成，跳过启动" }
        default { Write-Err "无效选项"; exit 1 }
    }
}

# ============================== 脚本入口 =====================================
Push-Location $BackendDir
try {
    switch ($Command) {
        "infra-up" {
            Invoke-InfraUp
        }
        "infra-down" {
            Invoke-InfraDown
        }
        "infra-status" {
            Invoke-InfraStatus
        }
        "build" {
            Check-Java
            Check-Maven
            Invoke-Build
        }
        "start" {
            Check-Java
            Check-Maven
            Check-EnvFile
            Invoke-Build
            Start-App -Mode "foreground"
        }
        "start-bg" {
            Check-Java
            Check-Maven
            Check-EnvFile
            Invoke-Build
            Start-App -Mode "background"
        }
        "stop" {
            Stop-App
        }
        "status" {
            Show-Status
        }
        "check" {
            Check-Java
            Check-Maven
            Check-EnvFile
            Check-Infrastructure
            Check-LiteParse
            Write-Ok "环境检测完成"
        }
        "help" {
            Show-Help
        }
        "" {
            Start-Interactive
        }
    }
}
finally {
    Pop-Location
}
