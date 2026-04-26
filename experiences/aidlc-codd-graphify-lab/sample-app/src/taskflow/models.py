from dataclasses import dataclass
from datetime import date
from enum import Enum


class TaskStatus(Enum):
    TODO = "todo"
    DOING = "doing"
    DONE = "done"


@dataclass(frozen=True)
class Task:
    id: int
    title: str
    description: str
    due_date: date
    status: TaskStatus = TaskStatus.TODO
