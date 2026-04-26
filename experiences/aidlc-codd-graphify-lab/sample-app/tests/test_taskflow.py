from datetime import date

from taskflow.models import TaskStatus
from taskflow.repository import InMemoryTaskRepository
from taskflow.service import TaskService


def test_create_task_defaults_to_todo_and_can_list_by_status():
    service = TaskService(InMemoryTaskRepository())

    task = service.create_task(
        title="Write lab README",
        description="Record official setup evidence",
        due_date=date(2026, 4, 30),
    )

    assert task.status is TaskStatus.TODO
    assert service.list_by_status(TaskStatus.TODO) == [task]
    assert service.list_by_status(TaskStatus.DONE) == []


def test_mark_task_done_moves_it_between_status_lists():
    service = TaskService(InMemoryTaskRepository())
    task = service.create_task(
        title="Run graphify",
        description="Generate graphify-out artifacts",
        due_date=date(2026, 4, 30),
    )

    updated = service.change_status(task.id, TaskStatus.DONE)

    assert updated.status is TaskStatus.DONE
    assert service.list_by_status(TaskStatus.TODO) == []
    assert service.list_by_status(TaskStatus.DONE) == [updated]
