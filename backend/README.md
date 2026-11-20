# Varanti FastAPI backend

Copy `../.env.example` to `.env` in this folder and fill secrets.

```bash
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

See [docs/MASTER.md](../docs/MASTER.md).
