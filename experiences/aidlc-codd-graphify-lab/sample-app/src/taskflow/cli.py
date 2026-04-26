from datetime import date

from taskflow.models import TaskStatus
from taskflow.repository import InMemoryTaskRepository
from taskflow.service import TaskService


def main() -> None:
    service = TaskService(InMemoryTaskRepository())
    task = service.create_task(
        title="Run lab",
        description="Generate CoDD and Graphify evidence",
        due_date=date.today(),
    )
    print(f"created task #{task.id}: {task.title} [{task.status.value}]")
    service.change_status(task.id, TaskStatus.DONE)
    print(f"done tasks: {len(service.list_by_status(TaskStatus.DONE))}")


if __name__ == "__main__":
    main()
