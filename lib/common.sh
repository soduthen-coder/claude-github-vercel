#!/usr/bin/env bash
# ============================================================================
#  공통 설정 · 공통 함수
# ----------------------------------------------------------------------------
#  직접 실행하지 않습니다. ship.sh / lock.sh / down.sh 가 불러다 씁니다.
#
#  하는 일
#    1) gh(깃허브 도구) 와 vercel(버셀 도구) 위치 찾기
#    2) 없으면 설치, 로그인 안 되어 있으면 로그인  → ensure_ready()
#    3) 계정 정보 기억 (config.sh)
#    4) 여러 스크립트가 함께 쓰는 도우미 함수
#
#  ★ 이 도구의 목표 ★
#    사람이 승인 창을 마주치는 횟수를 0 에 가깝게 만드는 것.
#    최초 로그인 두 번만 사람이 하고, 그 뒤로는 전부 자동입니다.
# ============================================================================

# 엄격 모드: 실패를 조용히 지나치지 않습니다.
set -euo pipefail

# Git Bash 는 "/v9/projects" 같은 문자열을 파일 경로로 오해해 멋대로 바꿉니다.
# 버셀 API 주소를 넘길 때 깨지므로 변환을 끕니다. (맥·리눅스는 영향 없음)
export MSYS_NO_PATHCONV=1

TOOLS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="$TOOLS/config.sh"
export TOOLS CONFIG_FILE

say()  { printf '%s\n' "$*"; }
step() { printf '  · %s\n' "$*"; }
die()  { printf '\n[멈춤] %s\n' "$*" >&2; exit 1; }

# ----------------------------------------------------------------------------
# 도구 찾기
#   winget 으로 막 설치하면 PATH 에 바로 안 잡힙니다. 흔한 경로를 뒤집니다.
# ----------------------------------------------------------------------------
find_gh() {
  command -v gh 2>/dev/null && return
  local c
  for c in "$HOME/AppData/Local/Microsoft/WinGet/Packages"/GitHub.cli_*/bin/gh.exe \
           "/c/Program Files/GitHub CLI/gh.exe" "/opt/homebrew/bin/gh" \
           "/usr/local/bin/gh" "/usr/bin/gh"; do
    [ -x "$c" ] && { printf '%s' "$c"; return; }
  done
  return 1
}
find_vercel() { command -v vercel 2>/dev/null && return; return 1; }

GH="$(find_gh || true)"
VERCEL="$(find_vercel || true)"
export GH VERCEL

# 기억해 둔 계정 정보 (있으면)
if [ -f "$CONFIG_FILE" ]; then
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
fi
: "${GH_OWNER:=}"; : "${VERCEL_SCOPE:=}"; : "${GIT_NAME:=}"; : "${GIT_EMAIL:=}"
export GH_OWNER VERCEL_SCOPE GIT_NAME GIT_EMAIL

# ----------------------------------------------------------------------------
# winpath : 윈도우 프로그램에 넘길 경로로 바꿉니다.
#   Git Bash 안의 "/c/Users/..." 를 node·vercel 같은 윈도우 프로그램은
#   읽지 못합니다. "C:/Users/..." 형태여야 합니다.
# ----------------------------------------------------------------------------
winpath() {
  if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi
}

# ----------------------------------------------------------------------------
# ensure_ready : 준비가 안 되어 있으면 알아서 갖춥니다.
#
#   이미 되어 있는 단계는 건너뜁니다. 그래서 처음 쓰는 사람도, 다 갖춘
#   사람도 같은 명령 하나만 실행하면 됩니다.
#
#   ※ 확인은 한 번씩만 합니다. `vercel whoami` 는 3초 넘게 걸려서,
#     같은 확인을 두 번 하면 그만큼 그냥 버리게 됩니다.
# ----------------------------------------------------------------------------
ensure_ready() {
  local os; os="$(uname -s)"

  # --- git · Node.js : 없으면 설치를 시도합니다 --------------------------
  if ! command -v git >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
    case "$os" in
      MINGW*|MSYS*|CYGWIN*)
        command -v winget >/dev/null 2>&1 || die \
"git 과 Node.js 가 필요한데 자동 설치를 할 수 없습니다.
  직접 설치해 주세요:  https://git-scm.com/downloads , https://nodejs.org
  설치 뒤 터미널을 껐다 켜고 다시 실행하세요."
        command -v git >/dev/null 2>&1 || { step "git 설치 중..."
          winget install --id Git.Git -e --accept-package-agreements \
            --accept-source-agreements --disable-interactivity >/dev/null 2>&1 || true; }
        command -v npm >/dev/null 2>&1 || { step "Node.js 설치 중..."
          winget install --id OpenJS.NodeJS.LTS -e --accept-package-agreements \
            --accept-source-agreements --disable-interactivity >/dev/null 2>&1 || true; }
        ;;
      Darwin)
        command -v brew >/dev/null 2>&1 || die \
