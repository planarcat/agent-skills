<#
  技能安装 / 更新工具（Windows · PowerShell 版）
  与仓库根的 install.sh 行为一致：装一次 → 记住路径 → 以后不带参数一键更新所有记住的路径。

  用法（在仓库根目录）：
    .\install.ps1 <安装目录> [技能名…]   装到该目录（默认用「目录联接」）并记住这个路径
    .\install.ps1                         不带参数：更新到所有记住过的目录
    .\install.ps1 <目录> -Group report    只装某一组（report / query / tapd / plan / pm / dev / journal，自动带入口）
    .\install.ps1 -Targets                看记住哪些目录（含存在性与模式）
    .\install.ps1 -Forget <目录>          忘掉一个目录（已装的文件不动）
    .\install.ps1 -List                   列技能、分组与记住的目录
    .\install.ps1 -Lint                   技能自包含性体检（不安装）
    .\install.ps1 -Copy <目录>            用拷贝代替「目录联接」
    .\install.ps1 -NoEntry                分组安装不带入口 playbook（移植用）
    .\install.ps1 -Prune                  清理指向本仓库但源已不存在的失效链接
    .\install.ps1 -PruneBak               清理 <技能名>.bak-<时间戳> 旧备份

  三条硬规矩（同 install.sh）：
    1. 不主动创建工具的技能目录——目标目录必须已存在，否则跳过并提示。
    2. 记住的路径每次运行都重新检查是否存在：不存在就跳过（换机器、mac 路径拿到 Windows 上都属这种情况）。
    3. 装过的目录记在仓库根 install.config（每行一条：裸路径=联接，copy <路径>=拷贝）。
       该文件是本机状态，不要提交到 git。

  入口技能：playbook —— agent 找不着北时先读它，它按流程与状态把请求路由到执行技能。名字不要改。
#>

[CmdletBinding()]
param(
  # 位置参数放**第一位**：Windows PowerShell 会按声明顺序给参数自动编号，
  # 若把它放最后，第一个位置参数会被 [string]$Forget 抢走（实测踩过）。
  [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
  [string[]] $Rest,
  [switch] $Copy,
  [switch] $Link,
  [switch] $List,
  [switch] $Lint,
  [switch] $Targets,
  [string] $Forget,
  [switch] $Prune,
  [switch] $PruneBak,
  [switch] $NoEntry,
  [string] $Group
)

try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

$ErrorActionPreference = 'Stop'
$RepoDir    = $PSScriptRoot
$ConfigFile = Join-Path $RepoDir 'install.config'
$EntrySkill = 'playbook'
$UseCopy    = [bool]$Copy              # 默认用「目录联接」（不需要管理员）

function Get-GroupSkills([string] $name) {
  switch ($name) {
    { $_ -in 'report','日报' }  { return 'report-pipeline report-draft-filter report-writer' }
    { $_ -in 'query','查询' }   { return 'cnb-push-audit tapd-todo-query' }
    { $_ -in 'tapd','需求' }    { return 'tapd-requirement-writing tapd-todo-query' }
    { $_ -in 'plan','方案' }    { return 'plan-discussion plan-execution plan-lock' }
    { $_ -in 'pm','产品' }      { return 'prd-authoring requirement-clarification user-story-acceptance competitive-or-feature-brief release-note-pm meeting-to-action' }
    { $_ -in 'dev','开发' }     { return 'development-guardrails change-advice change-impact-regression impact-surface-audit resolve-merge-conflict test-case-authoring create-requirement-branch generate-commit' }
    { $_ -in 'journal','记录' } { return 'record-change-log record-development-blog' }
    default { return $null }
  }
}

function Get-AllSkills {
  Get-ChildItem -LiteralPath $RepoDir -Directory |
    Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'SKILL.md') } |
    ForEach-Object { $_.Name }
}

# ---------- install.config ----------

function Read-Config {
  if (-not (Test-Path -LiteralPath $ConfigFile)) { return @() }
  Get-Content -LiteralPath $ConfigFile -Encoding UTF8 | ForEach-Object {
    $line = $_
    $i = $line.IndexOf('#')
    if ($i -ge 0) { $line = $line.Substring(0, $i) }
    $line = $line.Trim()
    if ($line) { $line }
  }
}

function Normalize-Path([string] $p) { ($p -replace '[\\/]+$', '') }

