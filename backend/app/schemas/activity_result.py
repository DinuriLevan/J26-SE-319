import uuid
from datetime import datetime
from typing import Any

from pydantic import BaseModel, ConfigDict


class ActivityResultCreate(BaseModel):
    child_id: uuid.UUID
    component_name: str
    activity_id: str
    result_payload: dict[str, Any]


class ActivityResultRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    child_id: uuid.UUID
    component_name: str
    activity_id: str
    result_payload: dict[str, Any]
    created_at: datetime
