import json
import os
from typing import Any, Dict, List, Optional

from app.models.company import Company
from app.models.project import Project


class DataService:
    def __init__(self):
        self.data_dir = os.path.join(os.path.dirname(__file__), '..', 'data')
        self.companies_file = os.path.join(self.data_dir, 'companies.json')
        self.projects_file = os.path.join(self.data_dir, 'projects.json')
    
    def _load_json(self, file_path: str) -> Dict[str, Any]:
        """Load JSON data from file"""
        try:
            with open(file_path, 'r') as f:
                return json.load(f)
        except FileNotFoundError:
            return {}
        except json.JSONDecodeError:
            return {}
    
    def _save_json(self, file_path: str, data: Dict[str, Any]) -> bool:
        """Save JSON data to file"""
        try:
            with open(file_path, 'w') as f:
                json.dump(data, f, indent=2)
            return True
        except Exception:
            return False
    
    # Company methods
    def get_companies(self) -> List[Company]:
        """Get all companies"""
        data = self._load_json(self.companies_file)
        companies = data.get('companies', [])
        return [Company(**company) for company in companies]
    
    def get_company(self, company_id: int) -> Optional[Company]:
        """Get company by ID"""
        companies = self.get_companies()
        for company in companies:
            if company.id == company_id:
                return company
        return None
    
    def get_company_projects(self, company_id: int) -> List[Project]:
        """Get all projects for a company"""
        data = self._load_json(self.projects_file)
        projects = data.get('projects', [])
        company_projects = [p for p in projects if company_id in p.get('company_id', [])]
        return [Project(**project) for project in company_projects]
    
    def create_company(self, company_data: Dict[str, Any]) -> Optional[Company]:
        """Create a new company"""
        data = self._load_json(self.companies_file)
        companies = data.get('companies', [])
        
        # Generate new ID
        max_id = max([c.get('id', 0) for c in companies], default=0)
        company_data['id'] = max_id + 1
        company_data['project_count'] = 0
        
        companies.append(company_data)
        data['companies'] = companies
        
        if self._save_json(self.companies_file, data):
            return Company(**company_data)
        return None
    
    def update_company(self, company_id: int, update_data: Dict[str, Any]) -> Optional[Company]:
        """Update a company"""
        data = self._load_json(self.companies_file)
        companies = data.get('companies', [])
        
        for i, company in enumerate(companies):
            if company.get('id') == company_id:
                # Update only provided fields
                for key, value in update_data.items():
                    if value is not None:
                        company[key] = value
                
                companies[i] = company
                data['companies'] = companies
                
                if self._save_json(self.companies_file, data):
                    return Company(**company)
                break
        return None
    
    def delete_company(self, company_id: int) -> bool:
        """Delete a company"""
        data = self._load_json(self.companies_file)
        companies = data.get('companies', [])
        
        original_count = len(companies)
        companies = [c for c in companies if c.get('id') != company_id]
        
        if len(companies) < original_count:
            data['companies'] = companies
            return self._save_json(self.companies_file, data)
        return False
    
    # Project methods
    def get_projects(self, company_id: Optional[int] = None) -> List[Project]:
        """Get all projects, optionally filtered by company_id"""
        data = self._load_json(self.projects_file)
        projects = data.get('projects', [])
        
        if company_id is not None:
            projects = [p for p in projects if company_id in p.get('company_id', [])]
        
        return [Project(**project) for project in projects]
    
    def get_project(self, project_id: int) -> Optional[Project]:
        """Get project by ID"""
        data = self._load_json(self.projects_file)
        projects = data.get('projects', [])
        
        for project in projects:
            if project.get('id') == project_id:
                return Project(**project)
        return None
    
    def create_project(self, project_data: Dict[str, Any]) -> Optional[Project]:
        """Create a new project"""
        data = self._load_json(self.projects_file)
        projects = data.get('projects', [])
        
        # Generate new ID
        max_id = max([p.get('id', 0) for p in projects], default=0)
        project_data['id'] = max_id + 1
        
        projects.append(project_data)
        data['projects'] = projects
        
        if self._save_json(self.projects_file, data):
            # Update company project count
            company_ids = project_data.get('company_id', [])
            for company_id in company_ids:
                self._update_company_project_count(company_id)
            return Project(**project_data)
        return None
    
    def update_project(self, project_id: int, update_data: Dict[str, Any]) -> Optional[Project]:
        """Update a project"""
        data = self._load_json(self.projects_file)
        projects = data.get('projects', [])
        
        for i, project in enumerate(projects):
            if project.get('id') == project_id:
                # Update only provided fields
                for key, value in update_data.items():
                    if value is not None:
                        project[key] = value
                
                projects[i] = project
                data['projects'] = projects
                
                if self._save_json(self.projects_file, data):
                    return Project(**project)
                break
        return None
    
    def delete_project(self, project_id: int) -> bool:
        """Delete a project"""
        data = self._load_json(self.projects_file)
        projects = data.get('projects', [])
        
        # Find project to get company_id
        project_to_delete = None
        for project in projects:
            if project.get('id') == project_id:
                project_to_delete = project
                break
        
        if project_to_delete:
            original_count = len(projects)
            projects = [p for p in projects if p.get('id') != project_id]
            
            if len(projects) < original_count:
                data['projects'] = projects
                if self._save_json(self.projects_file, data):
                    # Update company project count
                    company_id = project_to_delete.get('company_id')
                    if company_id:
                        self._update_company_project_count(company_id)
                    return True
        return False
    
    def _update_company_project_count(self, company_id: int):
        """Update the project count for a company"""
        data = self._load_json(self.companies_file)
        companies = data.get('companies', [])
        
        for company in companies:
            if company.get('id') == company_id:
                # Count projects for this company
                project_count = len(self.get_company_projects(company_id))
                company['project_count'] = project_count
                break
        
        data['companies'] = companies
        self._save_json(self.companies_file, data)


# Global data service instance
data_service = DataService()
