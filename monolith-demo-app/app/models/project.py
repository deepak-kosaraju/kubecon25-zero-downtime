from typing import List, Optional

from pydantic import BaseModel


class Task(BaseModel):
    id: int
    name: str
    status: str
    completion_date: Optional[str] = None


class Project(BaseModel):
    id: int
    name: str
    company_id: List[int]
    status: str
    start_date: str
    end_date: str
    budget: int
    location: str
    project_type: str
    square_footage: int
    floors: int
    architect: str
    tasks: List[Task]


class ProjectCreate(BaseModel):
    name: str
    company_id: List[int]
    status: str
    start_date: str
    end_date: str
    budget: int
    location: str
    project_type: str
    square_footage: int
    floors: int
    architect: str
    tasks: List[Task]


class ProjectUpdate(BaseModel):
    name: Optional[str] = None
    company_id: Optional[List[int]] = None
    status: Optional[str] = None
    start_date: Optional[str] = None
    end_date: Optional[str] = None
    budget: Optional[int] = None
    location: Optional[str] = None
    project_type: Optional[str] = None
    square_footage: Optional[int] = None
    floors: Optional[int] = None
    architect: Optional[str] = None
    tasks: Optional[List[Task]] = None


class ProjectSummary(BaseModel):
    id: int
    name: str
    status: str
    budget: int
    location: str
    project_type: str
