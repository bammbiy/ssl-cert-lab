#!/usr/bin/env python3
# ============================================================
# 06_ssl_expiry_monitor.py
# SSL 인증서 만료일 확인 + 콘솔 출력 / 이메일 알림
#
# 사전 조건:
#   pip install requests  (이메일 알림 쓸 경우)
#
# 사용법:
#   python3 06_ssl_expiry_monitor.py
#
# Cron 등록 예시 (매일 오전 9시 실행):
#   0 9 * * * python3 /path/to/06_ssl_expiry_monitor.py >> /var/log/ssl-monitor.log 2>&1
# ============================================================

import ssl
import socket
import smtplib
from datetime import datetime, timezone
from email.mime.text import MIMEText

# ── 설정 ─────────────────────────────────────────────────────
DOMAINS = [
    "your-domain.com",
    "www.your-domain.com",
    # 모니터링할 도메인 추가
]

WARN_DAYS = 30  # 만료 며칠 전부터 경고할지

# 이메일 알림 설정 (사용 안 하면 SEND_EMAIL = False)
SEND_EMAIL = False
SMTP_HOST  = "smtp.gmail.com"
SMTP_PORT  = 587
SMTP_USER  = "your-email@gmail.com"
SMTP_PASS  = "your-app-password"   # Gmail 앱 비밀번호
ALERT_TO   = "your-email@gmail.com"


# ── 인증서 만료일 조회 ────────────────────────────────────────
def get_cert_expiry(domain: str, port: int = 443) -> datetime | None:
    try:
        ctx = ssl.create_default_context()
        with socket.create_connection((domain, port), timeout=5) as sock:
            with ctx.wrap_socket(sock, server_hostname=domain) as ssock:
                cert = ssock.getpeercert()
                expiry_str = cert["notAfter"]
                return datetime.strptime(expiry_str, "%b %d %H:%M:%S %Y %Z").replace(tzinfo=timezone.utc)
    except Exception as e:
        print(f"  [오류] {domain}: {e}")
        return None


# ── 이메일 발송 ───────────────────────────────────────────────
def send_alert(subject: str, body: str):
    msg = MIMEText(body, "plain", "utf-8")
    msg["Subject"] = subject
    msg["From"]    = SMTP_USER
    msg["To"]      = ALERT_TO

    try:
        with smtplib.SMTP(SMTP_HOST, SMTP_PORT) as server:
            server.starttls()
            server.login(SMTP_USER, SMTP_PASS)
            server.send_message(msg)
        print("  이메일 알림 발송 완료")
    except Exception as e:
        print(f"  이메일 발송 실패: {e}")


# ── 메인 ─────────────────────────────────────────────────────
def main():
    now = datetime.now(timezone.utc)
    alerts = []

    print(f"\n{'='*55}")
    print(f"SSL 인증서 만료일 확인 - {now.strftime('%Y-%m-%d %H:%M UTC')}")
    print(f"{'='*55}")

    for domain in DOMAINS:
        expiry = get_cert_expiry(domain)
        if expiry is None:
            continue

        days_left = (expiry - now).days
        expiry_str = expiry.strftime("%Y-%m-%d")

        if days_left <= 0:
            status = "🔴 만료됨"
        elif days_left <= WARN_DAYS:
            status = f"🟡 {days_left}일 남음 — 갱신 필요"
            alerts.append(f"{domain}: {days_left}일 후 만료 ({expiry_str})")
        else:
            status = f"🟢 {days_left}일 남음"

        print(f"  {domain:<35} {expiry_str}  {status}")

    print(f"{'='*55}\n")

    # 경고 대상 있으면 이메일 발송
    if alerts and SEND_EMAIL:
        subject = f"[SSL 경고] 인증서 만료 임박 ({len(alerts)}건)"
        body = "만료가 임박한 인증서 목록:\n\n" + "\n".join(alerts)
        send_alert(subject, body)


if __name__ == "__main__":
    main()