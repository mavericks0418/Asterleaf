<script lang="ts">
import Icon from "@components/common/Icon.svelte";
import ScheduleTaskBoard from "@components/pages/ScheduleTaskBoard.svelte";
import ScheduleXCalendarView from "@components/pages/ScheduleXCalendarView.svelte";
import type { Session, SupabaseClient } from "@supabase/supabase-js";
import { getSupabaseClient } from "@utils/supabase";
import { onMount } from "svelte";
import type {
	ScheduleColor,
	ScheduleEvent,
	ScheduleEventDraft,
} from "@/types/schedule";

type AuthMode = "sign-in" | "sign-up";

const COLORS: ScheduleColor[] = ["teal", "violet", "amber", "rose"];

let supabase: SupabaseClient | null = null;
let session: Session | null = null;
let initialized = false;
let isLoading = false;
let isSaving = false;
let isDeleting = false;
let authMode: AuthMode = "sign-in";
let email = "";
let password = "";
let authMessage = "";
let errorMessage = "";
let noticeMessage = "";
let events: ScheduleEvent[] = [];
let draft: ScheduleEventDraft = createDraft(localDateKey());
let editorOpen = false;

onMount(() => {
	supabase = getSupabaseClient();
	initialized = true;

	if (!supabase) return;

	const {
		data: { subscription },
	} = supabase.auth.onAuthStateChange((_event, nextSession) => {
		session = nextSession;
		if (!nextSession) {
			events = [];
			return;
		}
		void loadEvents(nextSession);
	});

	void initializeSession();
	return () => subscription.unsubscribe();
});

async function initializeSession(): Promise<void> {
	if (!supabase) return;
	const { data, error } = await supabase.auth.getSession();
	if (error) {
		errorMessage = readableError("读取登录状态失败", error.message);
		return;
	}
	session = data.session;
	if (session) await loadEvents(session);
}

function localDateKey(): string {
	const now = new Date();
	const year = now.getFullYear();
	const month = String(now.getMonth() + 1).padStart(2, "0");
	const day = String(now.getDate()).padStart(2, "0");
	return `${year}-${month}-${day}`;
}

function normalizeTime(value: string): string {
	return value.slice(0, 5);
}

function createDraft(date: string, start = "09:00"): ScheduleEventDraft {
	const [hour = 9, minute = 0] = start.split(":").map(Number);
	const endMinutes = Math.min(hour * 60 + minute + 60, 23 * 60 + 59);
	return {
		title: "",
		description: "",
		event_date: date,
		start_time: start,
		end_time: `${String(Math.floor(endMinutes / 60)).padStart(2, "0")}:${String(endMinutes % 60).padStart(2, "0")}`,
		color: "teal",
	};
}

function openNewEditor(date = localDateKey(), start = "09:00"): void {
	errorMessage = "";
	noticeMessage = "";
	draft = createDraft(date, start);
	editorOpen = true;
}

function openEditor(event: ScheduleEvent): void {
	errorMessage = "";
	noticeMessage = "";
	draft = {
		id: event.id,
		title: event.title,
		description: event.description ?? "",
		event_date: event.event_date,
		start_time: normalizeTime(event.start_time),
		end_time: normalizeTime(event.end_time),
		color: event.color,
	};
	editorOpen = true;
}

function closeEditor(): void {
	editorOpen = false;
	errorMessage = "";
}

function shiftDraft(minutes: number): void {
	const duration =
		timeToMinutes(draft.end_time) - timeToMinutes(draft.start_time);
	const nextStart = Math.max(
		0,
		Math.min(1439 - duration, timeToMinutes(draft.start_time) + minutes),
	);
	draft.start_time = minutesToTime(nextStart);
	draft.end_time = minutesToTime(nextStart + duration);
}

