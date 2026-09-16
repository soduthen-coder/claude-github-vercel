# 클로드가 만든 걸 인터넷에 올리기

클로드에게 뭔가 만들어 달라고 했더니 파일이 생겼습니다.
그걸 **깃허브에 올리고 인터넷 주소로 열리게** 하는 일만 합니다.

## 쓰는 법

이 주소를 **클로드(Claude Code)에 붙여넣고 "올려 줘"** 라고 하세요.

```
https://github.com/soduthen-coder/claude-github-vercel
```

터미널도, 명령어도, 깃허브 사용법도 몰라도 됩니다.
사람이 할 일은 **처음 한 번 로그인 승인 두 번**뿐입니다.

## 미리 만들어 둘 것

| | 어디서 |
|---|---|
| 깃허브 계정 | [github.com/signup](https://github.com/signup) |
| 버셀 계정 | [vercel.com/signup](https://vercel.com/signup) — **Continue with GitHub** 을 고르세요 |

둘 다 무료입니다. 2단계 인증은 설정하지 않아도 됩니다.

## 그 다음

```
"고친 거 다시 올려 줘"   "나만 보게 잠가 줘"
"다시 공개해 줘"         "내려 줘"
```

---

### 자세한 설명

**https://claude-ship.vercel.app**

### 만든 사람용

`ship.sh` 올리기 · `lock.sh` 잠금/공개 · `down.sh` 내리기.
동작 방식과 만들면서 부딪힌 함정들은 각 스크립트 주석과
[`CLAUDE.md`](CLAUDE.md) 에 적어 두었습니다.

이 저장소가 배포 도구의 **확정판**입니다.
전에 따로 있던 `github-vercel-onetouch` 는 여기로 합쳐졌습니다. 그쪽은
빈 사이트를 처음부터 만들어 주는 기능이 있었지만, 클로드에게 만들어 달라고
하면 될 일이라 덜어냈습니다. 흐름은 하나입니다 — **만들게 한 뒤 올린다.**
