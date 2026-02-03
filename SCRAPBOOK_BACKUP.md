# 📌 스크랩북 자동 백업 시스템

## 📖 개요

매일 중요한 뉴스를 스크랩북에 저장하고, 다음날 자동으로 백업한 후 초기화되는 시스템입니다.

## 🚀 설정 방법

### 1. 백업 서버 실행 (필수)

```bash
# 수동 실행
./start-backup-server.sh

# 또는 직접 실행
node backup_server.js
```

### 2. 자동 시작 설정 (선택 - 추천)

시스템 부팅 시 자동으로 백업 서버가 실행되도록 설정:

```bash
./setup-backup-daemon.sh
```

## 📋 작동 방식

1. **매일 뉴스 스크랩**: 중요한 뉴스를 스크랩북(💾 버튼)에 저장
2. **자동 백업**: 다음날 첫 방문 시 자동으로 어제 날짜로 백업
   - 백업 위치: `data/scrapbook/scrapbook_2026-02-03.json`
3. **자동 초기화**: 백업 후 스크랩북이 자동으로 비워짐
4. **새로운 하루**: 깨끗한 스크랩북으로 다시 시작

## 📁 백업 파일 구조

```json
{
  "date": "2026-02-03",
  "timestamp": "2026-02-04T00:05:32.123Z",
  "count": 5,
  "items": [
    {
      "id": "...",
      "category": "listeria_free",
      "title": "...",
      "url": "...",
      "saved_at": "..."
    }
  ]
}
```

## 🔧 유용한 명령어

### 백업 서버 관리

```bash
# 상태 확인
launchctl list | grep scrapbook-backup

# 서버 중지
launchctl unload ~/Library/LaunchAgents/com.wavetree.scrapbook-backup.plist

# 서버 재시작
launchctl unload ~/Library/LaunchAgents/com.wavetree.scrapbook-backup.plist
launchctl load ~/Library/LaunchAgents/com.wavetree.scrapbook-backup.plist

# 로그 확인
tail -f logs/backup-server.log
```

### 백업 파일 확인

```bash
# 백업 파일 목록
ls -lh data/scrapbook/

# 특정 날짜 백업 내용 확인
cat data/scrapbook/scrapbook_2026-02-03.json | jq .

# 백업 통계
find data/scrapbook -name "*.json" | wc -l
```

## ⚠️  주의사항

1. **백업 서버 필수**: 백업 서버가 실행되지 않으면 백업되지 않습니다
2. **포트 3001 사용**: 다른 프로그램이 포트 3001을 사용 중이면 충돌 발생
3. **수동 백업**: 서버가 실행되지 않아도 스크랩북은 localStorage에 계속 저장됩니다

## 🐛 문제 해결

### 백업이 되지 않을 때

1. 백업 서버 실행 확인: `launchctl list | grep scrapbook-backup`
2. 로그 확인: `tail -f logs/backup-server.log`
3. 수동으로 서버 실행: `node backup_server.js`
4. 브라우저 콘솔 확인: F12 → Console 탭

### 백업 서버 재시작

```bash
./start-backup-server.sh
```

## 📊 백업 이력 조회

Python으로 백업 통계 확인:

```python
import json
from pathlib import Path

backup_dir = Path("data/scrapbook")
for backup_file in sorted(backup_dir.glob("*.json")):
    with open(backup_file) as f:
        data = json.load(f)
    print(f"{data['date']}: {data['count']}개 항목")
```

## 🎯 다음 단계

- [ ] 백업 파일을 woonmok.github.io에도 동기화
- [ ] 주간/월간 백업 요약 생성
- [ ] 백업 파일 압축 (7일 이상 된 파일)