function resizeDraft(minutes: number): void {
	const start = timeToMinutes(draft.start_time);
	const nextEnd = Math.max(
		start + 15,
		Math.min(1439, timeToMinutes(draft.end_time) + minutes),
	);
	draft.end_time = minutesToTime(nextEnd);
}

function timeToMinutes(value: string): number {
	const [hour = 0, minute = 0] = value.split(":").map(Number);
	return hour * 60 + minute;
}

function minutesToTime(value: number): string {
	return `${String(Math.floor(value / 60)).padStart(2, "0")}:${String(value % 60).padStart(2, "0")}`;
}

async function loadEvents(activeSession = session): Promise<void> {
	if (!supabase || !activeSession) return;
	isLoading = true;
	errorMessage = "";

	try {
		const { data, error } = await supabase
			.from("schedule_events")
			.select("*")
			.eq("user_id", activeSession.user.id)
			.order("event_date")
			.order("start_time");

		if (error) throw error;
		events = (data ?? []) as ScheduleEvent[];
	} catch (error) {
		errorMessage = readableError(
			"读取日程失败，请检查 schedule_events 表和 RLS 策略",
			error,
		);
	} finally {
		isLoading = false;
	}
}

function getAuthRedirectUrl(): string {
	const baseUrl = import.meta.env.BASE_URL.endsWith("/")
		? import.meta.env.BASE_URL
		: `${import.meta.env.BASE_URL}/`;
	return new URL(`${baseUrl}schedule/`, window.location.origin).toString();
}

async function submitAuth(): Promise<void> {
	if (!supabase) return;
	authMessage = "";
	errorMessage = "";
	isLoading = true;

	try {
		const result =
			authMode === "sign-in"
				? await supabase.auth.signInWithPassword({ email, password })
				: await supabase.auth.signUp({
						email,
						password,
						options: { emailRedirectTo: getAuthRedirectUrl() },
					});

		if (result.error) throw result.error;
		if (authMode === "sign-up" && !result.data.session) {
			authMessage = "注册成功，请先完成邮箱确认。";
		} else {
			authMessage = "登录成功。";
		}
	} catch (error) {
		errorMessage = readableError("认证失败", error);
	} finally {
		isLoading = false;
	}
}

async function resendConfirmation(): Promise<void> {
	if (!supabase || !email) return;
	authMessage = "";
	errorMessage = "";
	isLoading = true;

	try {
		const { error } = await supabase.auth.resend({
			type: "signup",
			email,
			options: { emailRedirectTo: getAuthRedirectUrl() },
		});
		if (error) throw error;
		authMessage = "确认邮件已重新发送，请检查收件箱与垃圾邮件。";
	} catch (error) {
		errorMessage = readableError("邮件发送失败", error);
	} finally {
		isLoading = false;
	}
}

async function signOut(): Promise<void> {
	if (!supabase) return;
	const { error } = await supabase.auth.signOut();
	if (error) errorMessage = readableError("退出失败", error);
}

async function saveEvent(): Promise<void> {
	if (!supabase || !session) return;
	errorMessage = "";
	noticeMessage = "";

	if (!draft.title.trim()) {
		errorMessage = "请填写日程标题。";
		return;
	}
	if (draft.end_time <= draft.start_time) {
		errorMessage = "结束时间必须晚于开始时间。";
		return;
	}

	isSaving = true;
	const wasEditing = Boolean(draft.id);
	const payload = {
		title: draft.title.trim(),
		description: draft.description.trim(),
		event_date: draft.event_date,
		start_time: draft.start_time,
		end_time: draft.end_time,
		color: draft.color,
	};

	try {
		const query = draft.id
			? supabase
					.from("schedule_events")
					.update(payload)
					.eq("id", draft.id)
					.eq("user_id", session.user.id)
			: supabase
					.from("schedule_events")
					.insert({ ...payload, user_id: session.user.id });

		const { data, error } = await query.select("*").maybeSingle();
		if (error) throw error;
		if (!data) {
			throw new Error(
				"数据库没有返回被写入的记录。请重新执行 RLS 策略，并确认当前账号拥有这条日程。",
			);
		}

		const savedEvent = data as ScheduleEvent;
		events = wasEditing
			? events.map((event) => (event.id === savedEvent.id ? savedEvent : event))
			: [...events, savedEvent].sort(compareEvents);
		editorOpen = false;
		noticeMessage = wasEditing
			? "日程已修改并同步到云端。"
			: "日程已添加并同步到云端。";
	} catch (error) {
		errorMessage = readableError(wasEditing ? "修改失败" : "添加失败", error);
	} finally {
		isSaving = false;
	}
}

