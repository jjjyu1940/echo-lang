#!/bin/bash
# echoi - EchoLang Interpreter & Compiler
# Version 0.0.2 (added native commands: rm, ls, pwd, mv, cp, top, ps, cd)
# Modified: unknown syntax now passed to shell directly.

VERSION="0.0.2-alpha-r2"

show_help() {
    cat << 'EOF'
用法: echoi [选项] [文件]
选项:
  -h, --help       显示帮助信息
  -v, --version    显示版本信息
  -c <文件>        加载代码规则文件
  --compile-c      编译为C代码
  --compile-sh     编译为Shell脚本
  -o <输出文件>    指定输出文件名
  -r               编译后自动运行
EOF
}

show_version() {
    echo "echoi version $VERSION"
}

COMPILE_C=0
COMPILE_SH=0
OUTPUT_FILE=""
RUN_AFTER=0
RULE_FILE=""
INPUT_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) show_help; exit 0 ;;
        -v|--version) show_version; exit 0 ;;
        -c) shift; RULE_FILE="$1"; shift ;;
        --compile-c) COMPILE_C=1; shift ;;
        --compile-sh) COMPILE_SH=1; shift ;;
        -o) shift; OUTPUT_FILE="$1"; shift ;;
        -r) RUN_AFTER=1; shift ;;
        -*) echo "未知选项: $1"; exit 1 ;;
        *) INPUT_FILE="$1"; shift ;;
    esac
done

if [[ -z "$INPUT_FILE" ]]; then
    echo "错误: 未指定输入文件"
    echo "运行 'echoi -h' 查看帮助"
    exit 1
fi

if [[ ! -f "$INPUT_FILE" ]]; then
    echo "错误: 文件 '$INPUT_FILE' 不存在"
    exit 1
fi

SOURCE=$(cat "$INPUT_FILE")

if [[ -n "$RULE_FILE" ]]; then
    if [[ ! -f "$RULE_FILE" ]]; then
        echo "错误: 规则文件 '$RULE_FILE' 不存在"
        exit 1
    fi
    source "$RULE_FILE"
fi

declare -A FUNCS

eval_math() {
    local expr="$1"
    if command -v python3 >/dev/null 2>&1; then
        python3 -c "print($expr)" 2>/dev/null
    elif command -v bc >/dev/null 2>&1; then
        echo "$expr" | bc 2>/dev/null
    else
        echo "$expr"
    fi
}

eval_condition() {
    local cond="$1"
    if command -v python3 >/dev/null 2>&1; then
        local result
        result=$(python3 -c "print(1 if ($cond) else 0)" 2>/dev/null)
        [[ "$result" == "1" ]]
        return $?
    else
        [[ "$cond" == "1" || "$cond" == "true" ]]
        return $?
    fi
}

is_func_call() {
    echo "$1" | grep -qE '^[a-zA-Z_][a-zA-Z0-9_]*[(][^)]*[)][[:space:]]*;[[:space:]]*$'
}

get_func_call_name() {
    echo "$1" | sed 's/^[a-zA-Z_]*[(]//; s/[)].*//'
}

is_func_def() {
    echo "$1" | grep -qE '^[a-zA-Z_][a-zA-Z0-9_]*[(][^)]*[)][[:space:]]*:[[:space:]]*$'
}

get_func_def_name() {
    echo "$1" | sed 's/[(].*//'
}

is_if() {
    echo "$1" | grep -qE '^if[[:space:]]*[(].*[)][[:space:]]+turn[[:space:]]*:[[:space:]]*$'
}

get_if_cond() {
    echo "$1" | sed 's/^if[[:space:]]*[(]//; s/[)][[:space:]].*//'
}

is_for() {
    echo "$1" | grep -qE '^for[[:space:]]+[0-9]+[[:space:]]*$'
}

get_for_count() {
    echo "$1" | sed 's/^for[[:space:]]*//; s/[[:space:]]*$//'
}

is_for_func() {
    echo "$1" | grep -qE '^for[[:space:]]+[0-9]+[[:space:]]+[a-zA-Z_][a-zA-Z0-9_]*[(][)][[:space:]]*$'
}

