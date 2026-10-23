import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict


class PhonemeProgressRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    child_id: uuid.UUID
    language: str
    unit_label: str
    attempts: int
    successes: int
    last_score: float | None
    last_seen: datetime
    mastery: float