# 写 install.config：UTF-8 **不带 BOM**（带 BOM 会污染第一行，让 install.sh 的解析多出一个字符）
function Write-ConfigLines([string[]] $lines) {
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllLines($ConfigFile, $lines, $enc)
}

function Get-EntryMode([string] $line) { if ($line -like 'copy *') { 'copy' } else { 'link' } }

function Get-EntryPath([string] $line) {
  if ($line -like 'copy *') { return $line.Substring(5).Trim() }
  if ($line -like 'link *') { return $line.Substring(5).Trim() }
  return $line.Trim()
}

function Add-Config([string] $path, [string] $mode) {
  $n = Normalize-Path $path
  if (-not (Test-Path -LiteralPath $ConfigFile)) {
    Write-ConfigLines @(
      '# 技能安装目标（每行一个）。本文件是本机状态，不要提交到 git。'
      '# 格式：<路径>            -> 目录联接（默认）'
      '#       copy <路径>       -> 拷贝安装（工具不认联接时用这个）'
      '# 由 .\install.ps1 <目录> 自动追加；手工增删也可以，改完存盘，下次运行生效。'
      '# 另一台机器上的路径（如 mac 的 /Users/...）在这里不会装（会提示不存在）——这是期望的行为。'
    )
  }
  $lines = @(Read-Config)
  $exists = $false
  foreach ($l in $lines) { if ((Normalize-Path (Get-EntryPath $l)) -eq $n) { $exists = $true } }
  if ($exists) {
    $out = foreach ($l in (Get-Content -LiteralPath $ConfigFile -Encoding UTF8)) {
      if ($l.Trim().StartsWith('#')) { $l; continue }
      if ((Normalize-Path (Get-EntryPath $l)) -eq $n) {
        if ($mode -eq 'copy') { "copy $n" } else { $n }
      } else { $l }
    }
    Write-ConfigLines @($out)
    Write-Host "  已更新安装目标记录：$n（模式：$(if ($mode -eq 'copy') { '拷贝' } else { '联接' })）"
  } else {
    $enc = New-Object System.Text.UTF8Encoding($false)
    $nl = [Environment]::NewLine
    if ($mode -eq 'copy') { [System.IO.File]::AppendAllText($ConfigFile, "copy $n$nl", $enc) }
    else { [System.IO.File]::AppendAllText($ConfigFile, "$n$nl", $enc) }
    Write-Host "  已记住安装目标：$n（模式：$(if ($mode -eq 'copy') { '拷贝' } else { '联接' })）"
  }
}

function Remove-Config([string] $path) {
  if (-not (Test-Path -LiteralPath $ConfigFile)) { Write-Host '  没有 install.config，无需忘记。'; return }
  $n = Normalize-Path $path
  $out = foreach ($l in (Get-Content -LiteralPath $ConfigFile -Encoding UTF8)) {
    if ($l.Trim().StartsWith('#')) { $l; continue }
    if (-not $l.Trim()) { continue }
    if ((Normalize-Path (Get-EntryPath $l)) -eq $n) { continue }
    $l
  }
  Write-ConfigLines @($out)
  Write-Host "  已忘记安装目标：$n（已装的文件没动）"
}

# ---------- 比较两棵树是否一致（用于决定要不要备份）----------