"git 과 Node.js 가 필요합니다. Homebrew 를 먼저 설치해 주세요: https://brew.sh"
        step "git · Node.js 설치 중..."
        brew install git node >/dev/null 2>&1 || true ;;
      Linux)
        step "git · Node.js 설치 중..."
        if   command -v apt >/dev/null 2>&1; then sudo apt update -qq && sudo apt install -y git nodejs npm
        elif command -v dnf >/dev/null 2>&1; then sudo dnf install -y git nodejs
        else die "git 과 Node.js 를 직접 설치해 주세요."; fi ;;
    esac
    command -v git >/dev/null 2>&1 || die \
"git 을 설치했지만 아직 인식되지 않습니다. 터미널을 껐다 켜고 다시 실행해 주세요."
    command -v npm >/dev/null 2>&1 || die \
"Node.js 를 설치했지만 아직 인식되지 않습니다. 터미널을 껐다 켜고 다시 실행해 주세요."
  fi

  # --- gh · vercel : 없으면 설치 -----------------------------------------
  if [ -z "$GH" ]; then
    step "깃허브 도구 설치 중..."
    case "$os" in
      MINGW*|MSYS*|CYGWIN*)
        winget install --id GitHub.cli -e --scope user --accept-package-agreements \
          --accept-source-agreements --disable-interactivity >/dev/null 2>&1 \
          || die "깃허브 도구 설치 실패. https://cli.github.com 에서 직접 설치해 주세요." ;;
      Darwin) brew install gh >/dev/null 2>&1 || die "깃허브 도구 설치 실패" ;;
      Linux)
        if   command -v apt >/dev/null 2>&1; then sudo apt install -y gh
        elif command -v dnf >/dev/null 2>&1; then sudo dnf install -y gh
        else die "깃허브 도구를 직접 설치해 주세요: https://cli.github.com"; fi ;;
    esac
    GH="$(find_gh || true)"
    [ -n "$GH" ] || die "깃허브 도구를 설치했지만 찾지 못했습니다. 터미널을 껐다 켜고 다시 실행해 주세요."
  fi
  if [ -z "$VERCEL" ]; then
    step "버셀 도구 설치 중... (1~2분 걸릴 수 있습니다)"
    npm install -g vercel >/dev/null 2>&1 || die "버셀 도구 설치 실패"
    VERCEL="$(find_vercel || true)"
    [ -n "$VERCEL" ] || die "버셀 도구를 설치했지만 찾지 못했습니다. 터미널을 껐다 켜고 다시 실행해 주세요."
  fi

  # --- 로그인 : 여기만 사람이 직접 합니다 ---------------------------------
  if ! "$GH" auth status >/dev/null 2>&1; then
    say ""
    say "  깃허브 로그인이 필요합니다. 이번 한 번만 하면 됩니다."
    say "  계정이 없다면 먼저 만들어 주세요 (무료): https://github.com/signup"
    say "  브라우저가 열리면 화면의 8자리 코드를 넣고 승인해 주세요."
    say ""
    "$GH" auth login --hostname github.com --git-protocol https --web \
          --scopes "repo,delete_repo" \
      || die "깃허브 로그인에 실패했습니다. 계정을 만든 뒤 다시 실행해 주세요."
  fi
  if ! "$VERCEL" whoami >/dev/null 2>&1; then
    say ""
    say "  버셀 로그인이 필요합니다. 이번 한 번만 하면 됩니다."
    say "  계정이 없다면 https://vercel.com/signup 에서"
    say "  \"Continue with GitHub\" 을 고르면 깃허브 계정으로 바로 가입됩니다."
    say "  (2단계 인증은 설정하지 않아도 됩니다.)"
    say ""
    "$VERCEL" login || die "버셀 로그인에 실패했습니다. 계정을 만든 뒤 다시 실행해 주세요."
  fi

  # --- 계정 정보 기억 : 다음부터 안 묻습니다 ------------------------------
  if [ ! -f "$CONFIG_FILE" ]; then
    GH_OWNER="$("$GH" api /user --jq .login)"
    GIT_EMAIL="$("$GH" api /user --jq '.email // ""')"
    [ -n "$GIT_EMAIL" ] || GIT_EMAIL="$GH_OWNER@users.noreply.github.com"
    # ★ 함정 ★ vercel 은 목록 표를 stdout 이 아니라 stderr 로 냅니다.
    #   2>/dev/null 로 버리면 표가 통째로 사라집니다.
    VERCEL_SCOPE="$("$VERCEL" teams ls 2>&1 \
      | sed 's/\r//' | sed 's/^[√>*✔•]\+[[:space:]]*//' | grep -vE '^\s*<' \
      | awk '$1!="" && $1!="id" && $1 !~ /^(Vercel|Fetching|Error|Retrieving)/ && $2!="" {print $1; exit}' \
      || true)"
    cat > "$CONFIG_FILE" <<CFG