async function deleteEvent(): Promise<void> {
	if (!supabase || !session || !draft.id) return;
	if (!window.confirm("确定删除这个日程吗？此操作会同步删除云端记录。")) return;

	isDeleting = true;
	errorMessage = "";
	noticeMessage = "";
	const eventId = draft.id;

	try {
		const { data, error } = await supabase
			.from("schedule_events")
			.delete()
			.eq("id", eventId)
			.eq("user_id", session.user.id)
			.select("id")
			.maybeSingle();

		if (error) throw error;
		if (!data) {
			throw new Error(
				"数据库没有删除任何记录。这通常表示 RLS 策略未生效，或这条日程不属于当前账号。",
			);
		}

		events = events.filter((event) => event.id !== eventId);
		editorOpen = false;
		noticeMessage = "日程已从网页和云端删除。";
	} catch (error) {
		errorMessage = readableError("删除失败", error);
	} finally {
		isDeleting = false;
	}
}

function compareEvents(a: ScheduleEvent, b: ScheduleEvent): number {
	return `${a.event_date} ${a.start_time}`.localeCompare(
		`${b.event_date} ${b.start_time}`,
	);
}

function readableError(prefix: string, error: unknown): string {
	const detail =
		typeof error === "string"
			? error
			: error instanceof Error
				? error.message
				: "未知错误";
	return `${prefix}：${detail}`;
}
</script>

<svelte:window on:keydown={(event) => { if (event.key === "Escape" && editorOpen) closeEditor(); }} />

