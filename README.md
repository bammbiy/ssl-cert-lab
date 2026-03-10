# 🔐 SSL/TLS 인증서 구축 실습 기록

집에서 개인 서버 만지다가 HTTPS를 붙여보고 싶어서 시작했습니다.  
처음엔 "명령어 하나 치면 되겠지" 했는데 80번 포트 막혀있는 것도 모르고 반나절 날렸습니다.  
그때부터 하나씩 공부하면서 직접 만들어본 스크립트들을 여기 정리했습니다.

---

## 📁 파일 구성

```
ssl-cert-lab/
├── index.html                      # 포트폴리오 웹페이지
├── style.css
├── main.js
└── scripts/
    ├── 01_letsencrypt_setup.sh     # Let's Encrypt 발급 + 자동 갱신
    ├── 02_private_ca_setup.sh      # OpenSSL 사설 CA + 서버 인증서 발급
    ├── 03_wildcard_cert.sh         # 와일드카드 인증서 (Cloudflare DNS)
    ├── 04_nginx_https.conf         # Nginx HTTPS 설정
    ├── 05_apache_https.conf        # Apache HTTPS 설정
    ├── 06_ssl_expiry_monitor.py    # 인증서 만료일 모니터링 스크립트
    └── 07_aws_acm_setup.sh         # AWS ACM + ALB 연동
```

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

### 1. 처음으로 HTTPS 전환해본 경험 → `01_letsencrypt_setup.sh`
> 집에서 돌리던 개인 웹 서비스에 처음으로 HTTPS를 붙여봤습니다.

Certbot 설치까지는 금방 됐는데 HTTP-01 Challenge 인증에서 계속 실패했습니다.  
한참 뒤에야 방화벽에서 80번 포트가 막혀있던 걸 발견했고, 포트 열고 나서 5분 만에 발급됐습니다.  
허탈했지만 그때 포트랑 방화벽 개념을 제대로 이해했습니다.

- Ubuntu 22.04 / Nginx / Let's Encrypt
- Certbot + Nginx 플러그인으로 자동 발급
- HTTPS 리다이렉트, HSTS 헤더 설정
- Cron으로 자동 갱신 등록

```bash
chmod +x scripts/01_letsencrypt_setup.sh
sudo ./scripts/01_letsencrypt_setup.sh
```

---

### 2. 외부 인터넷 없이 사설 CA 직접 구축해보기 → `02_private_ca_setup.sh`
> Let's Encrypt 없이도 HTTPS가 되는지 궁금해서 OpenSSL로 직접 CA를 만들어봤습니다.

Root CA 만드는 건 됐는데 브라우저에서 계속 빨간 경고가 떴습니다.  
만든 Root CA를 브라우저 신뢰 저장소에 직접 등록해줘야 한다는 걸 한참 후에야 알았고,  
자물쇠 아이콘이 처음 떴을 때 혼자 꽤 뿌듯했습니다.

- CentOS 7 / OpenSSL / Apache
- Root CA → Intermediate CA 체인 구성
- SAN 포함한 서버 인증서 발급
- 브라우저 신뢰 등록 수동 테스트

```bash
chmod +x scripts/02_private_ca_setup.sh
./scripts/02_private_ca_setup.sh
```

---

### 3. 서브도메인 늘어날 때마다 귀찮아서 와일드카드 도전 → `03_wildcard_cert.sh`
> 테스트용 서브도메인이 계속 늘어나면서 매번 인증서 새로 발급하기 귀찮아졌습니다.

와일드카드 인증서라는 걸 알게 돼서 DNS-01 Challenge 방식을 공부했습니다.  
Cloudflare API 토큰 권한 설정을 잘못해서 한동안 인증이 계속 실패했는데,  
Zone:Read, DNS:Edit 권한이 둘 다 필요하다는 걸 공식 문서 보고 겨우 찾았습니다.

- Ubuntu 20.04 / Nginx / Certbot + Cloudflare DNS 플러그인
- DNS-01 Challenge로 `*.example.com` 발급
- deploy-hook으로 갱신 시 Nginx 자동 reload

```bash
chmod +x scripts/03_wildcard_cert.sh
sudo ./scripts/03_wildcard_cert.sh
```

---

### 4. Nginx / Apache HTTPS 설정 → `04_nginx_https.conf`, `05_apache_https.conf`
> 인증서를 발급했는데 서버 설정을 어떻게 해야 하는지 몰라서 따로 공부했습니다.

단순히 인증서 경로만 지정하는 게 아니라 TLS 버전 제한, HSTS, OCSP Stapling 같은  
보안 설정을 같이 넣어야 SSL Labs에서 A+ 등급이 나온다는 걸 알게 됐습니다.

```bash
# Nginx
sudo cp scripts/04_nginx_https.conf /etc/nginx/sites-available/mysite
sudo ln -s /etc/nginx/sites-available/mysite /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

# Apache
sudo cp scripts/05_apache_https.conf /etc/apache2/sites-available/mysite-ssl.conf
sudo a2enmod ssl rewrite headers
sudo a2ensite mysite-ssl
sudo systemctl reload apache2
```

---

### 5. 인증서 만료 모니터링 스크립트 → `06_ssl_expiry_monitor.py`
> 자동 갱신을 설정했는데도 혹시 몰라서 만료일을 직접 확인하는 스크립트를 짰습니다.

도메인 목록을 넣으면 남은 일수를 출력하고, 30일 미만이면 이메일로 알림을 보냅니다.  
Cron에 등록해두면 매일 아침 자동으로 확인됩니다.

```bash
python3 scripts/06_ssl_expiry_monitor.py
```

```
=======================================================
SSL 인증서 만료일 확인 - 2025-01-15 09:00 UTC
=======================================================
  your-domain.com          2025-04-15  🟢 90일 남음
  www.your-domain.com      2025-04-15  🟢 90일 남음
=======================================================
```

---

### 6. AWS 환경도 경험해보고 싶어서 ACM + ALB 구성 → `07_aws_acm_setup.sh`
> 클라우드에서는 어떻게 SSL을 적용하는지 궁금해서 AWS 프리티어로 테스트해봤습니다.

서버에 직접 Certbot 설치 안 해도 된다는 게 신기했고, ACM은 자동 갱신까지 돼서 편했습니다.  
ALB 리스너 설정이랑 Route 53 연동 흐름을 처음 잡는 데 시간이 좀 걸렸는데,  
한 번 해보고 나니 구조가 눈에 들어왔습니다.

```bash
chmod +x scripts/07_aws_acm_setup.sh
./scripts/07_aws_acm_setup.sh
```

---

## 📞 Contact

- GitHub: [https://github.com/bammbiy](https://github.com/bammbiy)
- Email: m1125k21@naver.com

---

*혼자 공부하면서 만들어본 것들입니다. 아직 부족하지만 모르면 끝까지 찾아보는 편입니다.*
