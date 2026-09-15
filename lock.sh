#!/usr/bin/env bash
# ============================================================================
#  lock.sh — 올린 것을 나만 보게 잠그거나, 다시 공개합니다
# ----------------------------------------------------------------------------
#      bash lock.sh 이름 on         잠그기 (나만 보기)
#      bash lock.sh 이름 off        공개하기 (누구나 보기)
#      bash lock.sh 이름            지금 상태만 확인
#      bash lock.sh 이름 on --repo  깃허브 저장소까지 함께 비공개로
#
#  ★ 알아 둘 것 ★
#    깃허브 저장소를 비공개로 뒀다고 웹페이지까지 가려지는 것이 아닙니다.
#    코드와 웹페이지는 따로 놉니다. 배포된 주소는 아는 사람이면 누구나
#    열 수 있습니다. 가리려면 이 명령으로 잠가야 합니다.
#
#    반대로 과제 제출처럼 남이 링크를 열어야 하는 것은 잠그면 안 됩니다.
#    잠근 사이트는 남에게 버셀 로그인 화면만 보여 줍니다.
#
#  비밀번호로 잠그는 기능은 버셀 유료 요금제 기능입니다.
#  여기서 쓰는 방식(Vercel Authentication)은 무료입니다.
# ============================================================================

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

NAME="${1:-}"
[ -z "$NAME" ] && die "사용법: bash lock.sh <이름> [on|off] [--repo]"
shift

ACTION="status"
ALSO_REPO=0
while [ $# -gt 0 ]; do
  case "$1" in
    on|off) ACTION="$1" ;;
    --repo) ALSO_REPO=1 ;;
    *) die "모르는 옵션입니다: $1" ;;
  esac
  shift
done

ensure_ready
NAME="$(to_slug "$NAME" || printf '%s' "$NAME")"

# 버셀 도구는 윈도우 프로그램이라 "/tmp/파일" 을 "C:\tmp\파일" 로 읽습니다.
# 그래서 임시 파일을 도구 폴더 안에 만들고 winpath 로 변환해 넘깁니다.
TMP="$TOOLS/.lock_$$.json"
trap 'rm -f "$TMP"' EXIT

if [ "$ACTION" != "status" ]; then
  if [ "$ACTION" = "on" ]; then
    # deploymentType "all" 이어야 정식 주소까지 잠깁니다.
    # 버셀 기본값은 "all_except_custom_domains" 라, 잠근 줄 알았는데
    # 정식 주소는 그대로 열려 있는 일이 생깁니다.
    printf '{"ssoProtection":{"deploymentType":"all"}}' > "$TMP"
    say "나만 볼 수 있게 잠그는 중..."
  else
    printf '{"ssoProtection":null}' > "$TMP"
    say "누구나 볼 수 있게 여는 중..."
  fi
  vc api "/v9/projects/$NAME" -X PATCH --input "$(winpath "$TMP")" >/dev/null 2>&1 \
    || die "설정을 바꾸지 못했습니다. 이름이 맞는지 확인해 주세요: $NAME"

  if [ "$ALSO_REPO" -eq 1 ]; then
    if [ "$ACTION" = "on" ]; then V=private; else V=public; fi
    "$GH" repo edit "$GH_OWNER/$NAME" --visibility "$V" \
          --accept-visibility-change-consequences >/dev/null 2>&1 \
      || step "저장소 공개 범위는 바꾸지 못했습니다 (권한 또는 이름 확인)"
  fi
fi

# 설정값을 믿지 않고, 로그인하지 않은 상태로 실제로 열어 봅니다.
SITE="$(site_url "$NAME")"
if [ -z "$SITE" ]; then
  STATE="배포를 찾을 수 없습니다 (아직 안 올렸거나 이름이 다릅니다)"
  SEEN=""; SITE="—"
else
  SEEN="$(page_title "$SITE")"
  case "$SEEN" in
    *Login*) STATE="나만 보기 — 남에게는 로그인 화면만 보입니다" ;;
    "")      STATE="응답 없음" ;;
    *)       STATE="공개 — 주소를 아는 누구나 열 수 있습니다" ;;
  esac
fi

REPOVIS="$("$GH" api "/repos/$GH_OWNER/$NAME" --jq .visibility 2>/dev/null)" || REPOVIS=""
[ -n "$REPOVIS" ] || REPOVIS="(저장소 없음)"

say ""
say "────────────────────────────────────────────"
say "  주소    $SITE"
say "  상태    $STATE"
say "  저장소  $REPOVIS"
say "────────────────────────────────────────────"
