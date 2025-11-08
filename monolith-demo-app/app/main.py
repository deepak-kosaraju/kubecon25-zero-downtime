import asyncio
import random
import time
from contextlib import asynccontextmanager
from typing import List, Optional

from fastapi import FastAPI, HTTPException, Query
from rich.console import Console

from app.models.company import Company, CompanyCreate, CompanyUpdate
from app.models.project import Project, ProjectCreate, ProjectSummary, ProjectUpdate
from app.services.data_service import data_service
from app.utils.metadata import (
    get_all_status_code_details,
    get_node_name,
    get_pod_name,
    get_worker_id,
)

initializers = ["caches", "databases", "client connections"]
WORKER_ID = get_worker_id()
POD_NAME = get_pod_name()
NODE_NAME = get_node_name()
ALL_STATUS_CODE_DETAILS = get_all_status_code_details()

console = Console()
# progress = Progress()
# progress.start()

# Define the lifespan context manager
@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Run at startup: Simulate a slow start by introducing a delay.
    Initialize resources here.
    """
    print(f"Application startup initiated (Worker {WORKER_ID}): Simulating slow start...")
    start_time = time.time()
    with console.status(f"[bold green]App Initializing (Worker {WORKER_ID})...") as status:
        for initializer in initializers:
            status.update(f"[bold blue] Worker {WORKER_ID} - Initializing {initializer}...")
            init_start_time = time.time()
            if initializer != "databases":
                await asyncio.sleep(random.randrange(1,5))
            else:
                await asyncio.sleep(random.randrange(5,10))
            console.log(f"[bold green]Worker {WORKER_ID} - Initialized {initializer} in {time.time() - init_start_time:.2f} seconds.")
        status.update(
            f"[bold blue]Worker {WORKER_ID} - Initializing Background Task and Resource Acquisition"
        )
        _final_sleep = random.randrange(1,5)
        await asyncio.sleep(_final_sleep)  # Simulate max of 40 seconds of delay
        console.log(f"[bold green]Worker {WORKER_ID} - Initialized Background Task and Resource Acquisition in {_final_sleep:.2f} seconds.")
    console.log(f"Application startup complete (Worker {WORKER_ID}): Resources initialized in [bold blue]{time.time() - start_time:.2f} seconds.")
    yield  # The FastAPI application will now handle requests
    """
    Run on shutdown: Clean up resources here.
    """
    start_time = time.time()
    with console.status(f"[bold green]Application shutdown (Worker {WORKER_ID})...") as status:
        status.update(
            f"[bold blue]Worker {WORKER_ID} - Cleaning up resources"
        )
        await asyncio.sleep(random.randrange(5,15))
    console.log(f"[bold green]Worker {WORKER_ID} - Application shutdown complete: Resources cleaned up in {time.time() - start_time:.2f} seconds.")

app = FastAPI(
    title="Construction Management API",
    description="A fictional construction management system API for zero-downtime migration demo",
    version="1.2.0",
    lifespan=lifespan,
)

# Simulate realistic response times
def simulate_database_delay(delay_min: float = 0.2, delay_max: float = 1.0):
    """Simulate realistic database query delay - 200ms to 1s for production-like behavior"""
    time.sleep(random.uniform(delay_min, delay_max))

def simulate_delay(delay_max: float):
    """Simulate realistic delay - 100ms to max_delay for production-like behavior"""
    time.sleep(random.uniform(0.1, delay_max))

@app.api_route("/", methods=["GET", "HEAD"])
def read_root():
    return {
        "message": app.title,
        "version": app.version,
        "status": app.description,
        "pod_name": POD_NAME,
        "node_name": NODE_NAME
    }

@app.api_route("/health", methods=["GET", "HEAD"])
def health_check():
    return {"status": "healthy", "service": "construction-management-api", "pod_name": POD_NAME, "node_name": NODE_NAME}

@app.get("/sleep/{sleep_time}")
def sleep_route(sleep_time: float):
    """Simulate long-running operations"""
    time.sleep(sleep_time)
    return {"slept_for": sleep_time, "message": "Operation completed"}

# Company Endpoints
@app.get("/companies", response_model=List[Company])
def get_companies():
    """Get all companies"""
    simulate_database_delay(delay_max=4.0)
    return data_service.get_companies()

@app.get("/companies/{company_id}", response_model=Company)
def get_company(company_id: int):
    """Get a specific company by ID"""
    simulate_database_delay()
    company = data_service.get_company(company_id)
    if not company:
        raise HTTPException(status_code=404, detail=f"Company with ID {company_id} not found")
    return company

@app.get("/companies/{company_id}/projects", response_model=List[ProjectSummary])
def get_company_projects(company_id: int):
    """Get all projects for a specific company"""
    simulate_database_delay()
    company = data_service.get_company(company_id)
    if not company:
        raise HTTPException(status_code=404, detail=f"Company with ID {company_id} not found")
    
    projects = data_service.get_company_projects(company_id)
    return [ProjectSummary(
        id=p.id,
        name=p.name,
        status=p.status,
        budget=p.budget,
        location=p.location,
        project_type=p.project_type
    ) for p in projects]

@app.post("/companies", response_model=Company)
def create_company(company: CompanyCreate):
    """Create a new company"""
    simulate_database_delay()
    company_data = company.dict()
    new_company = data_service.create_company(company_data)
    if not new_company:
        raise HTTPException(status_code=500, detail="Failed to create company")
    return new_company

@app.put("/companies/{company_id}", response_model=Company)
def update_company(company_id: int, company_update: CompanyUpdate):
    """Update a company"""
    simulate_database_delay()
    update_data = {k: v for k, v in company_update.dict().items() if v is not None}
    updated_company = data_service.update_company(company_id, update_data)
    if not updated_company:
        raise HTTPException(status_code=404, detail=f"Company with ID {company_id} not found")
    return updated_company

@app.delete("/companies/{company_id}")
def delete_company(company_id: int):
    """Delete a company"""
    simulate_database_delay()
    success = data_service.delete_company(company_id)
    if not success:
        raise HTTPException(status_code=404, detail=f"Company with ID {company_id} not found")
    return {"message": f"Company {company_id} deleted successfully"}

# Project Endpoints
@app.get("/projects", response_model=List[Project])
def get_projects(company_id: Optional[int] = Query(None, description="Filter by company ID")):
    """Get all projects, optionally filtered by company_id"""
    simulate_database_delay()
    return data_service.get_projects(company_id)

@app.get("/projects/{project_id}", response_model=Project)
def get_project(project_id: int):
    """Get a specific project by ID"""
    simulate_database_delay()
    project = data_service.get_project(project_id)
    if not project:
        raise HTTPException(status_code=404, detail=f"Project with ID {project_id} not found")
    return project

@app.post("/projects", response_model=Project)
def create_project(project: ProjectCreate):
    """Create a new project"""
    simulate_database_delay()
    
    # Validate company exists
    company = data_service.get_company(project.company_id)
    if not company:
        raise HTTPException(status_code=400, detail=f"Company with ID {project.company_id} not found")
    
    project_data = project.dict()
    new_project = data_service.create_project(project_data)
    if not new_project:
        raise HTTPException(status_code=500, detail="Failed to create project")
    return new_project

@app.put("/projects/{project_id}", response_model=Project)
def update_project(project_id: int, project_update: ProjectUpdate):
    """Update a project"""
    simulate_database_delay()
    
    # If updating company_id, validate company exists
    if project_update.company_id is not None:
        company = data_service.get_company(project_update.company_id)
        if not company:
            raise HTTPException(status_code=400, detail=f"Company with ID {project_update.company_id} not found")
    
    update_data = {k: v for k, v in project_update.dict().items() if v is not None}
    updated_project = data_service.update_project(project_id, update_data)
    if not updated_project:
        raise HTTPException(status_code=404, detail=f"Project with ID {project_id} not found")
    return updated_project

@app.delete("/projects/{project_id}")
def delete_project(project_id: int):
    """Delete a project"""
    simulate_database_delay()
    success = data_service.delete_project(project_id)
    if not success:
        raise HTTPException(status_code=404, detail=f"Project with ID {project_id} not found")
    return {"message": f"Project {project_id} deleted successfully"}

@app.get("/status/{status_code}")
def status_route(status_code: int):
    """Simulate a status code for testing error handling"""
    if status_code in ALL_STATUS_CODE_DETAILS:
        simulate_delay(delay_max=ALL_STATUS_CODE_DETAILS.get(status_code).get("max_delay"))
        message = ALL_STATUS_CODE_DETAILS.get(status_code).get("message")
        description = ALL_STATUS_CODE_DETAILS.get(status_code).get("description")
    else:
        raise HTTPException(status_code=400, detail=f"Invalid status code: {status_code}. Must be one of: {ALL_STATUS_CODE_DETAILS}")
    raise HTTPException(status_code=status_code, detail=f"{message}: {description}")
