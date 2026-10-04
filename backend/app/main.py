from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import get_settings
from app.routers import activity_results, child_profiles, learner_progress, rewards

settings = get_settings()

app = FastAPI(title="AkuRin API", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(child_profiles.router)
app.include_router(activity_results.router)
app.include_router(learner_progress.router)
app.include_router(rewards.router)


@app.get("/health", tags=["health"])
def health_check() -> dict[str, str]:
    return {"status": "ok"}
