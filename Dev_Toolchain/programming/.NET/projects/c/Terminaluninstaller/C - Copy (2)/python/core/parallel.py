"""
Parallel execution module for Ultimate Uninstaller
Provides thread pools, task queues, and concurrent execution
"""

import os
import queue
import threading
import time
from concurrent.futures import ThreadPoolExecutor, ProcessPoolExecutor, as_completed
from typing import Callable, List, Dict, Any, Optional, Tuple, Iterator
from dataclasses import dataclass, field
from enum import Enum, auto
from collections import defaultdict
import multiprocessing


class TaskStatus(Enum):
    """Task execution status"""
    PENDING = auto()
    RUNNING = auto()
    COMPLETED = auto()
    FAILED = auto()
    CANCELLED = auto()
    TIMEOUT = auto()


class TaskPriority(Enum):
    """Task priority levels"""
    LOW = 0
    NORMAL = 1
    HIGH = 2
    CRITICAL = 3


@dataclass
class Task:
    """Represents a single task"""
    id: str
    func: Callable
    args: Tuple = field(default_factory=tuple)
    kwargs: Dict = field(default_factory=dict)
    priority: TaskPriority = TaskPriority.NORMAL
    timeout: Optional[float] = None
    callback: Optional[Callable] = None
    error_callback: Optional[Callable] = None
    status: TaskStatus = TaskStatus.PENDING
    result: Any = None
    error: Optional[Exception] = None
    start_time: Optional[float] = None
    end_time: Optional[float] = None

    def __lt__(self, other):
        return self.priority.value > other.priority.value


@dataclass
class TaskResult:
    """Result of task execution"""
    task_id: str
    status: TaskStatus
    result: Any = None
    error: Optional[str] = None
    duration: float = 0.0


class TaskQueue:
    """Priority-based task queue with timeout support"""

    def __init__(self, max_size: int = 0):
        self._queue: queue.PriorityQueue = queue.PriorityQueue(maxsize=max_size)
        self._tasks: Dict[str, Task] = {}
        self._lock = threading.Lock()
        self._counter = 0

    def put(self, task: Task, block: bool = True, timeout: float = None):
        """Add task to queue"""
        with self._lock:
            self._counter += 1
            self._tasks[task.id] = task

        self._queue.put((task.priority.value * -1, self._counter, task),
                       block=block, timeout=timeout)

    def get(self, block: bool = True, timeout: float = None) -> Optional[Task]:
        """Get next task from queue"""
        try:
            _, _, task = self._queue.get(block=block, timeout=timeout)
            return task
        except queue.Empty:
            return None

    def get_task(self, task_id: str) -> Optional[Task]:
        """Get task by ID"""
        return self._tasks.get(task_id)

    def cancel(self, task_id: str) -> bool:
        """Cancel pending task"""
        with self._lock:
            if task_id in self._tasks:
                task = self._tasks[task_id]
                if task.status == TaskStatus.PENDING:
                    task.status = TaskStatus.CANCELLED
                    return True
        return False

    def clear(self):
        """Clear all pending tasks"""
        with self._lock:
            while not self._queue.empty():
                try:
                    self._queue.get_nowait()
                except:
                    break
            for task in self._tasks.values():
                if task.status == TaskStatus.PENDING:
                    task.status = TaskStatus.CANCELLED
            self._tasks.clear()

    @property
    def size(self) -> int:
        return self._queue.qsize()

    @property
    def empty(self) -> bool:
        return self._queue.empty()


