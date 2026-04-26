from datetime import date

from taskflow.models import Task, TaskStatus
from taskflow.repository import InMemoryTaskRepository


class TaskService:
    def __init__(self, repository: InMemoryTaskRepository) -> None:
        self._repository = repository

    def create_task(self, title: str, description: str, due_date: date) -> Task:
        return self._repository.add(title, description, due_date)

    def change_status(self, task_id: int, status: TaskStatus) -> Task:
        return self._repository.update_status(task_id, status)

    def list_by_status(self, status: TaskStatus) -> list[Task]:
        return self._repository.list_by_status(status)
