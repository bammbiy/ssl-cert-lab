#!/bin/bash
# ============================================================
# 03_wildcard_cert.sh
# 와일드카드 인증서 발급 (DNS-01 Challenge + Cloudflare)
#
# 사전 조건:
#   - Cloudflare에서 도메인 관리 중이어야 함
#   - Cloudflare API 토큰 필요
#     발급 위치: Cloudflare 대시보드 > My Profile > API Tokens > Create Token
#     필요 권한: Zone:Read + DNS:Edit  ← 이 두 개 없으면 인증 실패함
#
# 사용법:
#   chmod +x 03_wildcard_cert.sh
#   sudo ./03_wildcard_cert.sh
# ============================================================

DOMAIN="your-domain.com"       # 본인 도메인으로 변경
EMAIL="your-email@example.com"
CF_API_TOKEN="your-cloudflare-api-token"  # Cloudflare API 토큰

echo "==> Certbot + Cloudflare 플러그인 설치 중..."
sudo apt update -y
sudo apt install -y certbot python3-certbot-dns-cloudflare

echo "==> Cloudflare API 토큰 파일 생성..."
mkdir -p ~/.secrets
cat > ~/.secrets/cloudflare.ini <<EOF
dns_cloudflare_api_token = $CF_API_TOKEN
EOF

# 토큰 파일 권한 제한 (본인만 읽기 가능하게)
chmod 600 ~/.secrets/cloudflare.ini

echo "==> 와일드카드 인증서 발급 중..."
# DNS-01 Challenge: Cloudflare DNS에 TXT 레코드 자동 추가해서 소유권 인증
sudo certbot certonly \
  --dns-cloudflare \
  --dns-cloudflare-credentials ~/.secrets/cloudflare.ini \
  --dns-cloudflare-propagation-seconds 30 \
  -d "$DOMAIN" \
  -d "*.$DOMAIN" \
  --email "$EMAIL" \
  --agree-tos \
  --non-interactive

echo "==> 갱신 시 Nginx 자동 reload 훅 등록..."
# 인증서 갱신 성공할 때마다 자동으로 실행되는 스크립트
sudo mkdir -p /etc/letsencrypt/renewal-hooks/deploy
cat | sudo tee /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh <<'EOF'
#!/bin/bash
systemctl reload nginx
echo "$(date): 인증서 갱신 완료, Nginx reload 함" >> /var/log/certbot-deploy.log
EOF
sudo chmod +x /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh

echo ""
echo "완료! 발급된 인증서 경로:"
echo "  /etc/letsencrypt/live/$DOMAIN/fullchain.pem"
echo "  /etc/letsencrypt/live/$DOMAIN/privkey.pem"
echo ""
echo "이 인증서는 *.$DOMAIN 모든 서브도메인에 사용 가능합니다."