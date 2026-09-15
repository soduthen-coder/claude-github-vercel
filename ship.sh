#!/usr/bin/env bash
# ============================================================================
#  ship.sh — 지금 폴더에 있는 것을 깃허브에 올리고 버셀로 주소를 만듭니다
# ----------------------------------------------------------------------------
#  이 도구의 전제
#    클로드에게 무언가 만들어 달라고 해서 파일이 생겼습니다.
#    그 결과물을 인터넷에 올릴 것인가 — 그게 이 도구가 답하는 질문입니다.
#    빈 사이트를 새로 만드는 도구가 아닙니다. 이미 있는 것을 올리는 도구입니다.
#
#  사용법
#      bash ship.sh                     지금 폴더를 올립니다 (폴더 이름을 씁니다)
#      bash ship.sh --name 이름          이름을 정해서 올립니다
#      bash ship.sh --dir 경로           다른 폴더를 올립니다
#      bash ship.sh --public            저장소도 공개로 만듭니다
#      bash ship.sh --lock              올린 뒤 바로 잠급니다 (나만 보기)
#      bash ship.sh "메모"               커밋 메모를 남깁니다
#
#  처음이든 열 번째든 같은 명령입니다.
#    처음  → 저장소를 만들고 올리고 배포합니다
#    다음  → 바뀐 것만 올리고 다시 배포합니다
#  준비가 안 되어 있으면 알아서 갖춥니다. 이미 되어 있으면 건너뜁니다.
# ============================================================================

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

DIR="$PWD"
NAME=""
MSG=""
VIS="--private"     # 기본은 비공개. 실수로 공개되는 사고를 막기 위해서입니다.
LOCK=0

while [ $# -gt 0 ]; do
  case "$1" in
    --dir)     DIR="${2:-}"; shift ;;
    --name)    NAME="${2:-}"; shift ;;
    --public)  VIS="--public" ;;
    --private) VIS="--private" ;;
    --lock)    LOCK=1 ;;
    -*)        die "모르는 옵션입니다: $1" ;;
    *)         MSG="$1" ;;
  esac
  shift
done

cd "$DIR" 2>/dev/null || die "폴더를 찾을 수 없습니다: $DIR"
DIR="$PWD"

# 올릴 것이 있는지 봅니다. 빈 폴더를 올리면 빈 사이트가 나옵니다.
if [ -z "$(ls -A . 2>/dev/null | grep -v '^\.git$' | head -1)" ]; then
  die "이 폴더에 올릴 파일이 없습니다: $DIR
  먼저 클로드에게 무언가 만들어 달라고 한 뒤에 올려 주세요."
fi

say ""
say "지금 폴더를 올립니다"
say "  $DIR"
say ""

# ── 1. 준비 (이미 되어 있으면 건너뜀) ─────────────────────────────────────
ensure_ready

# ── 2. 이름 정하기 ────────────────────────────────────────────────────────
#     ★ 이미 올린 폴더면 그때 쓴 이름을 그대로 씁니다 ★
#     안 그러면 두 번째 실행에서 폴더 이름으로 저장소를 또 만들어 버립니다.
#     (실제로 그렇게 만들어 놓고 중복 저장소가 생기는 걸 보고 고쳤습니다.)
#     이미 연결된 origin 주소가 가장 확실한 근거입니다.
#
#     ※ git -C "$DIR" 를 쓰면 안 됩니다 ※
#       MSYS_NO_PATHCONV=1 때문에 "/c/Users/..." 가 그대로 git 에 넘어가고,
#       git 은 윈도우 프로그램이라 그 경로를 읽지 못합니다. 조용히 실패해서
#       "origin 이 없다" 고 판단해 버립니다. 이미 cd 로 들어와 있으므로
#       -C 없이 그냥 부르면 됩니다.
if [ -z "$NAME" ] && git remote get-url origin >/dev/null 2>&1; then
  NAME="$(git remote get-url origin | sed 's#.*/##; s#\.git$##')"
  step "이미 올린 폴더입니다. 같은 이름으로 갱신합니다: $NAME"
fi

#     그래도 이름이 없으면 폴더 이름을 씁니다. 한글이면 로마자로 바꿉니다.
RAW="${NAME:-$(basename "$DIR")}"
NAME="$(to_slug "$RAW" || true)"
[ -n "$NAME" ] || die "이 이름은 저장소 이름으로 쓸 수 없습니다: '$RAW'
  --name 으로 영문 이름을 정해 주세요.  예)  bash ship.sh --name my-page"
if [ "$NAME" != "$RAW" ]; then
  step "이름 '$RAW' → '$NAME' (깃허브가 한글 이름을 받지 못합니다)"
fi

# ── 3. 비밀 파일 걸러내기 ─────────────────────────────────────────────────
#     한 번 올라간 것은 지워도 커밋 기록에 남습니다. 올리기 전에 막습니다.
if [ ! -f .gitignore ]; then
  cat > .gitignore <<'IGN'
