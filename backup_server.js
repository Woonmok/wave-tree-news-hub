#!/usr/bin/env node
/**
 * backup_server.js - 스크랩북 백업 서버
 * 포트 3001에서 실행되며 app.js로부터 스크랩북 데이터를 받아 파일로 저장
 */

const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = 3001;
const backupDirEnv = process.env.BACKUP_DIR && process.env.BACKUP_DIR.trim();
const syncDirEnv = process.env.SYNC_DIR && process.env.SYNC_DIR.trim();
const BACKUP_DIR = backupDirEnv
  ? path.resolve(backupDirEnv)
  : path.join(__dirname, 'data', 'scrapbook');
const SYNC_DIR = syncDirEnv ? path.resolve(syncDirEnv) : null;

// 백업 디렉토리 확인/생성
if (!fs.existsSync(BACKUP_DIR)) {
  fs.mkdirSync(BACKUP_DIR, { recursive: true });
}

const server = http.createServer((req, res) => {
  // CORS 헤더 추가
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.writeHead(200);
    res.end();
    return;
  }

  if (req.method === 'GET' && (req.url === '/backup' || req.url === '/health')) {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'ok' }));
    return;
  }

  if (req.method === 'POST' && req.url === '/backup') {
    let body = '';

    req.on('data', chunk => {
      body += chunk.toString();
    });

    req.on('end', () => {
      try {
        const data = JSON.parse(body);
        const { date, items } = data;

        if (!date || !Array.isArray(items)) {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ error: 'Invalid data format' }));
          return;
        }

        // 파일명: scrapbook_2026-02-03.json
        const filename = `scrapbook_${date}.json`;
        const filepath = path.join(BACKUP_DIR, filename);

        const backupData = {
          date,
          timestamp: new Date().toISOString(),
          count: items.length,
          items
        };

        fs.writeFileSync(filepath, JSON.stringify(backupData, null, 2), 'utf-8');

        if (SYNC_DIR) {
          try {
            fs.mkdirSync(SYNC_DIR, { recursive: true });
            const syncPath = path.join(SYNC_DIR, filename);
            fs.copyFileSync(filepath, syncPath);
            console.log(`🔄 외장 동기화 완료: ${syncPath}`);
          } catch (syncError) {
            console.warn('⚠️ 외장 동기화 실패:', syncError.message || syncError);
          }
        }

        console.log(`✅ [${new Date().toLocaleString('ko-KR')}] 백업 완료: ${filename} (${items.length}개 항목)`);

        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ 
          success: true, 
          filename,
          count: items.length 
        }));

      } catch (error) {
        console.error('❌ 백업 오류:', error);
        res.writeHead(500, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: error.message }));
      }
    });
  } else {
    res.writeHead(404);
    res.end('Not Found');
  }
});

server.listen(PORT, () => {
  console.log(`🚀 스크랩북 백업 서버 실행 중: http://localhost:${PORT}`);
  console.log(`📁 백업 디렉토리: ${BACKUP_DIR}`);
  console.log(`⏰ 매일 자정 이후 첫 방문 시 자동 백업됩니다.`);
});

// 종료 시그널 처리
process.on('SIGTERM', () => {
  console.log('⏹️  서버 종료 중...');
  server.close();
  process.exit(0);
});
