import uuid
from datetime import datetime
from typing import Any

from pydantic import BaseModel, ConfigDict


class LearnerProgressUpdate(BaseModel):
    progress_data: dict[str, Any]


class LearnerProgressRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    child_id: uuid.UUID
    component_name: str
    progress_data: dict[str, Any]
    updated_at: datetime
