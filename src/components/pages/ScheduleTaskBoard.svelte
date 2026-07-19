<script lang="ts">
import Icon from "@components/common/Icon.svelte";
import type { Session, SupabaseClient } from "@supabase/supabase-js";
import { onMount } from "svelte";
import type { ScheduleTask } from "@/types/schedule";

export let supabase: SupabaseClient;
export let session: Session;

let tasks: ScheduleTask[] = [];
let newTitle = "";
let newDueDate = "";
let editingTask: ScheduleTask | null = null;
let isLoading = true;
let isAdding = false;
let busyTaskId = "";
let errorMessage = "";
let setupRequired = false;

onMount(() => {
	void loadTasks();
});

async function loadTasks(): Promise<void> {
	isLoading = true;
	errorMessage = "";
	setupRequired = false;

	try {
		const { data, error } = await supabase
			.from("schedule_tasks")
			.select("*")
			.eq("user_id", session.user.id)
			.order("is_completed")
			.order("position")
			.order("created_at");

		if (error) throw error;
		tasks = (data ?? []) as ScheduleTask[];
	} catch (error) {
		handleError("读取任务失败", error);
	} finally {
		isLoading = false;
	}
}

async function addTask(): Promise<void> {
	const title = newTitle.trim();
	if (!title || isAdding) return;
	isAdding = true;
	errorMessage = "";

	try {
		const { data, error } = await supabase
			.from("schedule_tasks")
			.insert({
				user_id: session.user.id,
				title,
				notes: "",
				due_date: newDueDate || null,
				is_completed: false,
				position: tasks.length,
			})
			.select("*")
			.single();

		if (error) throw error;
		tasks = [...tasks, data as ScheduleTask];
		newTitle = "";
		newDueDate = "";
	} catch (error) {
		handleError("添加任务失败", error);
	} finally {
		isAdding = false;
	}
}

async function toggleTask(task: ScheduleTask): Promise<void> {
	busyTaskId = task.id;
	errorMessage = "";

	try {
		const { data, error } = await supabase
			.from("schedule_tasks")
			.update({ is_completed: !task.is_completed })
			.eq("id", task.id)
			.eq("user_id", session.user.id)
			.select("*")
			.single();

		if (error) throw error;
		tasks = replaceTask(data as ScheduleTask).sort(compareTasks);
	} catch (error) {
		handleError("更新任务失败", error);
	} finally {
		busyTaskId = "";
	}
}

function beginEdit(task: ScheduleTask): void {
	editingTask = { ...task };
	errorMessage = "";
}

async function saveTask(): Promise<void> {
	if (!editingTask || !editingTask.title.trim()) return;
	busyTaskId = editingTask.id;
	errorMessage = "";

	try {
		const { data, error } = await supabase
			.from("schedule_tasks")
			.update({
				title: editingTask.title.trim(),
				notes: editingTask.notes.trim(),
				due_date: editingTask.due_date || null,
			})
			.eq("id", editingTask.id)
			.eq("user_id", session.user.id)
			.select("*")
			.single();

		if (error) throw error;
		tasks = replaceTask(data as ScheduleTask);
		editingTask = null;
	} catch (error) {
		handleError("保存任务失败", error);
	} finally {
		busyTaskId = "";
	}
}

async function deleteTask(task: ScheduleTask): Promise<void> {
	if (!window.confirm(`确定删除任务“${task.title}”吗？`)) return;
	busyTaskId = task.id;
	errorMessage = "";

	try {
		const { data, error } = await supabase
			.from("schedule_tasks")
			.delete()
			.eq("id", task.id)
			.eq("user_id", session.user.id)
			.select("id")
			.maybeSingle();

		if (error) throw error;
		if (!data) throw new Error("数据库没有删除任何记录，请检查 RLS 策略。");
		tasks = tasks.filter((item) => item.id !== task.id);
		if (editingTask?.id === task.id) editingTask = null;
	} catch (error) {
		handleError("删除任务失败", error);
	} finally {
		busyTaskId = "";
	}
}

