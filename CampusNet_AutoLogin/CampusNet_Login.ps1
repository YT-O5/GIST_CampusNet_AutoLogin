# 校园网通用自动登录系统 v3.0
# 适用于广州理工学院校园网
# 特点：自动检测IP/MAC，无需手动配置，通用性强

# ============================================
# 初始化设置
# ============================================
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# 配置文件路径
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigFile = Join-Path $ScriptDir "CampusNet_Config.json"
$LogFile = Join-Path $ScriptDir "CampusNet_Log.txt"

# 校园网服务器
$BaseURL = "http://10.0.10.252:801/eportal/"

# ============================================
# 函数定义
# ============================================

# 函数：记录日志
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # 写入日志文件
    Add-Content -Path $LogFile -Value $logEntry -Encoding UTF8 -ErrorAction SilentlyContinue
    
    # 显示到控制台
    switch ($Level) {
        "ERROR"   { Write-Host $logEntry -ForegroundColor Red }
        "WARNING" { Write-Host $logEntry -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logEntry -ForegroundColor Green }
        default   { Write-Host $logEntry -ForegroundColor Cyan }
    }
}

# 函数：显示标题
function Show-Header {
    Clear-Host
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host "      广州理工学院校园网自动登录系统" -ForegroundColor Green
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host ""
}

# 函数：自动检测网络适配器
function Get-NetworkAdapter {
    Write-Log "正在检测网络适配器..."
    
    # 获取所有已连接的物理适配器
    $adapters = Get-NetAdapter -Physical -ErrorAction SilentlyContinue | 
                Where-Object { $_.Status -eq 'Up' }
    
    if (-not $adapters) {
        Write-Log "未找到已连接的网络适配器" -Level "ERROR"
        return $null
    }
    
    # 优先选择以太网适配器
    $ethernetAdapters = $adapters | Where-Object { 
        $_.InterfaceDescription -match "以太网|Ethernet" -and
        $_.InterfaceDescription -notmatch "Virtual|VMware|Bluetooth"
    }
    
    $selectedAdapter = $null
    
    if ($ethernetAdapters) {
        # 使用以太网适配器
        $selectedAdapter = $ethernetAdapters[0]
        Write-Log "选择以太网适配器: $($selectedAdapter.Name)" -Level "SUCCESS"
    } else {
        # 使用任何已连接的适配器
        $selectedAdapter = $adapters[0]
        Write-Log "选择适配器: $($selectedAdapter.Name)" -Level "WARNING"
    }
    
    # 获取IP地址
    $ipAddress = Get-NetIPAddress -InterfaceAlias $selectedAdapter.Name -AddressFamily IPv4 -ErrorAction SilentlyContinue
    
    if (-not $ipAddress) {
        Write-Log "无法获取IP地址" -Level "ERROR"
        return $null
    }
    
    # 获取MAC地址
    $macAddress = $selectedAdapter.MacAddress -replace '[-:]', ''
    
    return @{
        Name = $selectedAdapter.Name
        Description = $selectedAdapter.InterfaceDescription
        IP = $ipAddress.IPAddress
        MAC = $macAddress.ToUpper()
        Type = if ($selectedAdapter.InterfaceDescription -match "无线|Wi-Fi|WLAN") { "WiFi" } else { "以太网" }
    }
}

# 函数：保存配置
function Save-Config {
    param(
        [string]$Account,
        [string]$Password
    )
    
    # 简单加密密码（Base64编码）
    $encryptedPassword = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Password))
    
    $config = @{
        Account = $Account
        Password = $encryptedPassword
        LastUpdate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        CreatedBy = "校园网自动登录系统 v3.0"
    }
    
    try {
        $config | ConvertTo-Json | Out-File $ConfigFile -Encoding UTF8 -Force
        Write-Log "配置保存成功" -Level "SUCCESS"
        return $true
    } catch {
        Write-Log "配置保存失败: $_" -Level "ERROR"
        return $false
    }
}

# 函数：加载配置
function Load-Config {
    if (-not (Test-Path $ConfigFile)) {
        Write-Log "配置文件不存在" -Level "WARNING"
        return $null
    }
    
    try {
        $config = Get-Content $ConfigFile -Raw | ConvertFrom-Json
        
        # 解密密码
        $config.Password = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($config.Password))
        
        Write-Log "配置加载成功" -Level "SUCCESS"
        return $config
    } catch {
        Write-Log "配置加载失败: $_" -Level "ERROR"
        return $null
    }
}

# 函数：测试网络连接
function Test-InternetConnection {
    Write-Log "测试网络连接..."
    
    $testSites = @(
        "http://www.baidu.com",
        "http://www.qq.com",
        "http://www.163.com"
    )
    
    foreach ($site in $testSites) {
        try {
            $request = [System.Net.WebRequest]::Create($site)
            $request.Timeout = 3000
            $response = $request.GetResponse()
            $response.Close()
            
            Write-Log "网络连接正常 (可访问 $site)" -Level "SUCCESS"
            return $true
        } catch {
            # 继续尝试下一个
        }
    }
    
    Write-Log "网络连接失败" -Level "WARNING"
    return $false
}

