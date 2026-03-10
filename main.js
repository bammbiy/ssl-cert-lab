const cases = [
  {
    num: "case_01",
    title: "처음으로 혼자 HTTPS 전환했던 경험",
    summary: "집에서 돌리던 개인 웹 서비스에 처음으로 HTTPS를 붙여봤습니다.",
    story: [
      "Certbot 설치까지는 금방 했는데, HTTP-01 Challenge 인증에서 계속 실패했습니다.",
      "나중에 보니 서버 방화벽에서 80번 포트가 막혀있었고, 그걸 몰랐던 거였습니다. 포트 열고 나서 5분 만에 발급됐을 때 허탈하면서도 배운 게 많았습니다."
    ],
    env: ["Ubuntu 22.04", "Nginx", "Let's Encrypt"],
    items: [
      "Certbot + Nginx 플러그인으로 자동 발급",
      "HTTPS 리다이렉트, HSTS 헤더 설정",
      "Cron으로 자동 갱신 등록",
    ],
    code: [
      { type: "cm", text: "# 발급" },
      { type: "kw", text: "sudo certbot", after: " --nginx " },
      { type: "fl", text: "-d", after: " " },
      { type: "st", text: "example.com", after: " " },
      { type: "fl", text: "-d", after: " " },
      { type: "st", text: "www.example.com" },
      { type: "br" },
      { type: "cm", text: "# 자동 갱신 (cron)" },
      { type: "kw", text: "echo", after: ' "0 3 * * * root certbot renew --quiet" | sudo tee /etc/cron.d/certbot' },
    ],
    lang: "bash",
    result: "개인 서비스 HTTPS 전환 완료. 자동 갱신까지 붙이고 나서 만료 걱정이 없어졌습니다."
  },
  {
    num: "case_02",
    title: "외부 인터넷 없이 사설 CA 직접 구축해보기",
    summary: "Let's Encrypt 없이도 HTTPS가 되는지 궁금해서 OpenSSL로 직접 CA를 만들어봤습니다.",
    story: [
      "Root CA 만드는 건 됐는데 브라우저에서 계속 빨간 경고가 떴습니다.",
      "만든 Root CA를 브라우저 신뢰 저장소에 직접 등록해줘야 한다는 걸 한참 후에야 알았고, 자물쇠 아이콘이 처음 떴을 때 혼자 꽤 뿌듯했습니다."
    ],
    env: ["CentOS 7", "OpenSSL", "Apache"],
    items: [
      "Root CA → Intermediate CA 체인 구성",
      "SAN 포함한 서버 인증서 발급",
      "브라우저 신뢰 등록 수동 테스트",
      "갱신 절차 직접 문서화",
    ],
    code: [
      { type: "cm", text: "# Root CA 키 생성" },
      { type: "kw", text: "openssl genrsa", after: " " },
      { type: "fl", text: "-aes256", after: " " },
      { type: "fl", text: "-out", after: " rootCA.key " },
      { type: "st", text: "4096" },
      { type: "br" },
      { type: "kw", text: "openssl req", after: " " },
      { type: "fl", text: "-x509 -new -nodes", after: " " },
      { type: "fl", text: "-key", after: " rootCA.key " },
      { type: "fl", text: "-sha256 -days", after: " " },
      { type: "st", text: "3650", after: " " },
      { type: "fl", text: "-out", after: " rootCA.crt" },
    ],
    lang: "bash",
    result: "로컬 환경에서 브라우저 경고 없이 HTTPS 동작 확인. 사설 CA 구조를 이해하게 됐습니다."
  },
  {
    num: "case_03",
    title: "와일드카드 인증서로 서브도메인 문제 해결",
    summary: "서비스마다 서브도메인이 늘어날 때마다 인증서를 새로 만들기 번거로웠습니다.",
    story: [
      "서브도메인마다 발급하기 귀찮아서 찾아보다가 와일드카드 인증서라는 걸 알게 됐고, DNS-01 Challenge 방식을 공부했습니다.",
      "Cloudflare API 토큰 권한 설정을 잘못해서 인증이 안 되는 상황이 있었는데, Zone:Read, DNS:Edit 권한이 필요한 걸 몰랐던 거였습니다."
    ],
    env: ["Ubuntu 20.04", "Nginx", "Cloudflare"],
    items: [
      "DNS-01 Challenge로 *.example.com 발급",
      "Certbot Cloudflare DNS 플러그인 연동 (API Token)",
      "deploy-hook으로 갱신 시 Nginx 자동 reload",
    ],
    code: [
      { type: "kw", text: "certbot certonly", after: " " },
      { type: "fl", text: "--dns-cloudflare", after: " \\\n  " },
      { type: "fl", text: "--dns-cloudflare-credentials", after: " ~/.secrets/cloudflare.ini \\\n  " },
      { type: "fl", text: "-d", after: " " },
      { type: "st", text: '"*.example.com"', after: " " },
      { type: "fl", text: "-d", after: " " },
      { type: "st", text: '"example.com"' },
    ],
    lang: "bash",
    result: "30개 넘는 서브도메인에 인증서 하나로 대응. 발급 요청이 확실히 줄었습니다."
  },
  {
    num: "case_04",
    title: "AWS 환경에서 ACM + ALB 연동",
    summary: "클라우드 환경에서는 SSL을 어떻게 쓰는지 궁금해서 AWS 프리티어로 직접 테스트해봤습니다.",
    story: [
      "서버에 직접 Certbot 설치 안 해도 된다는 게 신기했습니다.",
      "DNS 검증 방식으로 발급하고 ALB 리스너에 붙이는 흐름을 처음 잡는 데 시간이 좀 걸렸는데, 한 번 익히고 나니 제일 편한 방법이었습니다."
    ],
    env: ["AWS ACM", "ALB", "Route 53"],
    items: [
      "ACM DNS 검증으로 공인 인증서 발급",
      "ALB 리스너 HTTPS(443) 추가, HTTP→HTTPS 리다이렉트",
      "Route 53 Alias 레코드 연동",
    ],
    code: [
      { type: "kw", text: "aws acm request-certificate", after: " \\\n  " },
      { type: "fl", text: "--domain-name", after: " " },
      { type: "st", text: "example.com", after: " \\\n  " },
      { type: "fl", text: "--validation-method", after: " " },
      { type: "st", text: "DNS", after: " \\\n  " },
      { type: "fl", text: "--subject-alternative-names", after: " " },
      { type: "st", text: '"*.example.com"' },
    ],
    lang: "aws-cli",
    result: "서버 작업 없이 HTTPS 구성 완료. ACM은 자동 갱신도 돼서 편합니다."
  }
];

