module.exports = {
  apps: [
    {
      name: "fastapi-backend",
      cwd: "./backend",
      script: "./venv/bin/python3",
      args: "-m uvicorn main:app --host 0.0.0.0 --port 8000 --reload",
      out_file: "../logs/backend.log",
      error_file: "../logs/backend.log",
      merge_logs: true
    },
    {
      name: "flutter-web",
      cwd: "./mobile",
      script: "flutter",
      args: "run -d web-server --web-hostname 0.0.0.0 --web-port 3000",
      out_file: "../logs/flutter.log",
      error_file: "../logs/flutter.log",
      merge_logs: true
    },
    {
      name: "log-viewer",
      script: "frontail",
      args: "--port 9003 --theme dark /root/Snap_Khata/logs/backend.log /root/Snap_Khata/logs/flutter.log",
    },
    {
      name: "log-downloader",
      script: "python3",
      args: "-m http.server 9002",
      cwd: "./logs" 
    }
  ]
}
