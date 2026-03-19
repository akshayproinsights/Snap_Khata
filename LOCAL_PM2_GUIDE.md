# SnapKhata Local Development & PM2 Guide

This guide describes how to start and manage the SnapKhata ecosystem locally.

## 🚀 Quick Start
To start all services (Backend, React Frontend, Flutter Frontend, Logs):
```bash
pm2 start ecosystem.config.js
```

## 📋 Services & URLs
Once started, you can access the applications at:

| Service | Port | URL |
|---------|------|-----|
| **React Web App** | 5000 | [http://localhost:5000](http://localhost:5000) |
| **Flutter Web App** | 3000 | [http://localhost:3000](http://localhost:3000) |
| **FastAPI Backend** | 8000 | [http://localhost:8000](http://localhost:8000) |
| **Log Viewer** | 9003 | [http://localhost:9003](http://localhost:9003) |
| **Log Downloader** | 9002 | [http://localhost:9002](http://localhost:9002) |

## 🛠 Setup & Requirements
### 1. Environment Variables
The backend requires a `.env` file in the `backend/` directory.
```bash
cp .env backend/.env
```
*(Ensure the root `.env` contains the latest Supabase and Gemini API keys)*

### 2. Dependencies
- **Backend**: Uses a virtual environment in `backend/venv/`.
- **Node.js**: Requires `pm2`, `serve`, and `frontail` installed globally.

## 🛑 Management Commands
- **Check Status**: `pm2 status`
- **View Logs**: `pm2 logs`
- **Stop All**: `pm2 stop all`
- **Restart All**: `pm2 restart all`
- **Clear Everything**: `pm2 delete all`

## 🔍 Troubleshooting (Local Access)
If you see **"refused to connect"** on localhost:
1. **VS Code Port Forwarding**: Open the "Ports" tab in VS Code and ensure ports **8000, 5000, 3000, and 9003** are forwarded.
2. **Logs**: Check `pm2 logs log-viewer` to see if the frontail service is crashing.
3. **Log Files**: Ensure `logs/backend.log`, `logs/flutter.log`, and `logs/react.log` exist.
