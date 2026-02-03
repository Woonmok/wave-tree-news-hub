# 🖥️ iMac으로 작업 환경 이전 가이드

## 📦 방법 1: 자동 설정 스크립트 (추천)

### Mac Mini에서 준비

```bash
# 현재 디렉토리 압축
cd ~/Desktop
tar -czf wave-tree-news-hub.tar.gz wave-tree-news-hub/
```

### iMac으로 파일 전송

**방법 A: AirDrop 사용**
- Finder에서 `wave-tree-news-hub.tar.gz` 파일을 iMac으로 AirDrop

**방법 B: USB 드라이브**
- USB에 복사 → iMac에서 Desktop으로 복사

**방법 C: 네트워크 (같은 WiFi)**
```bash
# Mac Mini에서 (iMac IP가 192.168.1.100이라고 가정)
scp wave-tree-news-hub.tar.gz seunghoonoh@192.168.1.100:~/Desktop/
```

### iMac에서 설정

```bash
# 압축 해제
cd ~/Desktop
tar -xzf wave-tree-news-hub.tar.gz

# 자동 설정 실행
cd wave-tree-news-hub
./setup-imac.sh
```

## 📋 방법 2: 수동 복사

그냥 폴더 전체를 복사해도 됩니다!

### 복사할 폴더 구조
```
wave-tree-news-hub/
├── app.js                  ⭐
├── index.html             ⭐
├── backup_server.js       ⭐
├── news_hub.py            ⭐
├── sync_top_news.py       ⭐
├── data/
│   ├── normalized/
│   │   └── news.json      ⭐
│   ├── raw/
│   │   └── perplexity.txt ⭐
│   └── scrapbook/         ⭐ (백업 파일들)
├── scripts/
│   └── normalize.js       ⭐
├── *.sh                   ⭐ (모든 쉘 스크립트)
└── *.plist                ⭐ (데몬 설정)
```

### iMac에서 수동 설정

```bash
cd ~/Desktop/wave-tree-news-hub

# 1. 실행 권한 부여
chmod +x *.sh

# 2. 백업 서버 데몬 등록
./setup-backup-daemon.sh

# 3. Python 패키지 설치
pip3 install google-generativeai

# 완료!
```

## 🔧 iMac에서 첫 실행

```bash
# HTTP 서버 실행
./start-http-server.sh

# 브라우저에서 접속
open http://localhost:8000
```

## ✅ 확인 사항

### 1. 백업 서버 실행 확인
```bash
launchctl list | grep scrapbook-backup
# 결과: 숫자가 보이면 정상 실행 중
```

### 2. 로그 확인
```bash
tail -f logs/backup-server.log
```

### 3. 포트 충돌 확인
```bash
lsof -i :3001  # 백업 서버
lsof -i :8000  # HTTP 서버
```

## 🚨 문제 해결

### 백업 서버가 실행되지 않을 때

```bash
# 수동 실행 테스트
node backup_server.js

# 데몬 재시작
launchctl unload ~/Library/LaunchAgents/com.wavetree.scrapbook-backup.plist
launchctl load ~/Library/LaunchAgents/com.wavetree.scrapbook-backup.plist
```

### Python 환경 문제

```bash
# Python 버전 확인
python3 --version

# 패키지 재설치
pip3 uninstall google-generativeai
pip3 install google-generativeai
```

### 권한 문제

```bash
# 전체 실행 권한 부여
chmod +x *.sh
chmod +x scripts/*.js
```

## 📊 데이터 백업 확인

```bash
# 백업 파일 목록
ls -lh data/scrapbook/

# 최신 백업 내용 확인
cat data/scrapbook/scrapbook_*.json | jq .
```

## 💡 팁

1. **Mac Mini는 그대로 두기**: 나중에 다시 사용할 수 있도록
2. **정기 동기화**: rsync로 두 Mac 간 데이터 동기화 가능
3. **Git 사용**: 나중을 위해 Git 레포지토리 생성 추천

## 🔄 양방향 동기화 (선택)

두 Mac을 계속 사용하려면:

```bash
# Mac Mini → iMac
rsync -avz ~/Desktop/wave-tree-news-hub/ \
  seunghoonoh@iMac-IP:~/Desktop/wave-tree-news-hub/

# iMac → Mac Mini
rsync -avz ~/Desktop/wave-tree-news-hub/ \
  seunghoonoh@MacMini-IP:~/Desktop/wave-tree-news-hub/
```
