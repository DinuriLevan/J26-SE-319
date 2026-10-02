import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict


class CardUnlockCreate(BaseModel):
    card_id: str


class CardUnlockRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    child_id: uuid.UUID
    card_id: str
    unlocked_at: datetime