<div class="schedule-board">
	{#if !initialized}
		<section class="schedule-card schedule-state" aria-live="polite">
			<div class="state-orb"><Icon icon="svg-spinners:ring-resize" size="lg" /></div>
			<p>正在准备你的私有日程</p>
		</section>
	{:else if !supabase}
		<section class="schedule-card schedule-state">
			<div class="state-orb"><Icon icon="material-symbols:lock-outline" size="lg" /></div>
			<div>
				<h2>还差一步配置</h2>
				<p>请先配置 <code>PUBLIC_SUPABASE_URL</code> 和 <code>PUBLIC_SUPABASE_ANON_KEY</code>。</p>
				<p class="state-help">配置方法请参考 <code>docs/private-schedule.md</code>。</p>
			</div>
		</section>
	{:else if !session}
		<section class="schedule-card auth-card">
			<div class="auth-intro">
				<div class="eyebrow"><Icon icon="material-symbols:lock-outline" /> PRIVATE SPACE</div>
				<h2>只有你的账号可以看到</h2>
				<p>日程不会出现在公开博客中，登录后才会从 Supabase 加载。</p>
			</div>
			<form class="auth-form" on:submit|preventDefault={submitAuth}>
				<label><span>邮箱</span><input type="email" autocomplete="email" bind:value={email} required placeholder="you@example.com" /></label>
				<label><span>密码</span><input type="password" autocomplete={authMode === "sign-in" ? "current-password" : "new-password"} bind:value={password} minlength="6" required placeholder="至少 6 位" /></label>
				{#if errorMessage}<p class="form-error">{errorMessage}</p>{/if}
				{#if authMessage}<p class="form-success">{authMessage}</p>{/if}
				{#if authMode === "sign-up" && authMessage}
					<button class="text-button" type="button" on:click={resendConfirmation} disabled={isLoading}>重新发送确认邮件</button>
				{/if}
				<button class="primary-button" type="submit" disabled={isLoading}>{isLoading ? "处理中…" : authMode === "sign-in" ? "登录日程" : "创建账号"}</button>
				<button class="text-button" type="button" on:click={() => { authMode = authMode === "sign-in" ? "sign-up" : "sign-in"; errorMessage = ""; authMessage = ""; }}>
					{authMode === "sign-in" ? "第一次使用？创建一个账号" : "已有账号？登录日程"}
				</button>
			</form>
		</section>
	{:else}
		<section class="schedule-card board-card">
			<header class="board-header">
				<div>
					<div class="eyebrow"><Icon icon="material-symbols:calendar-month-outline-rounded" /> SCHEDULE-X PLANNER</div>
					<h1>我的日程</h1>
					<p class="board-subtitle">点击日程进行修改；双击空白时间可快速新建。红线代表当前时间。</p>
				</div>
				<div class="account-actions">
					<span class:loading={isLoading} class="sync-status"><span></span>{isLoading ? "同步中" : `${events.length} 项已同步`}</span>
					<span class="account-email" title={session.user.email}>{session.user.email}</span>
					<button class="plain-button" type="button" on:click={() => loadEvents()} disabled={isLoading} aria-label="重新读取云端日程"><Icon icon="material-symbols:refresh-rounded" />刷新</button>
					<button class="plain-button" type="button" on:click={signOut}><Icon icon="material-symbols:logout" />退出</button>
					<button class="primary-button compact" type="button" on:click={() => openNewEditor()}><Icon icon="material-symbols:add" />添加日程</button>
				</div>
			</header>

			{#if errorMessage}<div class="inline-message form-error"><Icon icon="material-symbols:error-outline" />{errorMessage}</div>{/if}
			{#if noticeMessage}<div class="inline-message form-success"><Icon icon="material-symbols:cloud-done-outline" />{noticeMessage}</div>{/if}

			<ScheduleXCalendarView {events} onEdit={openEditor} onCreate={openNewEditor} />
		</section>
		<ScheduleTaskBoard {supabase} {session} />
	{/if}
</div>

{#if editorOpen}
	<div class="schedule-board modal-scope"><div class="modal-backdrop" role="presentation" on:click={(event) => { if (event.target === event.currentTarget) closeEditor(); }}>
		<div class="editor-modal" role="dialog" aria-modal="true" aria-labelledby="schedule-editor-title">
			<div class="modal-heading">
				<div><div class="eyebrow">{draft.id ? "EDIT EVENT" : "NEW EVENT"}</div><h2 id="schedule-editor-title">{draft.id ? "修改日程" : "添加日程"}</h2></div>
				<button class="icon-button" type="button" aria-label="关闭" on:click={closeEditor}><Icon icon="material-symbols:close-rounded" /></button>
			</div>
			<form class="editor-form" on:submit|preventDefault={saveEvent}>
				<label class="full-field"><span>事项</span><input bind:value={draft.title} maxlength="120" required placeholder="例如：阅读、会议、运动" /></label>
				<div class="form-grid">
					<label><span>日期</span><input type="date" bind:value={draft.event_date} required /></label>
					<label><span>颜色</span><div class="color-options">{#each COLORS as color}<button class:chosen={draft.color === color} class={`color-dot color-${color}`} type="button" aria-label={color} on:click={() => draft.color = color}></button>{/each}</div></label>
					<label><span>开始</span><input type="time" bind:value={draft.start_time} required /></label>
					<label><span>结束</span><input type="time" bind:value={draft.end_time} required /></label>
				</div>
				<div class="time-adjustment" aria-label="快速调整时间">
					<span>快速调整</span>
					<div><button type="button" on:click={() => shiftDraft(-30)}>提前 30 分</button><button type="button" on:click={() => shiftDraft(30)}>延后 30 分</button><button type="button" on:click={() => resizeDraft(-30)}>缩短 30 分</button><button type="button" on:click={() => resizeDraft(30)}>延长 30 分</button></div>
					<small>Schedule-X 免费版不含拖拽与拉伸插件，可在这里或时间输入框中调整。</small>
				</div>
				<label class="full-field"><span>备注 <em>可选</em></span><textarea bind:value={draft.description} maxlength="2000" rows="3" placeholder="补充地点、链接或提醒"></textarea></label>
				{#if errorMessage}<p class="form-error">{errorMessage}</p>{/if}
				<div class="modal-actions">
					{#if draft.id}<button class="danger-button" type="button" on:click={deleteEvent} disabled={isDeleting || isSaving}>{isDeleting ? "删除中…" : "删除"}</button>{/if}
					<div class="modal-main-actions"><button class="plain-button" type="button" on:click={closeEditor}>取消</button><button class="primary-button compact" type="submit" disabled={isSaving || isDeleting}>{isSaving ? "保存中…" : "保存日程"}</button></div>
				</div>
			</form>
		</div>
	</div></div>
{/if}

<style>
	.schedule-board {
		--schedule-ink: oklch(0.28 0.02 var(--hue));
		--schedule-muted: oklch(0.53 0.02 var(--hue));
		--schedule-line: rgb(0 0 0 / 0.11);
		--schedule-soft: color-mix(in oklch, var(--primary) 9%, var(--card-bg));
		color: var(--schedule-ink);
	}
	:global(:root.dark) .schedule-board {
		--schedule-ink: oklch(0.92 0.018 var(--hue));
		--schedule-muted: oklch(0.76 0.025 var(--hue));
		--schedule-line: rgb(255 255 255 / 0.13);
		--schedule-soft: color-mix(in oklch, var(--primary) 13%, var(--card-bg));
	}
	.schedule-card { background: var(--card-bg); border: 1px solid var(--line-divider); border-radius: var(--radius-large); box-shadow: 0 18px 60px color-mix(in oklch, var(--schedule-ink) 8%, transparent); backdrop-filter: blur(14px); }
	.schedule-state { min-height: 260px; display: flex; align-items: center; justify-content: center; gap: 1rem; padding: 2rem; text-align: left; }
	.schedule-state h2, .auth-card h2, .editor-modal h2 { margin: 0; font-size: 1.5rem; font-weight: 800; }
	.schedule-state p, .auth-intro p { margin: 0.45rem 0 0; color: var(--schedule-muted); line-height: 1.7; }
	.state-orb { width: 3rem; height: 3rem; display: grid; place-items: center; border-radius: 1rem; background: var(--schedule-soft); color: var(--primary); font-size: 1.4rem; flex: 0 0 auto; }
	.state-help { font-size: 0.85rem; }
	code { padding: 0.1rem 0.35rem; border-radius: 0.35rem; background: var(--btn-regular-bg); color: var(--btn-content); font-size: 0.85em; }
	.auth-card { display: grid; grid-template-columns: minmax(0, 1fr) minmax(280px, 380px); gap: 3rem; padding: clamp(1.5rem, 5vw, 4.5rem); align-items: center; }
	.auth-intro { max-width: 34rem; }
	.auth-intro h2 { margin-top: 0.7rem; font-size: clamp(2rem, 5vw, 3.5rem); letter-spacing: -0.04em; }
	.eyebrow { display: flex; align-items: center; gap: 0.45rem; color: var(--primary); font-size: 0.72rem; font-weight: 800; letter-spacing: 0.13em; }
	.auth-form, .editor-form { display: grid; gap: 1rem; }
	.auth-form label, .editor-form label { display: grid; gap: 0.45rem; color: var(--schedule-muted); font-size: 0.82rem; font-weight: 700; }
	.auth-form input, .editor-form input, .editor-form textarea { width: 100%; border: 1px solid var(--line-divider); border-radius: 0.75rem; background: color-mix(in oklch, var(--page-bg) 38%, var(--card-bg)); color: var(--schedule-ink); padding: 0.72rem 0.8rem; outline: none; transition: border-color 150ms ease, box-shadow 150ms ease; }
	.auth-form input:focus, .editor-form input:focus, .editor-form textarea:focus { border-color: var(--primary); box-shadow: 0 0 0 3px color-mix(in oklch, var(--primary) 18%, transparent); }
	.primary-button, .plain-button, .icon-button, .text-button, .danger-button { border: 0; cursor: pointer; font: inherit; transition: transform 150ms ease, background 150ms ease, opacity 150ms ease; }
	.primary-button:active, .plain-button:active, .icon-button:active, .danger-button:active { transform: translateY(1px) scale(0.98); }
	.primary-button { display: inline-flex; align-items: center; justify-content: center; gap: 0.5rem; min-height: 2.75rem; padding: 0.7rem 1rem; border-radius: 0.75rem; background: var(--primary); color: oklch(0.22 0.03 var(--hue)); font-weight: 800; }
	.primary-button:hover { filter: saturate(1.08) brightness(0.98); }
	.primary-button:disabled, .plain-button:disabled { opacity: 0.55; cursor: wait; }
	.primary-button.compact { min-height: 2.4rem; padding: 0.55rem 0.85rem; font-size: 0.86rem; }
	.text-button { background: transparent; color: var(--primary); font-size: 0.82rem; font-weight: 700; }
	.text-button:hover { text-decoration: underline; }
	.form-error, .form-success { margin: 0; font-size: 0.82rem; line-height: 1.5; }
	.form-error { color: #d05b57; }
	.form-success { color: var(--primary); }
	.board-card { overflow: hidden; }
	.board-header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; padding: clamp(1.25rem, 3vw, 2rem) clamp(1.25rem, 3vw, 2.5rem) 1.2rem; }
	.board-header h1 { margin: 0.35rem 0 0; font-size: clamp(1.7rem, 4vw, 2.55rem); letter-spacing: -0.045em; }
	.board-subtitle { margin: 0.3rem 0 0; color: var(--schedule-muted); font-size: 0.88rem; }
	.account-actions { display: flex; align-items: center; justify-content: flex-end; flex-wrap: wrap; gap: 0.65rem; }
	.account-email { max-width: 13rem; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; color: var(--schedule-muted); font-size: 0.76rem; }
	.sync-status { display: inline-flex; align-items: center; gap: 0.4rem; color: var(--schedule-muted); font-size: 0.72rem; }
	.sync-status span { width: 0.48rem; height: 0.48rem; border-radius: 50%; background: var(--primary); box-shadow: 0 0 0 3px color-mix(in oklch, var(--primary) 14%, transparent); }
	.sync-status.loading span { animation: status-pulse 1s ease-in-out infinite; }
	.plain-button { display: inline-flex; align-items: center; justify-content: center; gap: 0.35rem; padding: 0.55rem 0.65rem; border-radius: 0.65rem; background: transparent; color: var(--schedule-muted); font-size: 0.78rem; font-weight: 700; }
	.plain-button:hover { background: var(--btn-regular-bg); color: var(--schedule-ink); }
	.inline-message { display: flex; align-items: center; gap: 0.45rem; margin: 0 1rem 0.8rem; padding: 0.7rem 0.8rem; border-radius: 0.65rem; background: var(--schedule-soft); }
	.inline-message.form-error { background: color-mix(in oklch, #c2413e 10%, transparent); }
	.modal-scope { position: relative; z-index: 100; }
	.modal-backdrop { position: fixed; z-index: 100; inset: 0; display: grid; place-items: center; padding: 1rem; background: color-mix(in oklch, #0b1020 48%, transparent); backdrop-filter: blur(5px); }
	.editor-modal { width: min(100%, 540px); max-height: min(90dvh, 700px); overflow: auto; padding: 1.35rem; border: 1px solid var(--line-divider); border-radius: var(--radius-large); background: var(--card-bg); color: var(--schedule-ink); box-shadow: 0 24px 80px color-mix(in oklch, #000 28%, transparent); }
	.modal-heading { display: flex; align-items: flex-start; justify-content: space-between; margin-bottom: 1.25rem; }
	.modal-heading h2 { margin-top: 0.3rem; }
	.icon-button { width: 2.25rem; height: 2.25rem; display: inline-grid; place-items: center; border-radius: 0.65rem; background: transparent; color: var(--schedule-muted); font-size: 1.25rem; }
	.icon-button:hover { background: var(--btn-regular-bg); color: var(--schedule-ink); }
	.form-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 1rem; }
	.full-field { grid-column: 1 / -1; }
	.editor-form em { color: var(--schedule-muted); font-size: 0.75rem; font-style: normal; font-weight: 400; }
	.editor-form textarea { resize: vertical; }
	.color-options { display: flex; align-items: center; gap: 0.65rem; min-height: 2.75rem; }
	.color-dot { width: 1.35rem; height: 1.35rem; border: 3px solid transparent; border-radius: 50%; cursor: pointer; outline: 2px solid transparent; outline-offset: 2px; }
	.color-dot.chosen { outline-color: var(--schedule-ink); }
	.color-teal { background: #159a8c; } .color-violet { background: #8067c8; } .color-amber { background: #d28a2e; } .color-rose { background: #c65c73; }
	.time-adjustment { display: grid; gap: 0.45rem; }
	.time-adjustment > span { color: var(--schedule-muted); font-size: 0.82rem; font-weight: 700; }
	.time-adjustment > div { display: grid; grid-template-columns: repeat(4, 1fr); gap: 0.4rem; }
	.time-adjustment button { min-height: 2.3rem; border: 1px solid var(--schedule-line); border-radius: 0.6rem; background: var(--schedule-soft); color: var(--schedule-ink); font: inherit; font-size: 0.72rem; font-weight: 700; cursor: pointer; }
	.time-adjustment button:hover { border-color: var(--primary); }
	.time-adjustment small { color: var(--schedule-muted); font-size: 0.7rem; line-height: 1.5; }
	.modal-actions, .modal-main-actions { display: flex; align-items: center; gap: 0.5rem; }
	.modal-actions { justify-content: space-between; gap: 1rem; margin-top: 0.25rem; }
	.danger-button { padding: 0.55rem 0.7rem; border-radius: 0.65rem; background: transparent; color: #d05b57; font-size: 0.8rem; font-weight: 800; }
	.danger-button:hover { background: color-mix(in oklch, #c2413e 9%, transparent); }
	@keyframes status-pulse { 50% { opacity: 0.35; transform: scale(0.85); } }
	@media (max-width: 900px) {
		.board-header { flex-direction: column; }
		.account-actions { width: 100%; justify-content: flex-start; }
		.account-email { margin-right: auto; }
	}
	@media (max-width: 700px) {
		.auth-card { grid-template-columns: 1fr; gap: 2rem; padding: 1.25rem; }
		.board-header { padding: 1.15rem; }
		.account-email { width: 100%; max-width: none; margin-right: 0; }
		.form-grid { grid-template-columns: 1fr; }
		.full-field { grid-column: auto; }
		.modal-actions { align-items: stretch; flex-direction: column-reverse; }
		.modal-main-actions, .modal-main-actions button, .danger-button { width: 100%; }
		.time-adjustment > div { grid-template-columns: repeat(2, 1fr); }
	}
	@media (prefers-reduced-motion: reduce) {
		.primary-button, .plain-button, .icon-button, .sync-status.loading span { transition: none; animation: none; }
	}
</style>