function Get-TreeHash([string] $dir) {
  $h = @()
  Get-ChildItem -LiteralPath $dir -Recurse -File | Sort-Object FullName | ForEach-Object {
    $rel = $_.FullName.Substring($dir.Length).TrimStart('\', '/')
    $fh  = (Get-FileHash -LiteralPath $_.FullName -Algorithm MD5).Hash
    $h += "$rel=$fh"
  }
  return ($h -join "`n")
}

# ---------- 体检 ----------

if ($Lint) {
  Write-Host "自包含性体检（$RepoDir）"
  Write-Host '判据：① 不跳出自身目录 ② 不引用别的技能下的文件路径 ③ 同名参考文件不漂移'
  Write-Host ''
  $names = @(Get-AllSkills)
  $warn = 0; $tips = 0
  foreach ($name in $names) {
    $skillMd = Join-Path (Join-Path $RepoDir $name) 'SKILL.md'
    $text = Get-Content -LiteralPath $skillMd -Raw -Encoding UTF8
    $bad = ($text -split "`n") | Where-Object { $_ -match '\.\./+[A-Za-z]' -and $_ -notmatch '\.\.\./' }
    if ($bad) { $warn++; Write-Host "  [!] ${name}：发现跳出自身目录的相对路径"; $bad | Select-Object -First 5 | ForEach-Object { Write-Host "      $_" } }
    $cross = @()
    foreach ($other in $names) { if ($other -ne $name -and $text -match [regex]::Escape("$other/")) { $cross += $other } }
    if ($cross.Count -gt 0) { $tips++; Write-Host "  [i] ${name}：正文里引用了别的技能下的文件路径 -> $($cross -join ', ')"; Write-Host '      同仓库（或同组一起移植）时能解析；若只搬本技能，这些指针会指空。' }
  }
  $map = @{}
  foreach ($name in $names) {
    $refDir = Join-Path (Join-Path $RepoDir $name) 'references'
    if (Test-Path -LiteralPath $refDir) {
      Get-ChildItem -LiteralPath $refDir -File -Filter *.md | ForEach-Object {
        $k = $_.Name
        if (-not $map.ContainsKey($k)) { $map[$k] = @() }
        $map[$k] += [pscustomobject]@{ Path = "$name/references/$($_.Name)"; Hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm MD5).Hash }
      }
    }
  }
  $drift = 0
  foreach ($k in $map.Keys) {
    $items = $map[$k]
    if ($items.Count -gt 1) {
      $uniq = ($items | Select-Object -ExpandProperty Hash | Sort-Object -Unique).Count
      if ($uniq -gt 1) {
        $drift++; $warn++
        Write-Host "  [!] 同名参考文件内容不一致（手工同步漏了）：$k"
        $items | ForEach-Object { Write-Host "      $($_.Path)" }
      }
    }
  }
  if ($warn -eq 0 -and $tips -eq 0) { Write-Host '  [OK] 全部技能自包含：任意单个技能或技能组都能直接拷走使用（不带入口 playbook 也能跑）。' }
  elseif ($warn -eq 0) { Write-Host "  [OK] 没有真依赖：所有技能都自包含；上面 $tips 条只是文档指针，同组一起搬就不会指空。" }
  Write-Host ''
  Write-Host '移植示例：'
  Write-Host '  .\install.ps1 -Copy -NoEntry C:\export report-writer'
  exit 0
}

# ---------- -Targets ----------

if ($Targets) {
  Write-Host "记住的安装目标（$ConfigFile）："
  $found = $false
  foreach ($line in (Read-Config)) {
    $found = $true
    $p = Get-EntryPath $line
    $m = if ((Get-EntryMode $line) -eq 'copy') { '拷贝' } else { '联接' }
    if (Test-Path -LiteralPath $p -PathType Container) {
      $n = (Get-ChildItem -LiteralPath $p -Force | Measure-Object).Count
      Write-Host "  [OK] $p（存在，已有 $n 项 ｜ 模式：$m）"
    } else {
      Write-Host "  [!]  $p（不存在——运行时装机会跳过它 ｜ 模式：$m）"
    }
  }
  if (-not $found) { Write-Host '  （还没有记住任何目录；用 .\install.ps1 <安装目录> 装一次就会记住）' }
  exit 0
}

if ($Forget) { Remove-Config $Forget; exit 0 }

if ($List) {
  Write-Host "仓库里的技能（$RepoDir）："
  Get-AllSkills | ForEach-Object { Write-Host "  $_" }
  Write-Host ''
  Write-Host "入口：$EntrySkill（技能地图 + 流程路由；找不着北先读它）"
  Write-Host ''
  Write-Host '分组（-Group <名>）：'
  foreach ($g in 'report','query','tapd','plan','pm','dev','journal') { Write-Host ("  {0,-8}{1}" -f $g, (Get-GroupSkills $g)) }
  Write-Host ''
  Write-Host '记住的安装目标：'
  $lines = @(Read-Config)
  if ($lines.Count -gt 0) { $lines | ForEach-Object { Write-Host "  $_" } } else { Write-Host '  （空；用 .\install.ps1 <安装目录> 装一次就会记住）' }
  exit 0
}

# ---------- 要装哪些技能 ----------

$pos = @($Rest | Where-Object { $_ -and -not $_.StartsWith('-') })
$Target = if ($pos.Count -ge 1) { $pos[0] } else { $null }
$SkillNames = @()
if ($pos.Count -ge 2) { $SkillNames = $pos[1..($pos.Count - 1)] }

