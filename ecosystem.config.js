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
      script: "serve",
      env: {
        PM2_SERVE_PATH: './build/web',
        PM2_SERVE_PORT: 3000,
        PM2_SERVE_SPA: 'true'
      },
      out_file: "../logs/flutter.log",
      error_file: "../logs/flutter.log",
      merge_logs: true
    },
    {
      name: "react-web",
      cwd: "./frontend",
      script: "serve",
      env: {
        PM2_SERVE_PATH: './dist',
        PM2_SERVE_PORT: 5000,
        PM2_SERVE_SPA: 'true'
      },
      out_file: "../logs/react.log",
      error_file: "../logs/react.log",
      merge_logs: true
    },
    {
      name: "log-viewer",
      script: "frontail",
      args: "--host 0.0.0.0 --port 9003 --theme dark /root/Snap_Khata/logs/backend.log /root/Snap_Khata/logs/flutter.log /root/Snap_Khata/logs/react.log",
    },
    {
      name: "log-downloader",
      script: "python3",
      args: "-m http.server 9002",
      cwd: "./logs" 
    }
  ]
}
