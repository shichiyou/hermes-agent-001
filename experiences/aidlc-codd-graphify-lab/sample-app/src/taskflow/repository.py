from taskflow.models import Task, TaskStatus


class InMemoryTaskRepository:
    def __init__(self) -> None:
        self._tasks: dict[int, Task] = {}
        self._next_id = 1

    def add(self, title: str, description: str, due_date) -> Task:
        task = Task(
            id=self._next_id,
            title=title,
            description=description,
            due_date=due_date,
        )
        self._tasks[task.id] = task
        self._next_id += 1
        return task

    def update_status(self, task_id: int, status: TaskStatus) -> Task:
        task = self._tasks[task_id]
        updated = Task(
            id=task.id,
            title=task.title,
            description=task.description,
            due_date=task.due_date,
            status=status,
        )
        self._tasks[task_id] = updated
        return updated

    def list_by_status(self, status: TaskStatus) -> list[Task]:
        return [task for task in self._tasks.values() if task.status is status]