$Skills = @()
if ($Group) {
  $grp = Get-GroupSkills $Group
  if (-not $grp) { Write-Host '错误：未知分组。可用分组：report / query / tapd / plan / pm / dev / journal'; exit 1 }
  $Skills = @($grp -split '\s+')
  if (-not $NoEntry) { $Skills += $EntrySkill }
} elseif ($SkillNames.Count -gt 0) {
  $Skills = $SkillNames
} else {
  $Skills = @(Get-AllSkills)
}
if ($Skills.Count -eq 0) { Write-Host '错误：仓库里没找到任何带 SKILL.md 的技能目录。'; exit 1 }

# ---------- 要装到哪些目录 ----------

$TargetPaths = @(); $TargetModes = @()
if ($Target) {
  $TargetPaths = @($Target)
  $TargetModes = @($(if ($UseCopy) { 'copy' } else { 'link' }))
} else {
  foreach ($line in (Read-Config)) {
    $TargetPaths += (Get-EntryPath $line)
    $TargetModes += (Get-EntryMode $line)
  }
  if ($TargetPaths.Count -eq 0) {
    Write-Host '还没有记住任何安装目录。' -ForegroundColor Yellow
    Write-Host ''
    Write-Host '用法：.\install.ps1 <安装目录> [技能名…]   例如：'
    Write-Host "  .\install.ps1 $(Join-Path $HOME '.claude\skills')      # Claude Code"
    Write-Host "  .\install.ps1 $(Join-Path $HOME '.workbuddy\skills')   # WorkBuddy"
    Write-Host ''
    Write-Host '本工具不会替你创建技能目录。以下是本机已存在的候选（仅提示，未安装）：'
    $cands = @('.claude\skills', '.workbuddy\skills', '.cursor\skills', '.codex\skills', '.agents\skills') | ForEach-Object { Join-Path $HOME $_ }
    foreach ($c in $cands) {
      if (Test-Path -LiteralPath $c -PathType Container) { Write-Host "  [OK] $c" }
    }
    exit 1
  }
}

# ---------- 装一个技能 ----------
# 返回：'new' | 'skip' | 'fresh'
function Install-One([string] $tdir, [string] $name, [string] $mode) {
  $src = Join-Path $RepoDir $name
  $dst = Join-Path $tdir $name
  if (-not (Test-Path -LiteralPath (Join-Path $src 'SKILL.md'))) {
    Write-Host "  跳过 ${name}（不是技能目录，缺 SKILL.md）"
    return 'skip'
  }
  if ($mode -eq 'link') {
    $item = Get-Item -LiteralPath $dst -Force -ErrorAction SilentlyContinue
    if ($item -and $item.LinkType) {
      if ((Normalize-Path $item.Target) -eq (Normalize-Path $src)) {
        Write-Host "  已是最新 ${name}（链接指向仓库）"
        return 'fresh'
      }
    }
    if ($item -and -not $item.PSIsContainer -and $item.LinkType) {
      # 指向别处的链接 → 直接换掉
      Remove-Item -LiteralPath $dst -Force
    } elseif ($item) {
      # 已有真实目录 → 内容一致就直接换；不同则备份
      if ((Get-TreeHash $src) -eq (Get-TreeHash $dst)) {
        Write-Host "  原有 ${name} 与仓库内容一致，直接替换（不备份）"
      } else {
        $ts = Get-Date -Format 'yyyyMMddHHmmss'
        Rename-Item -LiteralPath $dst -NewName "$name.bak-$ts"
        Write-Host "  [!] 原有 ${name} 与仓库内容不同（可能有你的本地改动），已备份到 $name.bak-$ts（未删除）"
      }
    }
    # 建链接：命令"没报错" ≠ 真建出来了 —— 必须复核一次（实测：macOS 上
    # New-Item -ItemType Junction 会静默成功但什么都没建，所以先按平台选类型，再验证）。
    $created = $false
    if ($IsWin) {
      try {
        New-Item -ItemType Junction -Path $dst -Target $src -ErrorAction Stop | Out-Null
        $created = Test-Path -LiteralPath $dst
      } catch { $created = $false }
      if ($created) { Write-Host "  已联接 ${name}"; return 'new' }
    }
    try {
      New-Item -ItemType SymbolicLink -Path $dst -Target $src -ErrorAction Stop | Out-Null
      $created = Test-Path -LiteralPath $dst
    } catch { $created = $false }
    if ($created) { Write-Host "  已建立符号链接 ${name}"; return 'new' }

    Copy-Item -LiteralPath $src -Destination $dst -Recurse -Force
    Write-Host "  [!] 本机无法建链接（需要管理员 / 开发者模式），已改为拷贝 ${name}；想固定用拷贝请加 -Copy"
    return 'new'
  }

  # ---- 拷贝模式 ----
  if (Test-Path -LiteralPath $dst) { Remove-Item -LiteralPath $dst -Recurse -Force }
  Copy-Item -LiteralPath $src -Destination $dst -Recurse -Force
  Write-Host "  已安装 ${name}"
  return 'new'
}

