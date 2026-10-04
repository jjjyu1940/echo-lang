# Agent 指南：EchoShell

EchoShell 是一种轻量级脚本语言，专为快速原型开发和自动化任务设计。它结合了简单的自定义语法与强大的 Shell 能力，支持颜色输出、函数、条件、循环、数学运算、原生系统命令以及内嵌 Shell 块。既可解释执行，也可编译为 C 或 Shell 脚本。

## 核心能力

| 特性               | 说明                                                                 |
|--------------------|----------------------------------------------------------------------|
| **颜色输出**       | `echo -c red/green/blue/yellow/magenta/cyan 文字`                   |
| **函数**           | `funcName:` 定义，`funcName;` 调用                                   |
| **条件判断**       | `if (条件) turn : ... else : ... :`                                 |
| **循环**           | `for 次数` 或 `for 次数 funcName()`                                  |
| **数学计算**       | `echo 表达式` 自动求值（依赖 Python3 或 bc）                         |
| **原生系统命令**   | 直接使用 `rm`, `ls`, `pwd`, `mv`, `cp`, `top`, `ps`（支持所有参数） |
| **内嵌 Shell 块**  | `shell;` … `;` 包裹任意 Shell 命令                                   |
| **编译**           | `--compile-c` → C 代码；`--compile-sh` → Shell 脚本                 |

## 快速上手

### 1. 安装

bash

chmod +x echoi


### 2. 编写脚本（`demo.echo`）

echo

echo Hello EchoShell!

echo -c green 绿色文字

ls -la /tmp

pwd

shell;

echo "This runs in real shell"

date

;

rm -f /tmp/test.txt

echo 2 * (3 + 4)


### 3. 运行

bash

./echoi demo.echo


## 原生命令详解

EchoShell 允许在脚本顶层直接调用以下命令，无需 `shell;` 块：

| 命令 | 用途                  | 示例                          |
|------|-----------------------|-------------------------------|
| rm   | 删除文件或目录        | `rm -rf /tmp/cache`           |
| ls   | 列出目录              | `ls -lh /home`                |
| pwd  | 显示当前路径          | `pwd`                         |
| mv   | 移动/重命名           | `mv old.txt new.txt`          |
| cp   | 复制                  | `cp -r src dst`               |
| top  | 进程监控（推荐非交互）| `top -bn1`                    |
| ps   | 进程快照              | `ps aux --sort=-%mem`         |

> 注意：这些命令会在解释器的 Shell 环境中直接执行，输出实时显示。编译为 C 或 Shell 时，会生成对应的 `system()` 调用或原样输出。

## 进阶用法

### 规则文件
通过 `-c` 加载规则文件，可预定义变量或函数：

bash

./echoi -c myrules.conf script.echo


### 编译与运行

bash

编译为 C 并运行

./echoi --compile-c -o prog script.echo -r

编译为 Shell 脚本

./echoi --compile-sh script.echo > run.sh && bash run.sh


## 典型场景

- **快速文件操作**：批量删除、复制、移动文件。
- **系统状态检查**：结合 `ls`、`ps`、`top` 获取快照。
- **彩色日志输出**：用 `echo -c` 高亮关键信息。
- **混合脚本**：用 `shell;` 块执行复杂管道或重定向，外层用 EchoShell 控制流程。

## 注意事项

- 原生命令的路径依赖系统 `PATH`，请确保命令可用。
- `top` 默认交互模式，建议在脚本中使用 `-bn1` 等批处理参数。
- 编译为 C 时，`system()` 调用可能受限于安全环境。
- 数学计算需 `python3` 或 `bc`，否则返回原表达式。

---

**EchoShell** – 让脚本既简洁又强大，适合 Agent 快速实现自动化任务。