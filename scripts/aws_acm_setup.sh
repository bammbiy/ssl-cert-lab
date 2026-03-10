#!/bin/bash
# ============================================================
# 07_aws_acm_setup.sh
# AWS ACM 인증서 발급 + ALB 연동 자동화
#
# 사전 조건:
#   - AWS CLI 설치 및 자격증명 설정 (aws configure)
#   - Route 53에서 도메인 관리 중이어야 함
#   - ALB ARN 확인 필요 (AWS 콘솔 > EC2 > Load Balancers)
#
# 사용법:
#   chmod +x 07_aws_acm_setup.sh
#   ./07_aws_acm_setup.sh
# ============================================================

DOMAIN="your-domain.com"
REGION="ap-northeast-2"        # 서울 리전
ALB_ARN="arn:aws:elasticloadbalancing:..."  # 본인 ALB ARN으로 변경

echo "==> AWS ACM 인증서 발급 요청 중..."
CERT_ARN=$(aws acm request-certificate \
  --domain-name "$DOMAIN" \
  --subject-alternative-names "*.$DOMAIN" \
  --validation-method DNS \
  --region "$REGION" \
  --query "CertificateArn" \
  --output text)

echo "인증서 ARN: $CERT_ARN"

echo ""
echo "==> DNS 검증 레코드 확인 중..."
echo "    (발급 요청 직후라 잠깐 기다리는 중...)"
sleep 10

# DNS 검증에 필요한 CNAME 레코드 값 출력
aws acm describe-certificate \
  --certificate-arn "$CERT_ARN" \
  --region "$REGION" \
  --query "Certificate.DomainValidationOptions[*].{Domain:DomainName,Name:ResourceRecord.Name,Value:ResourceRecord.Value}" \
  --output table

echo ""
echo "==> 위 CNAME 레코드를 Route 53에 추가해야 합니다."
echo "    Route 53 콘솔 > Hosted zones > $DOMAIN > Create record"
echo "    또는 아래 명령어로 자동 추가 가능 (Hosted Zone ID 필요):"
echo ""
echo "    HOSTED_ZONE_ID=<your-hosted-zone-id>"
echo "    aws route53 change-resource-record-sets \\"
echo "      --hosted-zone-id \$HOSTED_ZONE_ID \\"
echo "      --change-batch file://dns-validation.json"

echo ""
echo "==> 인증서 발급 완료 대기 중... (DNS 전파에 수 분 소요)"
aws acm wait certificate-validated \
  --certificate-arn "$CERT_ARN" \
  --region "$REGION"
echo "인증서 발급 완료!"

echo ""
echo "==> ALB에 HTTPS(443) 리스너 추가 중..."
aws elbv2 create-listener \
  --load-balancer-arn "$ALB_ARN" \
  --protocol HTTPS \
  --port 443 \
  --certificates CertificateArn="$CERT_ARN" \
  --ssl-policy "ELBSecurityPolicy-TLS13-1-2-2021-06" \
  --default-actions Type=forward,TargetGroupArn="<your-target-group-arn>" \
  --region "$REGION"

echo ""
echo "==> HTTP → HTTPS 리다이렉트 설정 중..."
HTTP_LISTENER_ARN=$(aws elbv2 describe-listeners \
  --load-balancer-arn "$ALB_ARN" \
  --region "$REGION" \
  --query "Listeners[?Port==\`80\`].ListenerArn" \
  --output text)

aws elbv2 modify-listener \
  --listener-arn "$HTTP_LISTENER_ARN" \
  --default-actions \
    Type=redirect,RedirectConfig="{Protocol=HTTPS,Port=443,StatusCode=HTTP_301}" \
  --region "$REGION"

echo ""
echo "완료! HTTPS 설정이 끝났습니다."
echo "ALB DNS로 접속해서 확인해보세요."
aws elbv2 describe-load-balancers \
  --load-balancer-arns "$ALB_ARN" \
  --region "$REGION" \
  --query "LoadBalancers[0].DNSName" \
  --output text