from fastapi import FastAPI
from fastapi.responses import HTMLResponse
import os

app = FastAPI()

# Get version from environment variable (set during build)
VERSION = os.getenv("SERVICE_VERSION", "dev")

@app.get("/", response_class=HTMLResponse)
def read_root():
    return f"""
    <!DOCTYPE html>
    <html>
    <head>
      <title>Datavisyn DevOps Challenge</title>
      <style>
        body {{
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
          background: #0d1117;
          color: #c9d1d9;
          min-height: 100vh;
          display: flex;
          align-items: center;
          justify-content: center;
          margin: 0;
        }}
        .card {{
          background: #161b22;
          border: 1px solid #30363d;
          border-radius: 12px;
          padding: 40px;
          max-width: 500px;
          text-align: center;
        }}
        h1 {{
          color: #58a6ff;
          margin: 0 0 8px 0;
          font-size: 1.8rem;
        }}
        .subtitle {{
          color: #8b949e;
          margin-bottom: 24px;
        }}
        .stack {{
          display: flex;
          flex-wrap: wrap;
          gap: 8px;
          justify-content: center;
          margin-bottom: 24px;
        }}
        .tag {{
          background: #21262d;
          border: 1px solid #30363d;
          padding: 6px 12px;
          border-radius: 16px;
          font-size: 0.85rem;
        }}
        .status {{
          color: #3fb950;
          font-size: 0.9rem;
        }}
        .status::before {{
          content: '●';
          margin-right: 6px;
        }}
        .version {{
          color: #8b949e;
          font-size: 0.75rem;
          margin-top: 20px;
        }}
      </style>
    </head>
    <body>
      <div class="card">
        <h1>Datavisyn DevOps Challenge</h1>
        <p class="subtitle">Kubernetes + GitOps Infrastructure Demo</p>
        <div class="stack">
          <span class="tag">EKS</span>
          <span class="tag">Terraform</span>
          <span class="tag">ArgoCD</span>
          <span class="tag">Helm</span>
          <span class="tag">GitHub Actions</span>
          <span class="tag">OAuth2</span>
          <span class="tag">Let's Encrypt</span>
        </div>
        <p class="status">Good news: All systems operational!</p>
        <p class="version">Version: {VERSION}</p>
      </div>
    </body>
    </html>
    """

@app.get("/health")
def health():
    return {"status": "healthy", "version": VERSION}

# Initial-build 
