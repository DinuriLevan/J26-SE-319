import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict


class ChildProfileCreate(BaseModel):
    id: uuid.UUID
    name: str
    preferred_language: str
    grade: int | None = None


class ChildProfileRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    name: str
    preferred_language: str
    grade: int | None
    created_at: datetime
