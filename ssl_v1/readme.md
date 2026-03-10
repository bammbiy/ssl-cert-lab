# 🔐 SSL/TLS 인증서 구축 포트폴리오

집에서 개인 서버 만지다가 HTTPS 적용해보고 싶어서 시작했습니다.  
처음엔 "명령어 하나 치면 되겠지" 했는데, 80번 포트 막혀있는 것도 모르고 반나절 날렸습니다.  
그 이후로 관련 내용을 계속 공부하면서 이것저것 직접 해봤고, 그 기록을 여기 정리했습니다.

---

## 🛠 사용 기술

| 분류 | 기술 |
|------|------|
| 인증서 발급 | Let's Encrypt, Certbot, OpenSSL |
| 웹 서버 | Nginx, Apache |
| CA / PKI | OpenSSL 기반 사설 CA, SAN 인증서 |
| 클라우드 | AWS ACM, ALB, Route 53 |
| 자동화 | Shell Script, Cron, deploy-hook |
| 모니터링 | 만료 알림 스크립트 (Python) |
| OS | Ubuntu 20.04 / 22.04, CentOS 7 |

---

## 📂 작업 사례

### 1. 처음으로 HTTPS 전환해본 경험
> 집에서 돌리던 간단한 웹 서비스에 HTTPS를 붙여보고 싶었습니다.

Certbot 설치까지는 금방 됐는데 HTTP-01 Challenge 인증에서 계속 실패했습니다.  
한참 뒤에야 방화벽에서 80번 포트가 막혀있던 걸 발견했고, 포트 열고 나서 5분 만에 발급됐습니다.  
허탈했지만 그때 포트랑 방화벽 개념을 제대로 이해했습니다.

- Ubuntu 22.04 / Nginx / Let's Encrypt
- Certbot + Nginx 플러그인으로 자동 발급
- HTTPS 리다이렉트, HSTS 헤더 설정
- Cron으로 자동 갱신 등록

```bash
# 발급
sudo certbot --nginx -d example.com -d www.example.com

# 자동 갱신 (cron)
echo "0 3 * * * root certbot renew --quiet" | sudo tee /etc/cron.d/certbot
```

**결과:** 개인 서비스 HTTPS 전환 완료. 자동 갱신까지 붙이고 나서 만료 걱정이 없어졌습니다.

---

### 2. 외부 인터넷 없이 사설 CA 직접 구축해보기
> Let's Encrypt 없이도 HTTPS가 가능한지 궁금해서 OpenSSL로 직접 CA를 만들어봤습니다.

Root CA 만드는 건 됐는데 브라우저에서 계속 빨간 경고가 떴습니다.  
만든 Root CA를 브라우저 신뢰 저장소에 직접 등록해줘야 한다는 걸 한참 후에야 알았고,  
자물쇠 아이콘이 처음 떴을 때는 혼자 꽤 뿌듯했습니다.

- CentOS 7 / OpenSSL / Apache
- Root CA → Intermediate CA 체인 구성
- SAN 포함한 서버 인증서 발급
- 브라우저 신뢰 등록 수동 테스트
- 갱신 절차 직접 문서화

```bash
# Root CA 생성
openssl genrsa -aes256 -out rootCA.key 4096
openssl req -x509 -new -nodes -key rootCA.key -sha256 -days 3650 -out rootCA.crt
```

**결과:** 로컬 환경에서 브라우저 경고 없이 HTTPS 동작 확인.

---

### 3. 서브도메인 늘어날 때마다 귀찮아서 와일드카드 도전
> 테스트용 서브도메인이 계속 늘어나면서 매번 인증서 새로 발급하기 귀찮아졌습니다.

와일드카드 인증서라는 걸 알게 돼서 DNS-01 Challenge 방식을 공부했습니다.  
Cloudflare API 토큰 권한 설정을 잘못해서 한동안 인증이 계속 실패했는데,  
Zone:Read, DNS:Edit 권한이 둘 다 필요하다는 걸 공식 문서 보고 겨우 찾았습니다.

- Ubuntu 20.04 / Nginx / Certbot + Cloudflare DNS 플러그인
- DNS-01 Challenge로 `*.example.com` 발급
- deploy-hook으로 갱신 시 Nginx 자동 reload

```bash
certbot certonly --dns-cloudflare \
  --dns-cloudflare-credentials ~/.secrets/cloudflare.ini \
  -d "*.example.com" -d "example.com"
```

**결과:** 서브도메인 여러 개에 인증서 하나로 대응. 신규 서브도메인 추가가 훨씬 편해졌습니다.

---

### 4. AWS 환경도 경험해보고 싶어서 ACM + ALB 구성
> 클라우드 환경에서는 어떻게 SSL을 적용하는지 궁금해서 AWS 프리티어로 테스트해봤습니다.

서버에 직접 Certbot 설치 안 해도 된다는 게 신기했고, ACM은 자동 갱신까지 돼서 편했습니다.  
ALB 리스너 설정이랑 Route 53 연동 흐름을 처음 잡는 데 시간이 좀 걸렸는데,  
한 번 해보고 나니 구조가 눈에 들어왔습니다.

- AWS ACM + ALB + Route 53
- ACM DNS 검증으로 공인 인증서 발급
- ALB HTTPS(443) 리스너 추가, HTTP→HTTPS 리다이렉트
- Route 53 Alias 레코드 연동

```bash
aws acm request-certificate \
  --domain-name example.com \
  --validation-method DNS \
  --subject-alternative-names "*.example.com"
```

**결과:** 서버 직접 설정 없이 HTTPS 구성 완료. 클라우드 환경 흐름을 파악할 수 있었습니다.

---

## ✅ 할 수 있는 작업

- Let's Encrypt 발급 및 자동 갱신 설정
- 사설 CA 구축 (OpenSSL)
- 와일드카드 / SAN 인증서 발급
- Nginx / Apache HTTPS 설정
- AWS ACM 연동
- 인증서 만료 모니터링 스크립트
- HTTP → HTTPS 전환
- SSL Labs A등급 이상 설정 최적화

---

## 📞 Contact

- GitHub: [https://github.com/bammbiy](https://github.com/bammbiy)
- Email: m1125k21@naver.com

---

*혼자 공부하면서 만들어본 것들입니다. 아직 부족하지만 모르면 끝까지 찾아보는 편입니다.*