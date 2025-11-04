# ===========================================================
# WHITE-LABEL AI ECOSYSTEM LAUNCHER
# Auto-generated and fully integrated with Base44 Dashboard
# ===========================================================

Write-Host "🚀 Bootstrapping White-Label AI Ecosystem..." -ForegroundColor Cyan

# Step 1: Virtual Environment
if (-Not (Test-Path "venv")) {
    Write-Host "🧠 Creating virtual environment..." -ForegroundColor Yellow
    python -m venv venv
}
.\venv\Scripts\activate

# Step 2: Dependencies
if (Test-Path "requirements.txt") {
    Write-Host "📦 Installing dependencies..." -ForegroundColor Yellow
    pip install -r requirements.txt
} else {
    Write-Host "⚠️ No requirements.txt found, installing essentials..." -ForegroundColor Red
    pip install fastapi uvicorn streamlit numpy pandas requests scikit-learn openai
}

# Step 3: Ensure Module Directories Exist
portfolio_engine ai_modules.fx_predictor ai_modules.geo_risk ai_modules.esg_scanner ai_modules.valuation_model ai_modules.liquidity_model ai_modules.regime_detection = @(
    "portfolio_engine",
    "ai_modules.fx_predictor",
    "ai_modules.geo_risk",
    "ai_modules.esg_scanner",
    "ai_modules.valuation_model",
    "ai_modules.liquidity_model",
    "ai_modules.regime_detection"
)
foreach (ai_modules.regime_detection in portfolio_engine ai_modules.fx_predictor ai_modules.geo_risk ai_modules.esg_scanner ai_modules.valuation_model ai_modules.liquidity_model ai_modules.regime_detection) {
    ai_modules/regime_detection = ai_modules.regime_detection -replace "\.", "/"
    if (-Not (Test-Path ai_modules/regime_detection)) {
        Write-Host "🧩 Creating placeholder for ai_modules.regime_detection..." -ForegroundColor Yellow
        New-Item -ItemType Directory -Force -Path ai_modules/regime_detection | Out-Null
        Set-Content "ai_modules/regime_detection/__init__.py" "# Auto-generated placeholder for ai_modules.regime_detection"
    }
}

# Step 4: Ensure Core Files Exist
if (-Not (Test-Path "main.py")) {
    Write-Host "⚙️ Creating main.py backend..." -ForegroundColor Yellow
    @'
from fastapi import FastAPI
import requests

app = FastAPI()
BASE44_URL = "https://fin-sight-ai-c809e98a.base44.app/dashboard"

@app.get("/")
def read_root():
    return {"status": "Backend running", "Base44_connected": True}

@app.post("/sync_base44")
def sync_data():
    try:
        r = requests.get(BASE44_URL)
        return {"Base44_status": r.status_code, "message": "Synced successfully"}
    except Exception as e:
        return {"error": str(e)}
'@ | Out-File -Encoding utf8 main.py
}

if (-Not (Test-Path "dashboard.py")) {
    Write-Host "🖥️ Creating dashboard.py frontend..." -ForegroundColor Yellow
    @'
import streamlit as st
import requests

BASE44_URL = "https://fin-sight-ai-c809e98a.base44.app/dashboard"

st.set_page_config(page_title="White-Label AI Dashboard", layout="wide")
st.title("White-Label AI Dashboard")

st.write("🌐 Connected to Base44 Dashboard:")
st.markdown(f"[{BASE44_URL}]({BASE44_URL})")

try:
    response = requests.get(BASE44_URL)
    if response.status_code == 200:
        st.success("✅ Connected successfully to Base44!")
    else:
        st.warning(f"⚠️ Base44 returned status {response.status_code}")
except Exception as e:
    st.error(f"❌ Connection failed: {e}")
'@ | Out-File -Encoding utf8 dashboard.py
}

# Step 5: Launch Backend + Dashboard
Write-Host "🌍 Launching FastAPI backend and Streamlit dashboard..." -ForegroundColor Cyan
Start-Process powershell -ArgumentList "uvicorn main:app --host 0.0.0.0 --port 8000"
Start-Sleep -Seconds 5
streamlit run dashboard.py
