// ============================================================================
//  slug.js — 프로젝트 이름을 깃허브·버셀이 받아들이는 형태로 바꿉니다
// ----------------------------------------------------------------------------
//  쓰는 법:  node lib/slug.js "포트폴리오"   →   poteupolrio
//
//  왜 필요한가
//    깃허브는 한글 저장소 이름을 전부 버리고 "-" 한 글자로 만들어 버립니다.
//    버셀은 한글 폴더에서 링크 오류를 냅니다. 둘 다 실제로 겪은 문제입니다.
//    그래서 예전에는 한글 이름이면 그냥 막았는데, 막는 것보다 자동으로
//    바꿔주는 편이 낫습니다. 한글을 소리나는 대로 로마자로 옮깁니다.
//
//    포트폴리오      →  poteupolrio
//    대전 서구 상권   →  daejeon-seogu-sanggwon
//    2026 졸업작품   →  2026-joleopjakpum
//
//  Node.js 로 만든 이유: 이 도구는 vercel 설치에 Node.js 가 필요하므로
//  이미 반드시 깔려 있습니다. 따로 뭘 더 설치할 필요가 없습니다.
// ============================================================================

// 한글 낱자(자모) 소리값. 한글 글자 하나는 초성+중성+종성으로 쪼갤 수 있고,
// 유니코드에서 규칙적으로 배열되어 있어 계산으로 분해됩니다.
const CHO  = ['g','kk','n','d','tt','r','m','b','pp','s','ss','','j','jj','ch','k','t','p','h'];
const JUNG = ['a','ae','ya','yae','eo','e','yeo','ye','o','wa','wae','oe','yo',
              'u','wo','we','wi','yu','eu','ui','i'];
const JONG = ['','k','k','k','n','n','n','t','l','l','l','l','l','l','l','l',
              'm','p','p','t','t','ng','t','t','k','t','p','t'];

function romanize(text) {
  let out = '';
  for (const ch of text) {
    const c = ch.codePointAt(0);
    if (c >= 0xAC00 && c <= 0xD7A3) {          // 한글 완성형 글자인 경우
      const i = c - 0xAC00;
      out += CHO[Math.floor(i / 588)] + JUNG[Math.floor((i % 588) / 28)] + JONG[i % 28];
    } else {
      out += ch;                                // 영문·숫자 등은 그대로
    }
  }
  return out;
}

function slugify(text) {
  let s = romanize(text);
  s = s.normalize('NFKD').replace(/[̀-ͯ]/g, ''); // 악센트 제거 (é → e)
  s = s.toLowerCase();
  s = s.replace(/[^a-z0-9]+/g, '-');   // 영소문자·숫자 아닌 것은 하이픈으로
  s = s.replace(/-{2,}/g, '-');        // 하이픈이 겹치면 하나로
  s = s.replace(/^-+|-+$/g, '');       // 앞뒤 하이픈 제거
  s = s.slice(0, 63);                  // 깃허브 이름 길이 제한
  s = s.replace(/-+$/, '');            // 자르다 끝에 하이픈이 남으면 제거
  return s;
}

const input = process.argv[2] || '';
const result = slugify(input);

// 변환해도 쓸 수 없는 이름(빈 문자열, 숫자·하이픈만 등)이면 빈 값을 돌려줍니다.
// 부르는 쪽에서 "이름을 다시 지어 달라"고 안내합니다.
if (!/^[a-z0-9][a-z0-9-]{0,62}$/.test(result)) {
  process.stdout.write('');
  process.exit(1);
}
process.stdout.write(result);