class WorkerPool:
    """Pool of worker threads/processes"""

    def __init__(self, max_workers: int = None, use_processes: bool = False):
        self.max_workers = max_workers or (os.cpu_count() or 4)
        self.use_processes = use_processes
        self._executor: Optional[ThreadPoolExecutor] = None
        self._running = False
        self._lock = threading.Lock()
        self._active_tasks: Dict[str, Any] = {}
        self._completed_tasks: Dict[str, TaskResult] = {}
        self._stats = defaultdict(int)

    def start(self):
        """Start the worker pool"""
        with self._lock:
            if self._running:
                return

            if self.use_processes:
                self._executor = ProcessPoolExecutor(max_workers=self.max_workers)
            else:
                self._executor = ThreadPoolExecutor(max_workers=self.max_workers)

            self._running = True

    def stop(self, wait: bool = True, cancel_pending: bool = True):
        """Stop the worker pool"""
        with self._lock:
            if not self._running:
                return

            self._running = False

            if cancel_pending:
                for future in self._active_tasks.values():
                    future.cancel()

            if self._executor:
                self._executor.shutdown(wait=wait)
                self._executor = None

    def submit(self, task: Task) -> bool:
        """Submit task for execution"""
        if not self._running:
            return False

        try:
            future = self._executor.submit(self._execute_task, task)
            self._active_tasks[task.id] = future
            future.add_done_callback(lambda f: self._task_done(task.id, f))
            return True
        except Exception:
            return False

    def _execute_task(self, task: Task) -> TaskResult:
        """Execute a single task"""
        task.status = TaskStatus.RUNNING
        task.start_time = time.time()

        try:
            if task.timeout:
                result = self._execute_with_timeout(
                    task.func, task.args, task.kwargs, task.timeout
                )
            else:
                result = task.func(*task.args, **task.kwargs)

            task.result = result
            task.status = TaskStatus.COMPLETED
            self._stats['completed'] += 1

            return TaskResult(
                task_id=task.id,
                status=TaskStatus.COMPLETED,
                result=result,
                duration=time.time() - task.start_time
            )

        except TimeoutError:
            task.status = TaskStatus.TIMEOUT
            task.error = TimeoutError(f"Task timed out after {task.timeout}s")
            self._stats['timeout'] += 1

            return TaskResult(
                task_id=task.id,
                status=TaskStatus.TIMEOUT,
                error=str(task.error),
                duration=time.time() - task.start_time
            )

        except Exception as e:
            task.status = TaskStatus.FAILED
            task.error = e
            self._stats['failed'] += 1

            return TaskResult(
                task_id=task.id,
                status=TaskStatus.FAILED,
                error=str(e),
                duration=time.time() - task.start_time
            )

        finally:
            task.end_time = time.time()

    def _execute_with_timeout(self, func: Callable, args: Tuple,
                              kwargs: Dict, timeout: float) -> Any:
        """Execute function with timeout"""
        result = [None]
        error = [None]
        completed = threading.Event()

        def target():
            try:
                result[0] = func(*args, **kwargs)
            except Exception as e:
                error[0] = e
            finally:
                completed.set()

        thread = threading.Thread(target=target)
        thread.daemon = True
        thread.start()

        if not completed.wait(timeout):
            raise TimeoutError(f"Execution timed out after {timeout}s")

        if error[0]:
            raise error[0]

        return result[0]

    def _task_done(self, task_id: str, future):
        """Callback when task completes"""
        with self._lock:
            if task_id in self._active_tasks:
                del self._active_tasks[task_id]

            try:
                result = future.result()
                self._completed_tasks[task_id] = result
            except Exception as e:
                self._completed_tasks[task_id] = TaskResult(
                    task_id=task_id,
                    status=TaskStatus.FAILED,
                    error=str(e)
                )

    def get_result(self, task_id: str) -> Optional[TaskResult]:
        """Get result for completed task"""
        return self._completed_tasks.get(task_id)

    def wait(self, task_ids: List[str] = None, timeout: float = None) -> bool:
        """Wait for tasks to complete"""
        start = time.time()

        while True:
            with self._lock:
                if task_ids:
                    pending = [tid for tid in task_ids if tid in self._active_tasks]
                else:
                    pending = list(self._active_tasks.keys())

                if not pending:
                    return True

            if timeout and (time.time() - start) > timeout:
                return False

            time.sleep(0.1)

    def get_stats(self) -> Dict:
        """Get execution statistics"""
        return {
            'running': self._running,
            'active_tasks': len(self._active_tasks),
            'completed_tasks': len(self._completed_tasks),
            'stats': dict(self._stats),
        }