function replaceTask(nextTask: ScheduleTask): ScheduleTask[] {
	return tasks.map((task) => (task.id === nextTask.id ? nextTask : task));
}

function compareTasks(a: ScheduleTask, b: ScheduleTask): number {
	if (a.is_completed !== b.is_completed)
		return Number(a.is_completed) - Number(b.is_completed);
	return a.position - b.position;
}

function handleError(prefix: string, error: unknown): void {
	const detail = errorDetail(error);
	const missingTable = /schedule_tasks|schema cache|PGRST205|42P01/i.test(
		detail,
	);
	const permissionError =
		/42501|row-level security|permission denied|policy|PGRST116/i.test(detail);
	setupRequired = missingTable || permissionError;
	if (missingTable) {
		errorMessage =
			"任务数据表尚未创建，请在 Supabase SQL Editor 执行 supabase/schedule_tasks.sql。";
	} else if (permissionError) {
		errorMessage =
			"任务表的 RLS 权限未配置完整，请在 Supabase SQL Editor 重新执行 supabase/schedule_tasks.sql。";
	} else {
		errorMessage = `${prefix}：${detail}`;
	}
}

function errorDetail(error: unknown): string {
	if (error instanceof Error) return error.message;
	if (!error || typeof error !== "object") return String(error);

	const record = error as Record<string, unknown>;
	return (
		[record.code, record.message, record.details, record.hint]
			.filter(
				(value): value is string =>
					typeof value === "string" && value.length > 0,
			)
			.join(" · ") || "未知数据库错误"
	);
}

function formatDueDate(value: string | null): string {
	if (!value) return "";
	return new Intl.DateTimeFormat("zh-CN", {
		month: "short",
		day: "numeric",
	}).format(new Date(`${value}T00:00:00`));
}
</script>

