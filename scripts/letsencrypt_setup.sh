#!/bin/bash
# ============================================================
# 01_letsencrypt_setup.sh
# Let's Encrypt SSL 인증서 발급 + 자동 갱신 설정
#
# 사전 조건:
#   - Ubuntu 20.04 / 22.04
#   - Nginx 설치되어 있어야 함 (sudo apt install nginx)
#   - 80번 포트 외부에서 열려 있어야 함 (방화벽 확인 필수)
#   - 실제 도메인이 이 서버 IP를 가리키고 있어야 함
#
# 사용법:
#   chmod +x 01_letsencrypt_setup.sh
#   sudo ./01_letsencrypt_setup.sh
# ============================================================

DOMAIN="your-domain.com"       # 본인 도메인으로 변경
WWW_DOMAIN="www.your-domain.com"
EMAIL="your-email@example.com" # 만료 알림 받을 이메일

echo "==> Certbot 설치 중..."
sudo apt update -y
sudo apt install -y certbot python3-certbot-nginx

echo "==> 80번 포트 방화벽 허용..."
sudo ufw allow 80
sudo ufw allow 443

echo "==> 인증서 발급 중 (HTTP-01 Challenge)..."
sudo certbot --nginx \
  -d "$DOMAIN" \
  -d "$WWW_DOMAIN" \
  --email "$EMAIL" \
  --agree-tos \
  --non-interactive

echo "==> 자동 갱신 Cron 등록..."
# 매일 새벽 3시에 갱신 시도 (만료 30일 전부터 자동 갱신)
echo "0 3 * * * root certbot renew --quiet --deploy-hook 'systemctl reload nginx'" \
  | sudo tee /etc/cron.d/certbot-renew

echo "==> 갱신 테스트 (실제 발급 없이 시뮬레이션)..."
sudo certbot renew --dry-run

echo ""
echo "완료! 아래 주소로 확인해보세요."
echo "https://$DOMAIN"