class ParallelExecutor:
    """High-level parallel execution manager"""

    def __init__(self, max_workers: int = None, queue_size: int = 10000):
        self.max_workers = max_workers or (os.cpu_count() or 4) * 2
        self._queue = TaskQueue(max_size=queue_size)
        self._pool = WorkerPool(max_workers=self.max_workers)
        self._running = False
        self._dispatcher_thread: Optional[threading.Thread] = None
        self._task_counter = 0
        self._lock = threading.Lock()
        self._callbacks: Dict[str, Callable] = {}

    def start(self):
        """Start the executor"""
        if self._running:
            return

        self._running = True
        self._pool.start()

        self._dispatcher_thread = threading.Thread(
            target=self._dispatch_loop, daemon=True
        )
        self._dispatcher_thread.start()

    def stop(self, wait: bool = True):
        """Stop the executor"""
        self._running = False

        if self._dispatcher_thread:
            self._dispatcher_thread.join(timeout=5)

        self._pool.stop(wait=wait)
        self._queue.clear()

    def submit(self, func: Callable, *args,
               priority: TaskPriority = TaskPriority.NORMAL,
               timeout: float = None,
               callback: Callable = None,
               **kwargs) -> str:
        """Submit function for parallel execution"""
        with self._lock:
            self._task_counter += 1
            task_id = f"task_{self._task_counter}"

        task = Task(
            id=task_id,
            func=func,
            args=args,
            kwargs=kwargs,
            priority=priority,
            timeout=timeout,
            callback=callback,
        )

        if callback:
            self._callbacks[task_id] = callback

        self._queue.put(task)
        return task_id

    def map(self, func: Callable, items: List[Any],
            priority: TaskPriority = TaskPriority.NORMAL,
            timeout: float = None) -> List[str]:
        """Map function over items in parallel"""
        task_ids = []
        for item in items:
            if isinstance(item, (tuple, list)):
                task_id = self.submit(func, *item, priority=priority, timeout=timeout)
            else:
                task_id = self.submit(func, item, priority=priority, timeout=timeout)
            task_ids.append(task_id)
        return task_ids

    def batch_execute(self, tasks: List[Tuple[Callable, Tuple, Dict]],
                      callback: Callable = None) -> List[TaskResult]:
        """Execute batch of tasks and wait for results"""
        task_ids = []

        for func, args, kwargs in tasks:
            task_id = self.submit(func, *args, **kwargs)
            task_ids.append(task_id)

        self._pool.wait(task_ids)

        results = []
        for task_id in task_ids:
            result = self._pool.get_result(task_id)
            if result:
                results.append(result)
                if callback:
                    callback(result)

        return results

    def _dispatch_loop(self):
        """Background dispatch loop"""
        while self._running:
            task = self._queue.get(block=True, timeout=0.1)

            if task and task.status == TaskStatus.PENDING:
                self._pool.submit(task)

    def get_result(self, task_id: str, wait: bool = True,
                   timeout: float = None) -> Optional[TaskResult]:
        """Get result for task"""
        if wait:
            self._pool.wait([task_id], timeout=timeout)
        return self._pool.get_result(task_id)

    def wait_all(self, timeout: float = None) -> bool:
        """Wait for all tasks to complete"""
        return self._pool.wait(timeout=timeout)

    def cancel(self, task_id: str) -> bool:
        """Cancel pending task"""
        return self._queue.cancel(task_id)

    def get_stats(self) -> Dict:
        """Get execution statistics"""
        return {
            'queue_size': self._queue.size,
            'total_submitted': self._task_counter,
            'pool_stats': self._pool.get_stats(),
        }


def parallel_map(func: Callable, items: List[Any],
                 max_workers: int = None,
                 timeout: float = None) -> List[Any]:
    """Simple parallel map function"""
    results = []
    max_workers = max_workers or min(32, os.cpu_count() or 4)

    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        futures = {executor.submit(func, item): i for i, item in enumerate(items)}

        for future in as_completed(futures, timeout=timeout):
            idx = futures[future]
            try:
                result = future.result()
                results.append((idx, result))
            except Exception as e:
                results.append((idx, e))

    results.sort(key=lambda x: x[0])
    return [r[1] for r in results]


def chunked_parallel(func: Callable, items: List[Any],
                     chunk_size: int = 100,
                     max_workers: int = None) -> Iterator[Any]:
    """Process items in parallel chunks"""
    max_workers = max_workers or min(32, os.cpu_count() or 4)

    for i in range(0, len(items), chunk_size):
        chunk = items[i:i + chunk_size]
        results = parallel_map(func, chunk, max_workers=max_workers)
        yield from results
