#!/bin/bash
# ============================================================
# 02_private_ca_setup.sh
# OpenSSL로 사설 CA 구축 + 서버 인증서 발급
#
# 사전 조건:
#   - openssl 설치 (sudo apt install openssl)
#   - 인터넷 없는 환경 or Let's Encrypt 쓰기 싫을 때 사용
#
# 사용법:
#   chmod +x 02_private_ca_setup.sh
#   ./02_private_ca_setup.sh
#
# 실행 후 생성되는 파일:
#   ca/rootCA.key       - Root CA 개인키 (절대 유출 금지)
#   ca/rootCA.crt       - Root CA 인증서 (브라우저에 신뢰 등록할 파일)
#   server/server.key   - 서버 개인키
#   server/server.crt   - 서버 인증서 (Nginx/Apache에 등록)
# ============================================================

DOMAIN="local.mysite.com"   # 사용할 내부 도메인으로 변경
DAYS_CA=3650                # Root CA 유효기간 (10년)
DAYS_CERT=365               # 서버 인증서 유효기간 (1년)

mkdir -p ca server

# ── 1단계: Root CA 키 + 인증서 생성 ──────────────────────────
echo "==> Root CA 생성 중..."

# Root CA 개인키 생성 (패스프레이즈 입력 필요)
openssl genrsa -aes256 -out ca/rootCA.key 4096

# Root CA 자체 서명 인증서 생성
openssl req -x509 -new -nodes \
  -key ca/rootCA.key \
  -sha256 \
  -days $DAYS_CA \
  -out ca/rootCA.crt \
  -subj "/C=KR/ST=Seoul/O=MyPrivateCA/CN=MyRootCA"

echo "Root CA 생성 완료: ca/rootCA.crt"

# ── 2단계: 서버 인증서 생성 ───────────────────────────────────
echo "==> 서버 인증서 생성 중..."

# 서버 개인키 생성
openssl genrsa -out server/server.key 2048

# SAN(Subject Alternative Name) 설정 파일 생성
# SAN 없으면 최신 브라우저에서 경고 뜸 - 반드시 포함해야 함
cat > server/san.cnf <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name

[req_distinguished_name]

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = $DOMAIN
DNS.2 = *.$DOMAIN
EOF

# CSR (인증서 서명 요청) 생성
openssl req -new \
  -key server/server.key \
  -out server/server.csr \
  -subj "/C=KR/ST=Seoul/O=MyOrg/CN=$DOMAIN" \
  -config server/san.cnf

# Root CA로 서버 인증서 서명
openssl x509 -req \
  -in server/server.csr \
  -CA ca/rootCA.crt \
  -CAkey ca/rootCA.key \
  -CAcreateserial \
  -out server/server.crt \
  -days $DAYS_CERT \
  -sha256 \
  -extensions v3_req \
  -extfile server/san.cnf

echo ""
echo "완료! 생성된 파일:"
echo "  - ca/rootCA.crt     → 브라우저에 신뢰 등록 (설정 > 인증서 관리)"
echo "  - server/server.crt → Nginx ssl_certificate 경로에 지정"
echo "  - server/server.key → Nginx ssl_certificate_key 경로에 지정"
echo ""
echo "인증서 정보 확인:"
openssl x509 -in server/server.crt -noout -text | grep -E "Subject:|DNS:|Not After"