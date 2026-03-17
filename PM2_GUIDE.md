# SnapKhata PM2 Management Guide

This guide contains all the commands needed to manage the SnapKhata ecosystem.

## 🚀 Quick Start
Run this to launch all 4 apps (Backend, Frontend, Log Viewer, Log Downloader):
```bash
pm2 start ecosystem.config.js
```

## 📋 Status & Monitoring
Check if everything is running:
```bash
pm2 status
```

Monitor logs in real-time:
```bash
pm2 logs
```

## 🛑 Management Commands
- **Stop all services:** `pm2 stop all`
- **Restart all services:** `pm2 restart all`
- **Delete/Clear all traces:** `pm2 delete all`
- **Save current state (for auto-start on reboot):** `pm2 save`

## 🔍 Specific Service Management
- **Backend only:** `pm2 restart fastapi-backend`
- **Frontend only:** `pm2 restart flutter-web`
- **Log Viewer only:** `pm2 restart log-viewer`

## 🌐 Web Dashboards
- **Log Viewer (Frontail):** [http://localhost:9003](http://localhost:9003)
- **Log Downloader:** [http://localhost:9002](http://localhost:9002)
- **FastAPI Backend:** [http://localhost:8000](http://localhost:8000)
- **Flutter Web:** [http://localhost:3000](http://localhost:3000)

## 🛠 Troubleshooting
If port 9003 is blocked or the log viewer is looping, run:
```bash
fuser -k 9003/tcp && pm2 restart log-viewer
```