# ---------- 逐个目标 ----------

$anyOk = $false
for ($i = 0; $i -lt $TargetPaths.Count; $i++) {
  $tdir = $TargetPaths[$i]
  $tmode = $TargetModes[$i]
  $mdesc = if ($tmode -eq 'copy') { '拷贝' } else { '联接' }
  Write-Host "-- 目标目录：$tdir（模式：$mdesc）"
  if (-not (Test-Path -LiteralPath $tdir -PathType Container)) {
    Write-Host '  [!] 路径不存在，跳过（本工具不创建技能目录）。'
    Write-Host '      确认路径写对、或先由该工具自己建好目录，再来装。'
    continue
  }
  $ok = 0; $skip = 0; $fresh = 0
  foreach ($name in $Skills) {
    switch (Install-One $tdir $name $tmode) {
      'new'   { $ok++ }
      'skip'  { $skip++ }
      'fresh' { $fresh++ }
    }
  }
  $anyOk = $true
  Write-Host "  -> 新装 $ok / 已是最新 $fresh / 跳过 $skip"

  # 失效链接
  Get-ChildItem -LiteralPath $tdir -Force | Where-Object { $_.LinkType } | ForEach-Object {
    $t = $_.Target
    if ($t -and (Normalize-Path $t).StartsWith((Normalize-Path $RepoDir)) -and -not (Test-Path -LiteralPath $_.FullName)) {
      if ($Prune) { Remove-Item -LiteralPath $_.FullName -Force; Write-Host "  已清理失效链接 $($_.Name)（源已不在仓库）" }
      else { Write-Host "  提示：$($_.Name) 是失效链接（仓库里已无此技能）；加 -Prune 可清理" }
    }
  }

  # 旧备份
  Get-ChildItem -LiteralPath $tdir -Directory -Force | Where-Object { $_.Name -match '\.bak-\d{14}$' } | ForEach-Object {
    $bname = $_.Name
    $skill = $bname -replace '\.bak-\d{14}$', ''
    $live  = Get-Item -LiteralPath (Join-Path $tdir $skill) -Force -ErrorAction SilentlyContinue
    if ($live -and $live.LinkType -and (Normalize-Path $live.Target) -eq (Normalize-Path (Join-Path $RepoDir $skill))) {
      if ($PruneBak) { Remove-Item -LiteralPath $_.FullName -Recurse -Force; Write-Host "  已清理旧备份 $bname（$skill 已改挂链接，备份多余的）" }
      else { Write-Host "  提示：$bname 是旧备份，且 $skill 已改挂链接 -> 加 -PruneBak 可清理" }
    } else {
      Write-Host "  提示：$bname 是旧备份，但 $skill 当前不是指向仓库的链接 -> 先别删，人工确认后再处理"
    }
  }
  Write-Host ''
}

if ($Target -and $anyOk) {
  $m = if ($UseCopy) { 'copy' } else { 'link' }
  Add-Config $Target $m
}

if (-not $anyOk) {
  Write-Host '没有任何目录被安装（上面每个目标都跳过了）。'
  Write-Host "记忆文件：$ConfigFile（未新增条目）"
  exit 1
}

Write-Host '提示：联接/符号链接模式下 git pull 后技能立即生效；仓库里新增技能后跑一次 .\install.ps1 即可补齐。'
Write-Host "记忆文件：$ConfigFile（.\install.ps1 -Targets 查看，-Forget <目录> 移除）"
Write-Host "入口技能：$EntrySkill —— agent 找不着北时先读它，它按流程与状态路由到执行技能。"