# 열쇠·비밀 파일 — 올라가면 지워도 기록에 남습니다
.env
.env.*
*.pem
*.key
# 도구가 만드는 로컬 설정 (토큰이 들어 있습니다)
.vercel/
# 운영체제·편집기 잡파일
.DS_Store
Thumbs.db
.vscode/
.idea/
node_modules/
IGN
  step ".gitignore 를 만들어 비밀 파일을 걸러냈습니다"
fi

# ── 4. 깃허브에 올리기 ────────────────────────────────────────────────────
if [ ! -d .git ]; then
  step "이 폴더를 기록 대상으로 만듭니다"
  git init -q
  git config core.quotepath false
  git config user.name  "$GIT_NAME"
  git config user.email "$GIT_EMAIL"
  git branch -M main
fi

if [ -n "$(git status --porcelain)" ]; then
  git add -A
  git commit -q -m "${MSG:-올림}"
  step "바뀐 내용을 기록했습니다"
else
  step "바뀐 내용이 없습니다"
fi

if git remote get-url origin >/dev/null 2>&1; then
  step "깃허브에 올리는 중..."
  git push -q 2>/dev/null || git push -q -u origin main
else
  step "깃허브 저장소를 만드는 중... (${VIS#--})"
  "$GH" repo create "$NAME" $VIS --source=. --remote=origin --push >/dev/null 2>&1 \
    || die "깃허브 저장소를 만들지 못했습니다.
  같은 이름이 이미 있는지 확인해 주세요:  https://github.com/$GH_OWNER?tab=repositories
  다른 이름으로 하려면:  bash ship.sh --name 다른이름"
fi

# ── 5. 버셀에 배포 ────────────────────────────────────────────────────────
#     깃 연동을 걸지 않고 여기서 바로 올립니다. 연동을 쓰려면 버셀 깃허브 앱에
#     저장소 접근 권한을 사람이 직접 켜야 해서, 새 저장소마다 막힙니다.
step "인터넷에 올리는 중..."
OUT="$TOOLS/.out_$$.txt"; ERR="$TOOLS/.err_$$.txt"
trap 'rm -f "$OUT" "$ERR"' EXIT
if ! vc deploy --prod --yes --name "$NAME" >"$OUT" 2>"$ERR"; then
  say ""
  say "배포 실패:"
  tail -6 "$ERR"
  die "버셀 배포에 실패했습니다."
fi
SITE="$(deployed_url "$ERR" "$OUT")"

# ── 6. 잠그기 (요청했을 때만) ─────────────────────────────────────────────
if [ "$LOCK" -eq 1 ]; then
  step "나만 볼 수 있게 잠그는 중..."
  TMP="$TOOLS/.lock_$$.json"
  printf '{"ssoProtection":{"deploymentType":"all"}}' > "$TMP"
  vc api "/v9/projects/$NAME" -X PATCH --input "$(winpath "$TMP")" >/dev/null 2>&1 \
    || step "잠금 설정에 실패했습니다. 나중에:  bash lock.sh $NAME on"
  rm -f "$TMP"
fi

# ── 7. 진짜 열리는지 확인 ─────────────────────────────────────────────────
#     "올렸습니다" 라고만 하지 않고 실제로 열어 봅니다.
SEEN="$(page_title "$SITE")"
case "$SEEN" in
  *Login*) STATE="나만 보기 (남에게는 로그인 화면만 보입니다)" ;;
  "")      STATE="확인 못 함 — 잠시 뒤 다시 열어 보세요" ;;
  *)       STATE="공개 (주소를 아는 누구나 열 수 있습니다)" ;;
esac

# 저장소 주소는 짐작하지 말고 실제로 연결된 곳에서 읽습니다.
#   --name 을 줘도 이미 연결된 origin 이 있으면 push 는 그쪽으로 갑니다.
#   그런데 화면에는 --name 을 찍고 있어서, 엉뚱한 저장소를 올린 것처럼
#   보이는 일이 있었습니다.
REPO_URL="$(git remote get-url origin 2>/dev/null | sed 's#\.git$##')" || REPO_URL=""
REPO_VIS="$("$GH" api "/repos/$GH_OWNER/$(basename "${REPO_URL:-x}")" --jq .visibility 2>/dev/null)" || REPO_VIS=""

say ""
say "────────────────────────────────────────────"
say "  올렸습니다"
say ""
say "  주소    $SITE"
say "  상태    $STATE"
say "  저장소  ${REPO_URL:-(없음)}${REPO_VIS:+  ($REPO_VIS)}"
say "────────────────────────────────────────────"
say ""
say "  고친 뒤 다시 올리기   bash ship.sh"
say "  나만 보기 / 공개      bash lock.sh $NAME on|off"
say "  내리기                bash down.sh $NAME --yes"
say ""