<section class="task-panel" aria-labelledby="schedule-task-title">
	<header class="task-header">
		<div>
			<div class="task-eyebrow"><Icon icon="material-symbols:checklist-rounded" /> FLEXIBLE TASKS</div>
			<h2 id="schedule-task-title">待办任务</h2>
			<p>记录不固定在某个时间段内、但仍需要完成的事情。</p>
		</div>
		<span class="task-count">{tasks.filter((task) => !task.is_completed).length} 项待完成</span>
	</header>

	<form class="quick-add" on:submit|preventDefault={addTask}>
		<label class="task-title-input">
			<span class="sr-only">任务名称</span>
			<input bind:value={newTitle} maxlength="160" placeholder="添加一项非时段任务…" required />
		</label>
		<label class="due-input">
			<span>截止日期（可选）</span>
			<input type="date" bind:value={newDueDate} />
		</label>
		<button class="add-task-button" type="submit" disabled={isAdding || setupRequired}>
			<Icon icon="material-symbols:add-rounded" />{isAdding ? "添加中…" : "添加任务"}
		</button>
	</form>

	{#if errorMessage}
		<div class:setup-warning={setupRequired} class="task-message" role="alert">
			<Icon icon={setupRequired ? "material-symbols:database-outline" : "material-symbols:error-outline"} />
			<span>{errorMessage}</span>
			<button type="button" on:click={loadTasks}>{setupRequired ? "重新检测" : "重试"}</button>
		</div>
	{/if}

	{#if isLoading}
		<div class="task-empty"><Icon icon="svg-spinners:ring-resize" />正在读取云端任务…</div>
	{:else if !setupRequired && tasks.length === 0}
		<div class="task-empty"><Icon icon="material-symbols:task-alt-rounded" />还没有任务，先记录一件想完成的事。</div>
	{:else if !setupRequired}
		<div class="task-list">
			{#each tasks as task (task.id)}
				<article class:completed={task.is_completed} class="task-item">
					<button class="check-button" type="button" aria-label={task.is_completed ? "标记为未完成" : "标记为已完成"} disabled={busyTaskId === task.id} on:click={() => toggleTask(task)}>
						<Icon icon={task.is_completed ? "material-symbols:check-circle-rounded" : "material-symbols:radio-button-unchecked"} />
					</button>
					{#if editingTask?.id === task.id}
						<form class="task-editor" on:submit|preventDefault={saveTask}>
							<input bind:value={editingTask.title} maxlength="160" required aria-label="任务名称" />
							<textarea bind:value={editingTask.notes} maxlength="2000" rows="2" placeholder="补充备注（可选）" aria-label="任务备注"></textarea>
							<label><span>截止日期</span><input type="date" bind:value={editingTask.due_date} /></label>
							<div class="editor-actions">
								<button type="button" on:click={() => editingTask = null}>取消</button>
								<button class="save-task" type="submit" disabled={busyTaskId === task.id}>保存</button>
							</div>
						</form>
					{:else}
						<div class="task-content">
							<h3>{task.title}</h3>
							{#if task.notes}<p>{task.notes}</p>{/if}
							{#if task.due_date}<span class="due-date"><Icon icon="material-symbols:event-outline-rounded" />{formatDueDate(task.due_date)}</span>{/if}
						</div>
						<div class="row-actions">
							<button type="button" aria-label={`编辑 ${task.title}`} on:click={() => beginEdit(task)}><Icon icon="material-symbols:edit-outline-rounded" /></button>
							<button class="delete-task" type="button" aria-label={`删除 ${task.title}`} disabled={busyTaskId === task.id} on:click={() => deleteTask(task)}><Icon icon="material-symbols:delete-outline-rounded" /></button>
						</div>
					{/if}
				</article>
			{/each}
		</div>
	{/if}
</section>

<style>
	.task-panel { margin-top: 1rem; padding: clamp(1.15rem, 3vw, 2rem); border: 1px solid var(--line-divider); border-radius: var(--radius-large); background: var(--card-bg); color: var(--schedule-ink); box-shadow: 0 18px 60px color-mix(in oklch, var(--schedule-ink) 7%, transparent); }
	.task-header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; }
	.task-header h2 { margin: 0.35rem 0 0; font-size: clamp(1.35rem, 3vw, 1.9rem); }
	.task-header p { margin: 0.3rem 0 0; color: var(--schedule-muted); font-size: 0.86rem; }
	.task-eyebrow { display: flex; align-items: center; gap: 0.45rem; color: var(--primary); font-size: 0.7rem; font-weight: 800; letter-spacing: 0.13em; }
	.task-count { flex: 0 0 auto; padding: 0.4rem 0.7rem; border-radius: 999px; background: var(--schedule-soft); color: var(--schedule-muted); font-size: 0.75rem; font-weight: 700; }
	.quick-add { display: grid; grid-template-columns: minmax(0, 1fr) minmax(170px, 0.32fr) auto; gap: 0.75rem; align-items: end; margin-top: 1.25rem; }
	.quick-add label { display: grid; gap: 0.35rem; color: var(--schedule-muted); font-size: 0.72rem; font-weight: 700; }
	.quick-add input, .task-editor input, .task-editor textarea { width: 100%; min-height: 2.75rem; padding: 0.65rem 0.75rem; border: 1px solid var(--schedule-line); border-radius: 0.72rem; background: color-mix(in oklch, var(--page-bg) 38%, var(--card-bg)); color: var(--schedule-ink); outline: none; }
	.quick-add input:focus, .task-editor input:focus, .task-editor textarea:focus { border-color: var(--primary); box-shadow: 0 0 0 3px color-mix(in oklch, var(--primary) 18%, transparent); }
	:global(:root.dark) .quick-add input[type="date"], :global(:root.dark) .task-editor input[type="date"] { color-scheme: dark; }
	:global(:root.dark) .quick-add input[type="date"]::-webkit-calendar-picker-indicator, :global(:root.dark) .task-editor input[type="date"]::-webkit-calendar-picker-indicator { opacity: 0.78; filter: brightness(0) invert(1); }
	.add-task-button { min-height: 2.75rem; display: inline-flex; align-items: center; justify-content: center; gap: 0.35rem; padding: 0.65rem 0.9rem; border: 0; border-radius: 0.72rem; background: var(--primary); color: oklch(0.22 0.03 var(--hue)); font: inherit; font-size: 0.82rem; font-weight: 800; cursor: pointer; }
	.add-task-button:disabled { opacity: 0.5; cursor: not-allowed; }
	.task-message, .task-empty { display: flex; align-items: center; gap: 0.55rem; margin-top: 1rem; padding: 0.85rem; border-radius: 0.75rem; color: #d05b57; background: color-mix(in oklch, #c2413e 10%, transparent); font-size: 0.82rem; }
	.task-message.setup-warning { color: var(--schedule-ink); background: color-mix(in oklch, #d28a2e 15%, var(--card-bg)); }
	.task-message button { margin-left: auto; border: 0; background: transparent; color: inherit; font-weight: 800; cursor: pointer; }
	.task-empty { justify-content: center; min-height: 110px; color: var(--schedule-muted); background: var(--schedule-soft); }
	.task-list { display: grid; gap: 0.55rem; margin-top: 1rem; }
	.task-item { display: grid; grid-template-columns: auto minmax(0, 1fr) auto; gap: 0.7rem; align-items: start; padding: 0.85rem; border: 1px solid var(--schedule-line); border-radius: 0.8rem; background: color-mix(in oklch, var(--page-bg) 22%, var(--card-bg)); }
	.check-button, .row-actions button { display: inline-grid; place-items: center; border: 0; background: transparent; color: var(--schedule-muted); font: inherit; font-size: 1.2rem; cursor: pointer; }
	.check-button { color: var(--primary); padding: 0.1rem; }
	.task-content h3 { margin: 0; font-size: 0.95rem; }
	.task-content p { margin: 0.25rem 0 0; color: var(--schedule-muted); font-size: 0.82rem; line-height: 1.55; white-space: pre-wrap; }
	.completed .task-content h3 { color: var(--schedule-muted); text-decoration: line-through; }
	.due-date { display: inline-flex; align-items: center; gap: 0.25rem; margin-top: 0.4rem; color: var(--schedule-muted); font-size: 0.72rem; }
	.row-actions { display: flex; gap: 0.35rem; }
	.row-actions button { width: 2rem; height: 2rem; border-radius: 0.55rem; font-size: 1rem; }
	.row-actions button:hover { background: var(--schedule-soft); color: var(--schedule-ink); }
	.row-actions .delete-task:hover { color: #d05b57; }
	.task-editor { display: grid; gap: 0.55rem; }
	.task-editor textarea { resize: vertical; }
	.task-editor label { display: grid; gap: 0.3rem; color: var(--schedule-muted); font-size: 0.7rem; font-weight: 700; }
	.editor-actions { display: flex; justify-content: flex-end; gap: 0.45rem; }
	.editor-actions button { padding: 0.45rem 0.65rem; border: 0; border-radius: 0.55rem; background: var(--schedule-soft); color: var(--schedule-ink); font: inherit; font-size: 0.75rem; font-weight: 700; cursor: pointer; }
	.editor-actions .save-task { background: var(--primary); color: oklch(0.22 0.03 var(--hue)); }
	.sr-only { position: absolute; width: 1px; height: 1px; padding: 0; margin: -1px; overflow: hidden; clip: rect(0, 0, 0, 0); white-space: nowrap; border: 0; }
	@media (max-width: 760px) {
		.task-header { flex-direction: column; }
		.quick-add { grid-template-columns: 1fr; }
		.add-task-button { width: 100%; }
		.task-item { grid-template-columns: auto minmax(0, 1fr); }
		.row-actions { grid-column: 2; justify-content: flex-end; }
	}
</style>