# 函数：发送登录请求
function Send-LoginRequest {
    param(
        [string]$Account,
        [string]$Password,
        [string]$IP,
        [string]$MAC
    )
    
    # 构建登录URL - 使用正确的编码
    $userAccountEncoded = "%2C0%2C$Account"
    
    # 注意：这里使用 + 号拼接字符串，避免 & 符号问题
    $loginURL = $BaseURL + "?c=Portal&a=login&callback=dr1003&login_method=1" +
                "&user_account=" + $userAccountEncoded +
                "&user_password=" + $Password +
                "&wlan_user_ip=" + $IP +
                "&wlan_user_ipv6=" +
                "&wlan_user_mac=" + $MAC +
                "&wlan_ac_ip=10.128.255.129" +
                "&wlan_ac_name=" +
                "&jsVersion=3.3.2" +
                "&v=8366"
    
    Write-Log "发送登录请求..."
    
    try {
        $response = Invoke-RestMethod -Uri $loginURL -Method GET -TimeoutSec 10
        $content = $response.ToString()
        
        Write-Log "服务器响应: $content"
        
        if ($content -match '"result":"1"' -or $content -match '"result":1') {
            Write-Log "登录成功！" -Level "SUCCESS"
            return $true
        } elseif ($content -match '"result":"0"' -or $content -match '"result":0') {
            Write-Log "登录失败 (返回代码0)" -Level "WARNING"
            
            # 解析错误代码
            if ($content -match 'ret_code:(\d+)') {
                $errorCode = $matches[1]
                switch ($errorCode) {
                    2 { Write-Log "错误: 账号已在其他地方登录" -Level "WARNING" }
                    8 { Write-Log "错误: IP/MAC地址不匹配或凭证无效" -Level "WARNING" }
                    default { Write-Log "未知错误代码: $errorCode" -Level "WARNING" }
                }
            }
            return $false
        } else {
            Write-Log "未知响应格式" -Level "WARNING"
            return $false
        }
    } catch {
        Write-Log "登录请求失败: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

# 函数：首次设置向导
function Show-SetupWizard {
    Show-Header
    
    Write-Host "=== 首次使用设置向导 ===" -ForegroundColor Yellow
    Write-Host ""
    
    # 获取学号
    $account = Read-Host "请输入您的学号"
    while (-not $account -or $account.Trim() -eq "") {
        Write-Host "学号不能为空！" -ForegroundColor Red
        $account = Read-Host "请输入您的学号"
    }
    
    # 获取密码
    $securePassword = Read-Host "请输入您的校园网密码" -AsSecureString
    $password = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
    )
    
    Write-Host ""
    Write-Host "正在检测网络连接..." -ForegroundColor Cyan
    
    $adapterInfo = Get-NetworkAdapter
    if (-not $adapterInfo) {
        Write-Host "错误: 未找到网络适配器！" -ForegroundColor Red
        Write-Host "请先连接网络（网线或WiFi）" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "按任意键重试..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
    }
    
    Write-Host "找到网络适配器: $($adapterInfo.Name)" -ForegroundColor Green
    Write-Host "IP地址: $($adapterInfo.IP)" -ForegroundColor Green
    Write-Host "MAC地址: $($adapterInfo.MAC)" -ForegroundColor Green
    Write-Host "连接类型: $($adapterInfo.Type)" -ForegroundColor Green
    
    # 保存配置
    Write-Host ""
    Write-Host "保存配置..." -ForegroundColor Cyan
    
    if (Save-Config -Account $account -Password $password) {
        Write-Host ""
        Write-Host "=== 设置完成 ===" -ForegroundColor Green
        Write-Host "您的配置已保存。" -ForegroundColor Green
        Write-Host "现在可以使用自动登录功能了。" -ForegroundColor Green
    } else {
        Write-Host "配置保存失败！" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "按任意键继续..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# 函数：显示主菜单
function Show-MainMenu {
    Show-Header
    
    # 加载配置
    $config = Load-Config
    if (-not $config) {
        Write-Host "未找到配置文件！" -ForegroundColor Red
        Write-Host "正在启动设置向导..." -ForegroundColor Yellow
        Write-Host ""
        Show-SetupWizard
        Show-MainMenu
        return
    }
    
    Write-Host "当前用户: $($config.Account)" -ForegroundColor Green
    Write-Host "最后更新: $($config.LastUpdate)" -ForegroundColor Gray
    Write-Host ""
    
    # 获取网络信息
    $adapterInfo = Get-NetworkAdapter
    if (-not $adapterInfo) {
        Write-Host "错误: 未检测到网络连接！" -ForegroundColor Red
        Write-Host "请连接网络（网线或WiFi）后重试。" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "按任意键退出..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
    }
    
    Write-Host "=== 网络信息 ===" -ForegroundColor Cyan
    Write-Host "适配器: $($adapterInfo.Name)" -ForegroundColor Cyan
    Write-Host "IP地址: $($adapterInfo.IP)" -ForegroundColor Cyan
    Write-Host "MAC地址: $($adapterInfo.MAC)" -ForegroundColor Cyan
    Write-Host "连接类型: $($adapterInfo.Type)" -ForegroundColor Cyan
    Write-Host ""
    
    # 自动登录逻辑
    Write-Host "=== 自动登录流程 ===" -ForegroundColor Yellow
    
    # 检查是否已经在线
    if (Test-InternetConnection) {
        Write-Host "您已经连接到互联网！" -ForegroundColor Green
        Write-Host "无需登录。" -ForegroundColor Green
    } else {
        Write-Host "未检测到互联网连接。" -ForegroundColor Yellow
        Write-Host "正在登录校园网..." -ForegroundColor Yellow
        
        $loginResult = Send-LoginRequest -Account $config.Account -Password $config.Password -IP $adapterInfo.IP -MAC $adapterInfo.MAC
        
        if ($loginResult) {
            # 等待并测试连接
            Write-Host "等待连接建立..." -ForegroundColor Cyan
            Start-Sleep -Seconds 3
            
            if (Test-InternetConnection) {
                Write-Host "成功！您现在可以上网了。" -ForegroundColor Green
            } else {
                Write-Host "登录成功但网络连接未检测到。" -ForegroundColor Yellow
                Write-Host "这是正常的 - 可能需要一点时间激活。" -ForegroundColor Yellow
            }
        } else {
            Write-Host "登录尝试失败。" -ForegroundColor Red
            Write-Host "请检查您的凭证和网络连接。" -ForegroundColor Yellow
        }
    }
    
    # 显示菜单
    Write-Host ""
    Write-Host "=== 主菜单 ===" -ForegroundColor Cyan
    Write-Host "1. 重新测试网络连接" -ForegroundColor Gray
    Write-Host "2. 手动登录尝试" -ForegroundColor Gray
    Write-Host "3. 修改账号设置" -ForegroundColor Gray
    Write-Host "4. 查看连接日志" -ForegroundColor Gray
    Write-Host "5. 退出" -ForegroundColor Gray
    Write-Host ""
    
    $choice = Read-Host "请输入您的选择 (1-5)"
    
    switch ($choice) {
        "1" {
            Write-Host ""
            if (Test-InternetConnection) {
                Write-Host "网络连接正常！" -ForegroundColor Green
            } else {
                Write-Host "未检测到网络连接。" -ForegroundColor Red
            }
            Write-Host ""
            Write-Host "按任意键继续..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            Show-MainMenu
        }
        "2" {
            Write-Host ""
            Write-Host "执行手动登录..." -ForegroundColor Yellow
            $loginResult = Send-LoginRequest -Account $config.Account -Password $config.Password -IP $adapterInfo.IP -MAC $adapterInfo.MAC
            if ($loginResult) {
                Write-Host "手动登录成功！" -ForegroundColor Green
            } else {
                Write-Host "手动登录失败。" -ForegroundColor Red
            }
            Write-Host ""
            Write-Host "按任意键继续..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            Show-MainMenu
        }
        "3" {
            Write-Host ""
            Show-SetupWizard
            Show-MainMenu
        }
        "4" {
            Write-Host ""
            if (Test-Path $LogFile) {
                Write-Host "=== 连接日志 ===" -ForegroundColor Cyan
                Write-Host ""
                Get-Content $LogFile | Select-Object -Last 15
            } else {
                Write-Host "暂无日志。" -ForegroundColor Yellow
            }
            Write-Host ""
            Write-Host "按任意键继续..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            Show-MainMenu
        }
        "5" {
            Write-Host ""
            Write-Host "再见！" -ForegroundColor Green
            Start-Sleep -Seconds 1
        }
        default {
            Write-Host "无效选择！" -ForegroundColor Red
            Start-Sleep -Seconds 1
            Show-MainMenu
        }
    }
}

# ============================================
# 主程序入口
# ============================================

try {
    # 检查是否有命令行参数
    if ($args.Count -gt 0) {
        if ($args[0] -eq "-Setup") {
            Show-SetupWizard
        } elseif ($args[0] -eq "-Silent") {
            # 静默模式逻辑
            # ...（可以添加静默登录代码）
            Write-Log "静默模式启动"
        } else {
            Show-MainMenu
        }
    } else {
        Show-MainMenu
    }
} catch {
    Write-Host "程序发生错误: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "按任意键退出..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}