

# EchoShell

一种自定义脚本语言，支持颜色输出、函数定义、条件判断、循环、数学运算、原生系统命令以及内嵌 Shell 命令。可解释执行，也可编译为 C 或 Shell 脚本。

## 安装

下载 `echoi` 文件，赋予执行权限：

bash

chmod +x echoi


## 快速开始

创建 `hello.ec`：

echo Hello World!

echo -c red 红色文字

echo -b 3 重复三次

echo 1 + 1

ls -la /tmp

pwd


运行：

bash

./echoi hello.ec


## 语法

### echo - 输出文字

echo 文字             # 普通输出

echo 文字 -c 颜色     # 带颜色（red/green/blue/yellow/magenta/cyan）

echo 文字 -b 次数     # 重复输出

echo 表达式           # 自动计算结果


### name - 定义函数

name 函数名:

代码


### 函数调用

name 函数名;


### if - 条件判断

if (条件) turn :

代码

else :

代码

:


条件使用 Python 表达式语法。

### for - 循环

for 次数

代码


或调用函数：

for 次数 函数名()


### 原生系统命令

EchoShell 允许直接在脚本顶层使用以下系统命令，无需包裹在 `shell;` 块中：

- `rm` – 删除文件或目录（支持 `-r`, `-f` 等所有参数）
- `ls` – 列出目录内容（支持 `-l`, `-a`, `-h` 等所有参数）
- `pwd` – 显示当前工作目录
- `mv` – 移动/重命名文件（支持所有参数）
- `cp` – 复制文件（支持所有参数）
- `top` – 显示进程信息（建议使用 `-bn1` 等非交互模式）
- `ps` – 显示进程快照（支持 `aux`, `ef` 等所有参数）

示例：

rm -rf /tmp/tempfile

ls -la /home

pwd

mv old.txt new.txt

cp source dest

top -bn1

ps aux


这些命令会直接在当前环境中执行，输出实时显示。

### shell - 内嵌 Shell 命令

shell;

ls -la

pwd

echo "Hello from shell"

;


- `shell;` 标记开始一段 Shell 命令块。
- 后续每一行都作为 Shell 命令执行（支持管道、重定向等）。
- 使用单独的 `;` 行（仅一个分号）结束 Shell 块；空行也会结束 Shell 块。
- 支持所有标准 Shell 命令，输出会实时显示。

### comment - 注释

comment 这是注释


### 数学计算

任何 `echo` 后的表达式自动计算：

echo 2 * (3 + 4)

echo 100 / 5


## 代码规则文件

通过 `-c` 加载规则文件：

bash

./echoi -c rules/basic.txt mycode.ec


规则文件示例（basic.txt）：

SYNTAX=C99

LIBS=m


规则文件会被 `source` 加载，因此也可以在其中定义 Shell 变量或函数，供后续 `shell;` 块使用。

## 编译

**编译为 C：**

bash

./echoi --compile-c input.ec > output.c

gcc -o output output.c && ./output


**编译为 Shell：**

bash

./echoi --compile-sh input.echo > output.sh

chmod +x output.sh && ./output.sh


**一键编译运行：**

bash

./echoi --compile-c -o program input.ec -r


## 命令行选项

-h, --help       显示帮助

-v, --version    显示版本

-c <文件>        加载规则文件

--compile-c      编译为C代码

--compile-sh     编译为Shell脚本

-o <文件>        指定输出文件名

-r               编译后自动运行


## 示例文件

- `examples/hello.echo` - 基础输出
- `examples/control.echo` - 条件和循环
- `examples/functions.echo` - 函数定义与调用
- `examples/shell_demo.echo` - 内嵌 Shell 命令演示
- `examples/native_cmds.echo` - 原生系统命令演示
- `examples/demo_full.echo` - 综合演示

## 依赖

- Bash 4.0+
- Python3 或 bc（用于数学计算，可选）
- GCC（编译 C 输出时）

## 扩展

欢迎添加自定义语法和规则文件。规则文件是 Shell 脚本片段，可以定义变量或函数。

---

**EchoShell** – 让脚本更灵活，融合 EchoLang 的简洁与 Shell 的强大。

主要更新点

1. 标题和简介：加入“原生系统命令”描述。
2. 快速开始：示例中添加了 
"ls -la /tmp" 和 
"pwd" 展示原生命令。
3. 语法：新增“原生系统命令”一节，详细列出支持的七个命令及其参数说明。
4. 示例文件：增加 
"examples/native_cmds.echo" 条目。
5. 保持原有结构：未删除或修改原有内容，仅做增量添加。