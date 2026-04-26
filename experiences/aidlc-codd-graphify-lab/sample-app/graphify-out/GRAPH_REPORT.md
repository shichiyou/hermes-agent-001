# Graph Report - /workspaces/hermes-agent-001/experiences/aidlc-codd-graphify-lab/sample-app  (2026-04-26)

## Corpus Check
- 6 files · ~333 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 23 nodes · 45 edges · 6 communities detected
- Extraction: 40% EXTRACTED · 60% INFERRED · 0% AMBIGUOUS · INFERRED: 27 edges (avg confidence: 0.7)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 4|Community 4]]
- [[_COMMUNITY_Community 5|Community 5]]

## God Nodes (most connected - your core abstractions)
1. `InMemoryTaskRepository` - 12 edges
2. `TaskService` - 12 edges
3. `test_mark_task_done_moves_it_between_status_lists()` - 6 edges
4. `main()` - 6 edges
5. `Task` - 6 edges
6. `test_create_task_defaults_to_todo_and_can_list_by_status()` - 5 edges
7. `TaskFlow Mini sample application.` - 5 edges
8. `TaskStatus` - 5 edges

## Surprising Connections (you probably didn't know these)
- `test_create_task_defaults_to_todo_and_can_list_by_status()` --calls--> `TaskService`  [INFERRED]
  /workspaces/hermes-agent-001/experiences/aidlc-codd-graphify-lab/sample-app/tests/test_taskflow.py → /workspaces/hermes-agent-001/experiences/aidlc-codd-graphify-lab/sample-app/src/taskflow/service.py
- `test_create_task_defaults_to_todo_and_can_list_by_status()` --calls--> `InMemoryTaskRepository`  [INFERRED]
  /workspaces/hermes-agent-001/experiences/aidlc-codd-graphify-lab/sample-app/tests/test_taskflow.py → /workspaces/hermes-agent-001/experiences/aidlc-codd-graphify-lab/sample-app/src/taskflow/repository.py
- `test_mark_task_done_moves_it_between_status_lists()` --calls--> `TaskService`  [INFERRED]
  /workspaces/hermes-agent-001/experiences/aidlc-codd-graphify-lab/sample-app/tests/test_taskflow.py → /workspaces/hermes-agent-001/experiences/aidlc-codd-graphify-lab/sample-app/src/taskflow/service.py
- `test_mark_task_done_moves_it_between_status_lists()` --calls--> `InMemoryTaskRepository`  [INFERRED]
  /workspaces/hermes-agent-001/experiences/aidlc-codd-graphify-lab/sample-app/tests/test_taskflow.py → /workspaces/hermes-agent-001/experiences/aidlc-codd-graphify-lab/sample-app/src/taskflow/repository.py
- `InMemoryTaskRepository` --uses--> `TaskStatus`  [INFERRED]
  /workspaces/hermes-agent-001/experiences/aidlc-codd-graphify-lab/sample-app/src/taskflow/repository.py → /workspaces/hermes-agent-001/experiences/aidlc-codd-graphify-lab/sample-app/src/taskflow/models.py

## Communities

### Community 0 - "Community 0"
Cohesion: 0.32
Nodes (3): TaskFlow Mini sample application., Task, InMemoryTaskRepository

### Community 1 - "Community 1"
Cohesion: 0.67
Nodes (2): test_create_task_defaults_to_todo_and_can_list_by_status(), test_mark_task_done_moves_it_between_status_lists()

### Community 2 - "Community 2"
Cohesion: 0.67
Nodes (1): TaskService

### Community 3 - "Community 3"
Cohesion: 0.67
Nodes (1): main()

### Community 4 - "Community 4"
Cohesion: 1.0
Nodes (2): Enum, TaskStatus

### Community 5 - "Community 5"
Cohesion: 1.0
Nodes (0): 

## Knowledge Gaps
- **Thin community `Community 5`** (2 nodes): `.add()`, `.create_task()`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `InMemoryTaskRepository` connect `Community 0` to `Community 1`, `Community 2`, `Community 3`, `Community 4`, `Community 5`?**
  _High betweenness centrality (0.398) - this node is a cross-community bridge._
- **Why does `TaskService` connect `Community 2` to `Community 0`, `Community 1`, `Community 3`, `Community 4`, `Community 5`?**
  _High betweenness centrality (0.347) - this node is a cross-community bridge._
- **Why does `TaskStatus` connect `Community 4` to `Community 0`, `Community 2`?**
  _High betweenness centrality (0.113) - this node is a cross-community bridge._
- **Are the 7 inferred relationships involving `InMemoryTaskRepository` (e.g. with `Task` and `TaskStatus`) actually correct?**
  _`InMemoryTaskRepository` has 7 INFERRED edges - model-reasoned connections that need verification._
- **Are the 7 inferred relationships involving `TaskService` (e.g. with `Task` and `TaskStatus`) actually correct?**
  _`TaskService` has 7 INFERRED edges - model-reasoned connections that need verification._
- **Are the 5 inferred relationships involving `test_mark_task_done_moves_it_between_status_lists()` (e.g. with `TaskService` and `InMemoryTaskRepository`) actually correct?**
  _`test_mark_task_done_moves_it_between_status_lists()` has 5 INFERRED edges - model-reasoned connections that need verification._
- **Are the 5 inferred relationships involving `main()` (e.g. with `TaskService` and `InMemoryTaskRepository`) actually correct?**
  _`main()` has 5 INFERRED edges - model-reasoned connections that need verification._