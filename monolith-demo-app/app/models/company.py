from typing import List, Optional

from pydantic import BaseModel


class Company(BaseModel):
    id: int
    name: str
    type: str
    founded: int
    headquarters: str
    specialties: List[str]
    employee_count: int
    annual_revenue: int
    project_count: int
    website: str
    phone: str
    email: str


class CompanyCreate(BaseModel):
    name: str
    type: str
    founded: int
    headquarters: str
    specialties: List[str]
    employee_count: int
    annual_revenue: int
    website: str
    phone: str
    email: str


class CompanyUpdate(BaseModel):
    name: Optional[str] = None
    type: Optional[str] = None
    founded: Optional[int] = None
    headquarters: Optional[str] = None
    specialties: Optional[List[str]] = None
    employee_count: Optional[int] = None
    annual_revenue: Optional[int] = None
    project_count: Optional[int] = None
    website: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[str] = None