#!/usr/bin/env bash
# 이 파일은 자동으로 만들어졌습니다. 아이디만 들어 있고 비밀번호·토큰은 없습니다.
GH_OWNER="$GH_OWNER"
GIT_NAME="$GH_OWNER"
GIT_EMAIL="$GIT_EMAIL"
VERCEL_SCOPE="$VERCEL_SCOPE"
CFG
  fi
  [ -n "$GH_OWNER" ] || GH_OWNER="$("$GH" api /user --jq .login)"
  [ -n "$GIT_NAME" ] || GIT_NAME="$GH_OWNER"
  [ -n "$GIT_EMAIL" ] || GIT_EMAIL="$GH_OWNER@users.noreply.github.com"
  export GH GH_OWNER GIT_NAME GIT_EMAIL VERCEL VERCEL_SCOPE
}

# vercel 을 팀 설정과 함께 실행합니다. 개인 계정이면 --scope 를 안 붙입니다.
vc() {
  if [ -n "$VERCEL_SCOPE" ]; then "$VERCEL" "$@" --scope "$VERCEL_SCOPE"
  else "$VERCEL" "$@"; fi
}

# ----------------------------------------------------------------------------
# to_slug : 이름을 깃허브·버셀이 받는 형태로 바꿉니다.
#   깃허브는 한글 이름을 전부 버리고 "-" 한 글자로 만들고, 버셀은 한글
#   폴더에서 오류를 냅니다. 막는 대신 소리나는 대로 로마자로 옮깁니다.
#       포트폴리오 → poteupolrio      대전 서구 상권 → daejeon-seogu-sanggwon
# ----------------------------------------------------------------------------
to_slug() {
  local n="$1"
  printf '%s' "$n" | grep -qE '^[a-z0-9][a-z0-9-]{0,62}$' && { printf '%s' "$n"; return 0; }
  command -v node >/dev/null 2>&1 || return 1
  node "$(winpath "$TOOLS/lib/slug.js")" "$n" 2>/dev/null || return 1
}

# ----------------------------------------------------------------------------
# site_url : 버셀이 실제로 배정한 주소를 알아냅니다.
#
#   ★ 주소를 추측하지 않습니다 ★
#   못 찾는다고 "https://<이름>.vercel.app" 으로 추측하면 안 됩니다.
#   그 주소는 남이 이미 쓰고 있을 수 있습니다. 실제로 speed-test 라는 이름을
#   썼더니 speed-test.vercel.app 은 생판 남의 사이트였고, 버셀은 겹치지 않는
#   speed-test-five-fawn.vercel.app 을 새로 배정했습니다.
#   추측한 주소를 확인하면 남의 사이트 상태를 내 것인 양 보고하게 됩니다.
# ----------------------------------------------------------------------------
site_url() {
  vc project ls 2>&1 | awk -v n="$1" '$1==n {print $2}' | head -1 || true
}

# 로그인하지 않은 사람이 그 주소를 열면 무엇이 보이는지 확인합니다.
#   버셀은 잠겨 있어도 HTTP 200 을 주므로, 코드가 아니라 제목으로 판별합니다.
page_title() {
  [ -z "$1" ] && return 0
  curl -s -L --max-time 30 "$1" 2>/dev/null \
    | grep -oE '<title>[^<]*</title>' | head -1 | sed 's/<[^>]*>//g' || true
}
http_code() {
  [ -z "$1" ] && { printf '000'; return; }
  local c; c="$(curl -s -o /dev/null -w '%{http_code}' -L --max-time 30 "$1" 2>/dev/null || true)"
  c="${c: -3}"; printf '%s' "${c:-000}"
}

# 배포 결과에서 주소를 뽑아냅니다.
deployed_url() {
  local err="$1" out="$2" u
  u="$(grep -oE 'Aliased +https://[^ ]+' "$err" | head -1 | awk '{print $2}' || true)"
  [ -n "$u" ] || u="https://$(grep -oE '"url": *"[^"]+"' "$out" | head -1 | sed 's/.*"url": *"//;s/"//' || true)"
  printf '%s' "$u"
}
