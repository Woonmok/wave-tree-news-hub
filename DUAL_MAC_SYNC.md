# 집/사무실 맥 동기화 가이드

## 1) 사무실/집 공통으로 1회 실행

```bash
cd /Volumes/AI_WORKSPACE/projects/wave-tree-news-hub
/bin/bash scripts/sync_dual_mac_setup.sh
```

## 2) 하는 일

- Homebrew 패키지 점검/설치: `git`, `node`, `python@3.14`, `jq`
- `wave-tree-news-hub/.venv` 재생성 + `requirements.txt` 설치
- `woonmok.github.io/.venv` 재생성 + 핵심 패키지 설치(`python-dotenv`, `requests`)
- Daily 자동화 cron 재등록
  - `50 6 * * * /bin/bash .../run_7am_publish.sh`
  - `0 7 * * * /bin/bash .../run_daily_bridge.sh`

## 3) jq 설치가 권한으로 실패할 때

```bash
sudo chown -R $(whoami) /usr/local/share/man/man8
chmod u+w /usr/local/share/man/man8
brew install jq
```

## 4) VS Code 인터프리터 확인

각 프로젝트에서 아래 경로를 사용:
- `wave-tree-news-hub/.venv/bin/python`
- `woonmok.github.io/.venv/bin/python`

필요하면 `Developer: Reload Window` 후 `Python: Select Interpreter`로 재선택.