get_for_func_count() {
    echo "$1" | sed 's/^for[[:space:]]*//; s/[[:space:]].*//'
}

get_for_func_name() {
    echo "$1" | sed 's/^for[[:space:]]*[0-9]*[[:space:]]*//; s/[(][)]//; s/[[:space:]]*$//'
}

is_echo() {
    echo "$1" | grep -qE '^echo[[:space:]]'
}

is_else() {
    echo "$1" | grep -qE '^else[[:space:]]*:[[:space:]]*$'
}

is_end_block() {
    echo "$1" | grep -qE '^:[[:space:]]*$'
}

is_comment() {
    echo "$1" | grep -qE '^comment'
}

process_block() {
    local block="$1"
    local mode="$2"
    
    local IFS=$'\n'
    local lines
    readarray -t lines <<< "$block"
    
    local i=0
    while [[ $i -lt ${#lines[@]} ]]; do
        local line="${lines[$i]}"
        line=$(echo "$line" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
        [[ -z "$line" ]] && ((i++)) && continue
        
        if is_comment "$line"; then
            ((i++)); continue
        fi

        # ========== 原生命令支持（已加入 cd） ==========
        local native_cmd_regex='^(rm|ls|pwd|mv|cp|top|ps|cd)([[:space:]]+|$)'
        if echo "$line" | grep -qE "$native_cmd_regex"; then
            if [[ "$mode" == "interpret" ]]; then
                eval "$line" 2>&1
            elif [[ "$mode" == "compile_c" ]]; then
                local escaped
                escaped=$(echo "$line" | sed 's/"/\\"/g')
                printf '    system("%s");\n' "$escaped"
            elif [[ "$mode" == "compile_sh" ]]; then
                echo "$line"
            fi
            ((i++))
            continue
        fi
        # ==============================================

        # === shell 块处理 ===
        if [[ "$line" == "shell;" ]]; then
            local shell_lines=()
            ((i++))
            while [[ $i -lt ${#lines[@]} ]]; do
                local sub
                sub=$(echo "${lines[$i]}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
                if [[ "$sub" == ";" ]]; then
                    ((i++))
                    break
                fi
                if [[ -z "$sub" ]]; then
                    ((i++))
                    break
                fi
                if is_echo "$sub" || is_if "$sub" || is_for "$sub" || is_func_call "$sub" || is_func_def "$sub" || is_comment "$sub" || is_for_func "$sub" || [[ "$sub" == "shell;" ]]; then
                    break
                fi
                shell_lines+=("$sub")
                ((i++))
            done
            
            if [[ ${#shell_lines[@]} -gt 0 ]]; then
                if [[ "$mode" == "interpret" ]]; then
                    for cmd in "${shell_lines[@]}"; do
                        eval "$cmd" 2>&1
                    done
                elif [[ "$mode" == "compile_c" ]]; then
                    for cmd in "${shell_lines[@]}"; do
                        local escaped
                        escaped=$(echo "$cmd" | sed 's/"/\\"/g')
                        printf '    system("%s");\n' "$escaped"
                    done
                elif [[ "$mode" == "compile_sh" ]]; then
                    for cmd in "${shell_lines[@]}"; do
                        echo "$cmd"
                    done
                fi
            fi
            continue
        fi
        
        # 函数调用
        if is_func_call "$line"; then
            local fname
            fname=$(get_func_call_name "$line")
            if [[ -n "${FUNCS[$fname]}" ]]; then
                process_block "${FUNCS[$fname]}" "$mode"
            else
                echo "错误: 未定义的函数 '$fname'" >&2
            fi
            ((i++)); continue
        fi
        
        # echo
        if is_echo "$line"; then
            local rest
            rest=$(echo "$line" | sed 's/^echo[[:space:]]*//')
            local color=""
            local repeat=1
            local text=""
            
            local IFS=' '
            local args=($rest)
            local j=0
            while [[ $j -lt ${#args[@]} ]]; do
                case "${args[$j]}" in
                    -c) ((j++)); color="${args[$j]}" ;;
                    -b) ((j++)); repeat="${args[$j]}" ;;
                    *) text+="${args[$j]} " ;;
                esac
                ((j++))
            done
            text=$(echo "$text" | sed 's/ *$//')
            
            if echo "$text" | grep -qE '^[0-9]+[[:space:]]*[\+\-\*/%]'; then
                local result
                result=$(eval_math "$text")
                if [[ -n "$result" ]]; then
                    text="$result"
                fi
            fi
            
            local colored="$text"
            case "$color" in
                red) colored=$'\033[31m'"$text"$'\033[0m' ;;
                green) colored=$'\033[32m'"$text"$'\033[0m' ;;
                blue) colored=$'\033[34m'"$text"$'\033[0m' ;;
                yellow) colored=$'\033[33m'"$text"$'\033[0m' ;;
                magenta) colored=$'\033[35m'"$text"$'\033[0m' ;;
                cyan) colored=$'\033[36m'"$text"$'\033[0m' ;;
            esac
            
            if [[ "$mode" == "interpret" ]]; then
                local k
                for ((k=0; k<repeat; k++)); do
                    echo -e "$colored"
                done
            elif [[ "$mode" == "compile_c" ]]; then
                local k
                for ((k=0; k<repeat; k++)); do
                    printf '    printf("%%s\\n", "%s");\n' "$text"
                done
            elif [[ "$mode" == "compile_sh" ]]; then
                local k
                for ((k=0; k<repeat; k++)); do
                    printf 'echo "%s"\n' "$text"
                done
            fi
            ((i++)); continue
        fi
        
        # if
        if is_if "$line"; then
            local cond
            cond=$(get_if_cond "$line")
            ((i++))
            
            local then_block=""
            while [[ $i -lt ${#lines[@]} ]]; do
                local sub
                sub=$(echo "${lines[$i]}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
                if is_else "$sub"; then
                    ((i++)); break
                fi
                if is_end_block "$sub"; then
                    break
                fi
                then_block+="$sub"$'\n'
                ((i++))
            done
            
            local else_block=""
            while [[ $i -lt ${#lines[@]} ]]; do
                local sub
                sub=$(echo "${lines[$i]}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
                if is_end_block "$sub"; then
                    ((i++)); break
                fi
                else_block+="$sub"$'\n'
                ((i++))
            done
            
            if eval_condition "$cond"; then
                process_block "$then_block" "$mode"
            else
                process_block "$else_block" "$mode"
            fi
            continue
        fi
        
        # for
        if is_for "$line"; then
            local count
            count=$(get_for_count "$line")
            ((i++))
            
            local loop_body=""
            while [[ $i -lt ${#lines[@]} ]]; do
                local sub
                sub=$(echo "${lines[$i]}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
                if [[ -z "$sub" ]]; then
                    ((i++)); break
                fi
                if is_echo "$sub" || is_if "$sub" || is_for "$sub" || is_func_call "$sub" || is_comment "$sub" || is_for_func "$sub" || [[ "$sub" == "shell;" ]]; then
                    break
                fi
                loop_body+="$sub"$'\n'
                ((i++))
            done
            
            local k
            for ((k=0; k<count; k++)); do
                process_block "$loop_body" "$mode"
            done
            continue
        fi
        
        # for func
        if is_for_func "$line"; then
            local count fname
            count=$(get_for_func_count "$line")
            fname=$(get_for_func_name "$line")
            if [[ -z "${FUNCS[$fname]}" ]]; then
                echo "错误: 未定义的函数 '$fname'" >&2
            else
                local k
                for ((k=0; k<count; k++)); do
                    process_block "${FUNCS[$fname]}" "$mode"
                done
            fi
            ((i++)); continue
        fi

        # ========== 新增：未知语法直接交给 Shell 执行 ==========
        if [[ "$mode" == "interpret" ]]; then
            eval "$line" 2>&1
        elif [[ "$mode" == "compile_c" ]]; then
            local escaped
            escaped=$(echo "$line" | sed 's/"/\\"/g')
            printf '    system("%s");\n' "$escaped"
        elif [[ "$mode" == "compile_sh" ]]; then
            echo "$line"
        fi
        # ====================================================

        ((i++))
    done
}

collect_functions() {
    local IFS=$'\n'
    local lines
    readarray -t lines <<< "$SOURCE"
    
    local i=0
    local in_func=0
    local func_name=""
    local func_body=""
    
    while [[ $i -lt ${#lines[@]} ]]; do
        local line="${lines[$i]}"
        line=$(echo "$line" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
        [[ -z "$line" ]] && ((i++)) && continue
        
        if is_comment "$line"; then
            ((i++)); continue
        fi
        
        if is_func_def "$line"; then
            if [[ $in_func -eq 1 ]]; then
                declare -g "FUNCS[$func_name]=$func_body"
            fi
            func_name=$(get_func_def_name "$line")
            func_body=""
            in_func=1
            ((i++)); continue
        fi
        
        if [[ $in_func -eq 1 ]]; then
            if is_func_def "$line" || is_func_call "$line" || is_echo "$line" || is_if "$line" || is_for "$line" || is_for_func "$line" || is_comment "$line" || [[ "$line" == "shell;" ]]; then
                declare -g "FUNCS[$func_name]=$func_body"
                in_func=0
                continue
            fi
            func_body+="$line"$'\n'
            ((i++)); continue
        fi
        
        ((i++))
    done
    
    if [[ $in_func -eq 1 ]]; then
        declare -g "FUNCS[$func_name]=$func_body"
    fi
}

execute_top_level() {
    local mode="$1"
    local IFS=$'\n'
    local lines
    readarray -t lines <<< "$SOURCE"
    
    local i=0
    while [[ $i -lt ${#lines[@]} ]]; do
        local line="${lines[$i]}"
        line=$(echo "$line" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
        [[ -z "$line" ]] && ((i++)) && continue
        
        if is_comment "$line"; then
            ((i++)); continue
        fi
        
        if is_func_def "$line"; then
            while [[ $i -lt ${#lines[@]} ]]; do
                local sub
                sub=$(echo "${lines[$i]}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
                if is_func_def "$sub" || is_func_call "$sub" || is_echo "$sub" || is_if "$sub" || is_for "$sub" || is_for_func "$sub" || is_comment "$sub" || [[ "$sub" == "shell;" ]]; then
                    break
                fi
                ((i++))
            done
            continue
        fi
        
        process_block "$line"$'\n' "$mode"
        ((i++))
    done
}

collect_functions

if [[ $COMPILE_C -eq 1 ]]; then
    if [[ -n "$OUTPUT_FILE" ]]; then
        {
            echo "/* Generated by echoi v$VERSION */"
            echo "#include <stdio.h>"
            echo ""
            echo "int main(void) {"
            execute_top_level "compile_c"
            echo "    return 0;"
            echo "}"
        } > "$OUTPUT_FILE"
        echo "已生成 C 文件: $OUTPUT_FILE"
        if [[ $RUN_AFTER -eq 1 ]]; then
            local out_bin="${OUTPUT_FILE%.c}"
            if gcc -o "$out_bin" "$OUTPUT_FILE" 2>/dev/null; then
                echo "已编译: $out_bin"
                echo "--- 运行结果 ---"
                "./$out_bin"
            else
                echo "GCC 编译失败" >&2
            fi
        fi
    else
        echo "/* Generated by echoi v$VERSION */"
        echo "#include <stdio.h>"
        echo ""
        echo "int main(void) {"
        execute_top_level "compile_c"
        echo "    return 0;"
        echo "}"
    fi
    
elif [[ $COMPILE_SH -eq 1 ]]; then
    if [[ -n "$OUTPUT_FILE" ]]; then
        {
            echo "#!/bin/bash"
            echo "# Generated by echoi v$VERSION"
            echo ""
            execute_top_level "compile_sh"
        } > "$OUTPUT_FILE"
        chmod +x "$OUTPUT_FILE"
        echo "已生成 Shell 文件: $OUTPUT_FILE"
        if [[ $RUN_AFTER -eq 1 ]]; then
            echo "--- 运行结果 ---"
            bash "$OUTPUT_FILE"
        fi
    else
        echo "#!/bin/bash"
        echo "# Generated by echoi v$VERSION"
        echo ""
        execute_top_level "compile_sh"
    fi
    
else
    execute_top_level "interpret"
fi