function renderCode(tokens) {
  return tokens.map(t => {
    if (t.type === "br") return "\n";
    const after = t.after || "";
    if (t.type === "cm") return `<span class="cm">${t.text}</span>`;
    if (t.type === "kw") return `<span class="kw">${t.text}</span>${after}`;
    if (t.type === "fl") return `<span class="fl">${t.text}</span>${after}`;
    if (t.type === "st") return `<span class="st">${t.text}</span>${after}`;
    return t.text + after;
  }).join("");
}

function renderCases() {
  const container = document.getElementById("cases-list");
  container.innerHTML = cases.map((c, i) => `
    <div class="case-card fade-in" style="transition-delay: ${i * 80}ms">
      <div class="case-head">
        <span class="case-num">${c.num}</span>
        <div class="case-info">
          <h3>${c.title}</h3>
          <p class="case-summary">${c.summary}</p>
        </div>
        <div class="case-env">
          ${c.env.map(e => `<span class="env-tag">${e}</span>`).join("")}
        </div>
      </div>
      <div class="case-story">
        ${c.story.map(s => `<p>${s}</p>`).join("")}
      </div>
      <div class="case-body">
        <ul class="case-items">
          ${c.items.map(item => `<li>${item}</li>`).join("")}
        </ul>
        <div class="code-block">
          <span class="lang">${c.lang}</span>
          <pre>${renderCode(c.code)}</pre>
        </div>
      </div>
      <div class="case-result">
        <div class="result-dot"></div>
        <span>${c.result}</span>
      </div>
    </div>
  `).join("");

  // 렌더 후 fade-in 옵저버 재등록
  observeFadeIns();
}

function observeFadeIns() {
  const observer = new IntersectionObserver((entries) => {
    entries.forEach(e => {
      if (e.isIntersecting) {
        e.target.classList.add("visible");
        observer.unobserve(e.target);
      }
    });
  }, { threshold: 0.12 });

  document.querySelectorAll(".fade-in").forEach(el => observer.observe(el));
}

// 헤더 스크롤 효과
window.addEventListener("scroll", () => {
  const header = document.getElementById("header");
  header.style.borderBottomColor = window.scrollY > 10 ? "#30363d" : "#21262d";
});

document.addEventListener("DOMContentLoaded", () => {
  renderCases();

  // hero fade-in
  document.querySelectorAll(".hero").forEach(el => {
    el.classList.add("fade-in");
    setTimeout(() => el.classList.add("visible"), 80);
  });
});