#!/usr/bin/env bash
# validate-manifest.sh — si-minimax/v3 manifest 全字段校验
# 用法: bash validate-manifest.sh <manifest.json>
#   通过 → exit 0(输出 [PASS] 列表)
#   失败 → exit 1(输出 [FAIL] 列表,错误具体到字段,如 "pictures[2].engine 非法: foo")
# 依赖: jq(仅内置函数,无外部模块)
# 校验项编号对应 ~/.claude/skills/si-regen/schema/README.md 的 a-g(+h)

if [[ $# -ne 1 ]]; then
  echo "用法: bash validate-manifest.sh <manifest.json>"
  echo "校验 manifest 是否符合 si-minimax/v3 schema;通过 exit 0,失败 exit 1"
  exit 1
fi
MANIFEST="$1"

command -v jq >/dev/null 2>&1 || { echo "[FAIL] 依赖 jq 未安装"; exit 1; }
[[ -f "$MANIFEST" ]] || { echo "[FAIL] 文件不存在: $MANIFEST"; exit 1; }

FAILED=0
fail() { echo "[FAIL] $*"; FAILED=$((FAILED + 1)); }
pass() { echo "[PASS] $*"; }
warn() { echo "[WARN] $*"; }

# ---------- a) 顶层是合法 JSON 对象 ----------
if ! jq -e . "$MANIFEST" >/dev/null 2>&1; then
  echo "[FAIL] a) 顶层不是合法 JSON($MANIFEST 解析失败)"
  exit 1
fi
TYPE=$(jq -r 'type' "$MANIFEST")
if [[ "$TYPE" != "object" ]]; then
  echo "[FAIL] a) 顶层必须是 JSON 对象,实际类型: $TYPE"
  exit 1
fi
pass "a) 顶层是合法 JSON 对象"

# ---------- 前置: _meta / pictures 存在性 ----------
jq -e 'has("_meta")' "$MANIFEST" >/dev/null 2>&1 \
  && pass "_meta 存在" \
  || fail "缺少 _meta 对象"
jq -e 'has("pictures")' "$MANIFEST" >/dev/null 2>&1 \
  && pass "pictures 存在" \
  || fail "缺少 pictures 数组"

LEN=$(jq -r 'if (.pictures | type) == "array" then (.pictures | length) else "-" end' "$MANIFEST")

# ---------- b) _meta.schema == "si-minimax/v3" ----------
SCHEMA=$(jq -r '._meta.schema // "null"' "$MANIFEST")
if [[ "$SCHEMA" == "si-minimax/v3" ]]; then
  pass "b) _meta.schema == si-minimax/v3"
else
  fail "b) _meta.schema 非法: $SCHEMA(必须为 si-minimax/v3;旧版请重跑完整流程升级)"
fi

# ---------- c) _meta 基础字段 ----------
# source: 非空字符串
if jq -e '._meta.source | type == "string" and length > 0' "$MANIFEST" >/dev/null 2>&1; then
  pass "c) _meta.source 为非空字符串"
else
  fail "c) _meta.source 非法: $(jq -r '._meta.source // "null"' "$MANIFEST")(必须为非空字符串,文章规范化绝对路径)"
fi
# source_mtime: 整数(兼容纯数字字符串,真实 manifest 为 stat 字符串输出)
if jq -e '._meta.source_mtime | (type == "number" and (floor == .)) or (type == "string" and test("^[0-9]+$"))' "$MANIFEST" >/dev/null 2>&1; then
  pass "c) _meta.source_mtime 为整数($(jq -r '._meta.source_mtime // "null"' "$MANIFEST"))"
else
  fail "c) _meta.source_mtime 非法: $(jq -r '._meta.source_mtime // "null"' "$MANIFEST")(必须为整数或数字字符串,如 1783740240)"
fi
# source_size: 整数(同上)
if jq -e '._meta.source_size | (type == "number" and (floor == .)) or (type == "string" and test("^[0-9]+$"))' "$MANIFEST" >/dev/null 2>&1; then
  pass "c) _meta.source_size 为整数($(jq -r '._meta.source_size // "null"' "$MANIFEST"))"
else
  fail "c) _meta.source_size 非法: $(jq -r '._meta.source_size // "null"' "$MANIFEST")(必须为整数或数字字符串,如 13756)"
fi
# produced_at: 非空字符串
if jq -e '._meta.produced_at | type == "string" and length > 0' "$MANIFEST" >/dev/null 2>&1; then
  pass "c) _meta.produced_at 为非空字符串"
else
  fail "c) _meta.produced_at 非法: $(jq -r '._meta.produced_at // "null"' "$MANIFEST")(必须为非空字符串,ISO8601 如 2026-08-03T16:37:01+08:00)"
fi

# ---------- d) _meta.total 为整数且 == pictures 长度 ----------
if jq -e '._meta.total | type == "number" and (floor == .)' "$MANIFEST" >/dev/null 2>&1; then
  TOTAL=$(jq -r '._meta.total' "$MANIFEST")
  if [[ "$TOTAL" == "$LEN" ]]; then
    pass "d) _meta.total($TOTAL) == pictures 长度($LEN)"
  else
    fail "d) _meta.total($TOTAL) ≠ pictures 长度($LEN),必须一致"
  fi
else
  fail "d) _meta.total 非法: $(jq -r '._meta.total // "null"' "$MANIFEST")(必须为整数)"
fi

# ---------- e) pictures 数组与逐张字段 ----------
if [[ "$(jq -r '.pictures | type' "$MANIFEST")" == "array" ]]; then
  if [[ "$LEN" -gt 0 ]]; then
    pass "e) pictures 为非空数组(共 $LEN 张)"
    # id 为正整数
    BAD=$(jq -r '[((.pictures // []) | to_entries[]) | select(((.value.id | type) != "number") or ((.value.id | floor) != .value.id) or (.value.id <= 0)) | "pictures[\(.key)].id=\(.value.id // "null")"] | join("; ")' "$MANIFEST")
    if [[ -n "$BAD" ]]; then
      fail "e) id 必须为正整数: $BAD"
    else
      pass "e) 每张 id 为正整数"
    fi
    # id 唯一
    if jq -e '([.pictures[].id] | unique | length) == (.pictures | length)' "$MANIFEST" >/dev/null 2>&1; then
      pass "e) id 唯一(无重复)"
    else
      DUP=$(jq -r '[.pictures[].id] | group_by(.) | map(select(length > 1) | .[0]) | map(tostring) | join(", ")' "$MANIFEST")
      fail "e) id 重复: $DUP(每张 id 必须唯一)"
    fi
    # id 从 1 连续递增(建议项,非强制)
    jq -e '([.pictures[].id] | sort) == [range(1; (.pictures | length) + 1)]' "$MANIFEST" >/dev/null 2>&1 \
      || warn "e) id 未严格从 1 连续递增(当前: $(jq -c '[.pictures[].id]' "$MANIFEST"));建议按图片编号 1..N 排列"
    # engine ∈ 枚举(注意:jq 函数参数在调用点求值,须先用 as 绑定元素,不能直接 index(.value.engine))
    BAD=$(jq -r '[((.pictures // []) | to_entries[]) as $e | select((["gemini","excalidraw","mermaid"] | index($e.value.engine)) | not) | "pictures[\($e.key)].engine 非法: \($e.value.engine // "null")"] | join("; ")' "$MANIFEST")
    if [[ -n "$BAD" ]]; then
      fail "e) $BAD(允许 gemini|excalidraw|mermaid)"
    else
      pass "e) 每张 engine 均在枚举内"
    fi
    # topic / content / anchor: 非空字符串
    for F in topic content anchor; do
      BAD=$(jq -r --arg F "$F" '[((.pictures // []) | to_entries[]) | select(((.value[$F] | type) != "string") or ((.value[$F] | length) == 0)) | "pictures[\(.key)].\($F) 为空或非字符串"] | join("; ")' "$MANIFEST")
      if [[ -n "$BAD" ]]; then
        fail "e) $BAD"
      else
        pass "e) 每张 $F 为非空字符串"
      fi
    done
    # status ∈ 枚举(同 engine,as 绑定)
    BAD=$(jq -r '[((.pictures // []) | to_entries[]) as $e | select((["planned","generated","failed"] | index($e.value.status)) | not) | "pictures[\($e.key)].status 非法: \($e.value.status // "null")"] | join("; ")' "$MANIFEST")
    if [[ -n "$BAD" ]]; then
      fail "e) $BAD(允许 planned|generated|failed)"
    else
      pass "e) status 均在枚举内"
    fi
  else
    fail "e) pictures 为空数组:必须至少 1 张"
  fi
else
  fail "e) pictures 必须为数组,实际类型: $(jq -r '.pictures | type' "$MANIFEST")"
fi

# ---------- f) source_file 条件必填 ----------
BAD=$(jq -r '[((.pictures // []) | to_entries[]) | select(.value.engine == "mermaid" or .value.engine == "excalidraw") | select(((.value.source_file | type) != "string") or ((.value.source_file | length) == 0)) | "pictures[\(.key)](engine=\(.value.engine // "null")) source_file 必填非空"] | join("; ")' "$MANIFEST")
if [[ -n "$BAD" ]]; then
  fail "f) $BAD"
else
  pass "f) mermaid/excalidraw 的 source_file 均必填非空(gemini 可为空)"
fi

# ---------- g) by_engine 一致性 ----------
if jq -e '._meta.by_engine | type == "object"' "$MANIFEST" >/dev/null 2>&1; then
  # 键 ∈ 枚举(as 绑定,避免 index(.) 求值歧义)
  BAD=$(jq -r '[(._meta.by_engine | keys[]) as $k | select((["gemini","excalidraw","mermaid"] | index($k)) | not) | $k] | join(", ")' "$MANIFEST")
  if [[ -n "$BAD" ]]; then
    fail "g) by_engine 键非法: $BAD(允许 gemini|excalidraw|mermaid)"
  else
    pass "g) by_engine 键均在枚举内"
  fi
  # 各值非负整数
  if jq -e '._meta.by_engine | to_entries | all(.value | type == "number" and (floor == .) and . >= 0)' "$MANIFEST" >/dev/null 2>&1; then
    pass "g) by_engine 各值均为非负整数"
  else
    fail "g) by_engine 存在非整数或负数值: $(jq -c '._meta.by_engine' "$MANIFEST")"
  fi
  # 之和 == total
  SUM=$(jq -r '(._meta.by_engine.gemini // 0) + (._meta.by_engine.excalidraw // 0) + (._meta.by_engine.mermaid // 0)' "$MANIFEST")
  if jq -e '._meta.total | type == "number"' "$MANIFEST" >/dev/null 2>&1; then
    TOTAL=$(jq -r '._meta.total' "$MANIFEST")
    if [[ "$SUM" == "$TOTAL" ]]; then
      pass "g) by_engine 各值之和($SUM) == _meta.total($TOTAL)"
    else
      fail "g) by_engine 各值之和($SUM) ≠ _meta.total($TOTAL)"
    fi
  fi
else
  fail "g) _meta.by_engine 非法: 必须为对象(缺失或类型错误)"
fi

# ---------- h) source_prompt(附加) ----------
BAD=$(jq -r '[((.pictures // []) | to_entries[]) | select(.value | has("source_prompt")) | select((.value.source_prompt | type) != "string") | "pictures[\(.key)].source_prompt 类型非法: \(.value.source_prompt | type)"] | join("; ")' "$MANIFEST")
if [[ -n "$BAD" ]]; then
  fail "h) $BAD(source_prompt 必须为字符串)"
else
  pass "h) source_prompt 均为字符串(若存在)"
fi
# gemini 空 source_prompt → 警告(重生时无法取 prompt),不阻塞
GEM=$(jq -r '[((.pictures // []) | to_entries[]) | select(.value.engine == "gemini") | select(((.value.source_prompt // "") | length) == 0) | .key] | join(", ")' "$MANIFEST")
if [[ -n "$GEM" ]]; then
  warn "h) 警告: gemini 图片 [索引 $GEM] 的 source_prompt 为空,重生时无法取 prompt(建议写完整文本或 /tmp 路径引用)"
fi

# ---------- 汇总 ----------
echo
if [[ $FAILED -gt 0 ]]; then
  echo "[结果] 校验失败($FAILED 项),请按上方 [FAIL] 修正后重试"
  exit 1
fi
echo "[结果] 校验通过: manifest 符合 si-minimax/v3 schema"
exit 0
