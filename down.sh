#!/usr/bin/env bash
# ============================================================================
#  down.sh — 올린 것을 내립니다 (깃허브 저장소 · 웹사이트 · 로컬 폴더)
# ----------------------------------------------------------------------------
#      bash down.sh 이름            무엇이 지워지는지 보여만 줍니다
#      bash down.sh 이름 --yes      실제로 지웁니다
#      bash down.sh 이름 --yes --keep-local    폴더는 남깁니다
#      bash down.sh 이름 --yes --keep-repo     저장소는 남깁니다
#
#  ★ 되돌릴 수 없습니다 ★
#    그래서 --yes 없이 실행하면 지우지 않고 목록만 보여 줍니다.
#    무엇이 지워지는지 먼저 확인하고 나서 --yes 를 붙이세요.
#
#    Claude 가 대신 실행할 때도 마찬가지입니다. 먼저 --yes 없이 돌려
#    사용자에게 무엇이 지워지는지 보여 주고, 그렇게 하겠다는 답을 들은
#    뒤에 --yes 를 붙이세요. 대화에서의 그 답이 확인 절차입니다.
# ============================================================================

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

NAME="${1:-}"
[ -z "$NAME" ] && die "사용법: bash down.sh <이름> [--yes] [--keep-local] [--keep-repo]"
shift

GO=0; KEEP_LOCAL=0; KEEP_REPO=0
while [ $# -gt 0 ]; do
  case "$1" in
    --yes|-y)     GO=1 ;;
    --keep-local) KEEP_LOCAL=1 ;;
    --keep-repo)  KEEP_REPO=1 ;;
    *) die "모르는 옵션입니다: $1" ;;
  esac
  shift
done

ensure_ready
NAME="$(to_slug "$NAME" || printf '%s' "$NAME")"

# 지우고 나면 주소를 알아낼 방법이 없으니 먼저 기억해 둡니다.
# (추측한 주소는 남의 사이트일 수 있어 쓰지 않습니다.)
SITE_BEFORE="$(site_url "$NAME")"

REPO_INFO="$("$GH" api "/repos/$GH_OWNER/$NAME" \
  --jq '"\(.full_name)  [\(.visibility)]  만든날 \(.created_at[0:10])  \(.size)KB"' \
  2>/dev/null)" || REPO_INFO=""

# 로컬 폴더는 '이 이름의 저장소를 origin 으로 가진 폴더' 를 찾습니다.
LOCAL=""
if [ -d .git ] && git remote get-url origin 2>/dev/null | grep -q "/$NAME\(\.git\)\?$"; then
  LOCAL="$PWD"
fi

say ""
say "지울 것"
say "────────────────────────────────────────────"
[ "$KEEP_REPO" -eq 0 ] && say "  저장소  ${REPO_INFO:-(없음)}" || say "  저장소  건너뜀"
say "  웹사이트  ${SITE_BEFORE:-(없음)}"
if [ "$KEEP_LOCAL" -eq 0 ] && [ -n "$LOCAL" ]; then say "  폴더    $LOCAL"; else say "  폴더    건너뜀"; fi
say "────────────────────────────────────────────"

if [ "$GO" -eq 0 ]; then
  say ""
  say "  아직 아무것도 지우지 않았습니다."
  say "  정말 지우려면 뒤에 --yes 를 붙여 주세요:"
  say ""
  say "      bash down.sh $NAME --yes"
  say ""
  exit 0
fi

say ""
if [ "$KEEP_REPO" -eq 0 ] && [ -n "$REPO_INFO" ]; then
  step "깃허브 저장소를 지우는 중..."
  "$GH" repo delete "$GH_OWNER/$NAME" --yes >/dev/null 2>&1 \
    || step "저장소를 지우지 못했습니다 (권한이 없을 수 있습니다)"
fi

if [ -n "$SITE_BEFORE" ]; then
  step "웹사이트를 내리는 중..."
  echo "y" | vc project rm "$NAME" >/dev/null 2>&1 || true
fi

LOCAL_LEFT=""
if [ "$KEEP_LOCAL" -eq 0 ] && [ -n "$LOCAL" ]; then
  step "로컬 폴더를 지우는 중..."
  # 폴더 밖으로 나온 뒤에 지웁니다.
  cd "$(dirname "$LOCAL")" 2>/dev/null || true
  # ※ 윈도우는 그 폴더를 열어 둔 창이 있으면 지우지 못합니다 ※
  #   이 명령을 그 폴더 안에서 실행했다면 부르는 쪽 셸이 잡고 있어서
  #   "Device or resource busy" 가 납니다. 여기서 스크립트가 죽으면
  #   저장소·사이트는 이미 지워졌는데 결과 보고를 못 하게 되므로,
  #   실패해도 넘어가고 마지막에 알려 줍니다.
  if ! rm -rf "$LOCAL" 2>/dev/null; then
    LOCAL_LEFT="$LOCAL"
  fi
fi

# 정말 지워졌는지 확인합니다. "지웠습니다" 라고만 하지 않습니다.
step "확인하는 중..."
if "$GH" api "/repos/$GH_OWNER/$NAME" >/dev/null 2>&1; then
  REPO_NOW="아직 남아 있습니다"
else
  REPO_NOW="지워짐"
fi

SITE_NOW="확인 안 함"
if [ -n "$SITE_BEFORE" ]; then
  # 버셀은 지운 직후 몇 초 동안 예전 내용을 계속 내려줍니다.
  # 바로 확인하면 "아직 살아 있다" 고 잘못 보고하게 되므로 몇 번 다시 봅니다.
  CODE="000"
  for _ in 1 2 3 4 5; do
    CODE="$(http_code "$SITE_BEFORE")"
    [ "$CODE" = "404" ] && break
    sleep 3
  done
  if [ "$CODE" = "404" ]; then SITE_NOW="내려감"
  else SITE_NOW="아직 응답함 (HTTP $CODE) — 잠시 뒤 다시 확인해 보세요"; fi
fi

say ""
say "────────────────────────────────────────────"
say "  저장소    $REPO_NOW"
say "  웹사이트  $SITE_NOW"
if [ -n "$LOCAL_LEFT" ]; then
  say "  폴더      지우지 못했습니다"
  say ""
  say "  이 폴더를 열어 둔 창이 있으면 윈도우가 지우지 못합니다."
  say "  탐색기·편집기·터미널에서 닫은 뒤 직접 지워 주세요:"
  say "    $LOCAL_LEFT"
fi
say "────────────────────────────────────────────"
