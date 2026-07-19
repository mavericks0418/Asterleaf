<script lang="ts">
	import { onMount } from "svelte";
	import type { Session, SupabaseClient } from "@supabase/supabase-js";
	import Icon from "@components/common/Icon.svelte";
	import { getSupabaseClient } from "@utils/supabase";
	import type {
		ScheduleColor,
		ScheduleEvent,
		ScheduleEventDraft,
	} from "@/types/schedule";

	type ViewMode = "week" | "day";
	type AuthMode = "sign-in" | "sign-up";

	const START_HOUR = 6;
	const END_HOUR = 24;
	const SLOT_MINUTES = 30;
	const SLOT_HEIGHT = 34;
	const TOTAL_MINUTES = (END_HOUR - START_HOUR) * 60;
	const SLOT_COUNT = TOTAL_MINUTES / SLOT_MINUTES;
	const DAY_NAMES = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"];
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
	let viewMode: ViewMode = "week";
	let visibleDate = startOfDay(new Date());
	let selectedDate = startOfDay(new Date());
	let events: ScheduleEvent[] = [];
	let draft: ScheduleEventDraft = createDraft(dateKey(selectedDate));
	let editorOpen = false;

	$: displayedDays = getDisplayedDays();
	$: rangeStart = dateKey(displayedDays[0] ?? visibleDate);
	$: rangeEnd = dateKey(displayedDays[displayedDays.length - 1] ?? visibleDate);
	$: dateRangeLabel = getDateRangeLabel(displayedDays);
	$: visibleEvents = events.filter(
		(event) => event.event_date >= rangeStart && event.event_date <= rangeEnd,
	);

	onMount(async () => {
		supabase = getSupabaseClient();
		initialized = true;

		if (!supabase) return;

		const {
			data: { session: currentSession },
		} = await supabase.auth.getSession();
		session = currentSession;
		if (session) await loadEvents();

		const {
			data: { subscription },
		} = supabase.auth.onAuthStateChange((_event, nextSession) => {
			session = nextSession;
			if (!nextSession) {
				events = [];
				return;
			}
			void loadEvents();
		});

		return () => subscription.unsubscribe();
	});

	function startOfDay(value: Date): Date {
		const date = new Date(value);
		date.setHours(12, 0, 0, 0);
		return date;
	}

	function startOfWeek(value: Date): Date {
		const date = startOfDay(value);
		const day = date.getDay();
		date.setDate(date.getDate() + (day === 0 ? -6 : 1 - day));
		return date;
	}

	function addDays(value: Date, amount: number): Date {
		const date = startOfDay(value);
		date.setDate(date.getDate() + amount);
		return date;
	}

	function dateKey(value: Date): string {
		const year = value.getFullYear();
		const month = String(value.getMonth() + 1).padStart(2, "0");
		const day = String(value.getDate()).padStart(2, "0");
		return `${year}-${month}-${day}`;
	}

	function dateFromKey(value: string): Date {
		return startOfDay(new Date(`${value}T12:00:00`));
	}

	function indexOfDay(value: Date): number {
		const day = value.getDay();
		return day === 0 ? 6 : day - 1;
	}

	function getDisplayedDays(): Date[] {
		if (viewMode === "day") return [startOfDay(visibleDate)];
		const monday = startOfWeek(visibleDate);
		return Array.from({ length: 7 }, (_, index) => addDays(monday, index));
	}

	function getDateRangeLabel(days: Date[]): string {
		const first = days[0] ?? visibleDate;
		const last = days[days.length - 1] ?? first;
		const firstMonth = first.getMonth() + 1;
		const lastMonth = last.getMonth() + 1;
		if (firstMonth === lastMonth) {
return `${first.getFullYear()}-${String(firstMonth).padStart(2, "0")}-${String(first.getDate()).padStart(2, "0")} / ${String(last.getDate()).padStart(2, "0")}`;
		}
return `${first.getFullYear()}-${String(firstMonth).padStart(2, "0")}-${String(first.getDate()).padStart(2, "0")} / ${String(last.getMonth() + 1).padStart(2, "0")}-${String(last.getDate()).padStart(2, "0")}`;
	}

	function formatDay(value: Date): string {
		return new Intl.DateTimeFormat("zh-CN", {
			month: "short",
			day: "numeric",
		}).format(value);
	}

	function formatHour(hour: number): string {
		return `${String(hour).padStart(2, "0")}:00`;
	}

	function formatTime(value: string): string {
		return value.slice(0, 5);
	}

	function minutesFromTime(value: string): number {
		const [hour = 0, minute = 0] = value.split(":").map(Number);
		return hour * 60 + minute;
	}

	function createDraft(date = dateKey(selectedDate), start = "09:00"): ScheduleEventDraft {
		const endMinutes = Math.min(minutesFromTime(start) + 60, END_HOUR * 60);
		return {
			title: "",
			description: "",
			event_date: date,
			start_time: start,
			end_time: formatTime(`${String(Math.floor(endMinutes / 60)).padStart(2, "0")}:${String(endMinutes % 60).padStart(2, "0")}`),
			color: "teal",
		};
	}

	function eventStyle(event: ScheduleEvent): string {
		const start = Math.max(minutesFromTime(event.start_time), START_HOUR * 60);
		const end = Math.min(minutesFromTime(event.end_time), END_HOUR * 60);
		const top = ((start - START_HOUR * 60) / SLOT_MINUTES) * SLOT_HEIGHT;
		const height = Math.max(((end - start) / SLOT_MINUTES) * SLOT_HEIGHT - 4, 28);
		return `top: ${top}px; height: ${height}px;`;
	}

	function slotStyle(index: number): string {
		return `top: ${index * SLOT_HEIGHT}px; height: ${SLOT_HEIGHT}px;`;
	}

	function eventsForDay(day: Date): ScheduleEvent[] {
		return visibleEvents.filter((event) => event.event_date === dateKey(day));
	}

	function isToday(day: Date): boolean {
		return dateKey(day) === dateKey(new Date());
	}

	function currentTimeStyle(day: Date): string {
		const now = new Date();
		const minutes = now.getHours() * 60 + now.getMinutes();
		const top = ((minutes - START_HOUR * 60) / SLOT_MINUTES) * SLOT_HEIGHT;
		return `top: ${Math.max(0, Math.min(top, TOTAL_MINUTES * SLOT_HEIGHT / SLOT_MINUTES))}px;`;
	}

	function changeDate(amount: number): void {
		visibleDate = addDays(visibleDate, viewMode === "week" ? amount * 7 : amount);
		selectedDate = visibleDate;
		if (session) void loadEvents();
	}

	function goToday(): void {
		visibleDate = startOfDay(new Date());
		selectedDate = visibleDate;
		if (session) void loadEvents();
	}

	function switchView(nextView: ViewMode): void {
		viewMode = nextView;
		if (session) void loadEvents();
	}

	function openNewEditor(day = selectedDate, start = "09:00"): void {
		errorMessage = "";
		authMessage = "";
		selectedDate = startOfDay(day);
		draft = createDraft(dateKey(day), start);
		editorOpen = true;
	}

	function openEditor(event: ScheduleEvent): void {
		errorMessage = "";
		authMessage = "";
		draft = {
			id: event.id,
			title: event.title,
			description: event.description ?? "",
			event_date: event.event_date,
			start_time: formatTime(event.start_time),
			end_time: formatTime(event.end_time),
			color: event.color,
		};
		editorOpen = true;
	}

	function handleSlotClick(event: MouseEvent, day: Date): void {
		const target = event.currentTarget as HTMLElement;
		const rect = target.getBoundingClientRect();
		const minutes = START_HOUR * 60 + Math.floor((event.clientY - rect.top) / SLOT_HEIGHT) * SLOT_MINUTES;
		const hour = Math.floor(minutes / 60);
		const minute = minutes % 60;
		const start = `${String(hour).padStart(2, "0")}:${String(minute).padStart(2, "0")}`;
		openNewEditor(day, start);
	}

	async function loadEvents(): Promise<void> {
		if (!supabase || !session) return;
		isLoading = true;
		errorMessage = "";
		const days = getDisplayedDays();
		const start = dateKey(days[0] ?? visibleDate);
		const end = dateKey(days[days.length - 1] ?? visibleDate);
		const { data, error } = await supabase
			.from("schedule_events")
			.select("*")
			.gte("event_date", start)
			.lte("event_date", end)
			.order("event_date")
			.order("start_time");

		if (error) {
			errorMessage = error.message;
		} else {
			events = (data ?? []) as ScheduleEvent[];
		}
		isLoading = false;
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
			const result = authMode === "sign-in"
				? await supabase.auth.signInWithPassword({ email, password })
				: await supabase.auth.signUp({
					email,
					password,
					options: { emailRedirectTo: getAuthRedirectUrl() },
				});

			if (result.error) {
				errorMessage = result.error.message;
			} else if (authMode === "sign-up" && !result.data.session) {
				authMessage = "注册成功，请先完成邮箱确认。";
			} else {
				authMessage = "登录成功。";
			}
		} catch (error) {
			errorMessage = error instanceof Error ? error.message : "操作失败，请稍后重试。";
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
			if (error) {
				errorMessage = error.message;
			} else {
				authMessage = "确认邮件已重新发送，请检查收件箱与垃圾邮件。";
			}
		} catch (error) {
			errorMessage = error instanceof Error ? error.message : "邮件发送失败，请稍后重试。";
		} finally {
			isLoading = false;
		}
	}
	async function signOut(): Promise<void> {
		if (!supabase) return;
		await supabase.auth.signOut();
	}

	async function saveEvent(): Promise<void> {
		if (!supabase || !session) return;
		errorMessage = "";
		if (!draft.title.trim()) {
			errorMessage = "请填写日程标题。";
			return;
		}
		if (draft.end_time <= draft.start_time) {
			errorMessage = "End时间必须晚于Start时间。";
			return;
		}

		isSaving = true;
		const payload = {
			title: draft.title.trim(),
			description: draft.description.trim(),
			event_date: draft.event_date,
			start_time: draft.start_time,
			end_time: draft.end_time,
			color: draft.color,
		};
		const result = draft.id
			? await supabase.from("schedule_events").update(payload).eq("id", draft.id)
			: await supabase.from("schedule_events").insert({ ...payload, user_id: session.user.id });

		if (result.error) {
			errorMessage = result.error.message;
		} else {
			visibleDate = dateFromKey(draft.event_date);
			selectedDate = visibleDate;
			editorOpen = false;
			await loadEvents();
		}
		isSaving = false;
	}

	async function deleteEvent(): Promise<void> {
		if (!supabase || !session || !draft.id) return;
		if (!window.confirm("确定删除这个日程吗？")) return;
		isDeleting = true;
		errorMessage = "";
		const { error } = await supabase.from("schedule_events").delete().eq("id", draft.id);
		if (error) {
			errorMessage = error.message;
		} else {
			editorOpen = false;
			await loadEvents();
		}
		isDeleting = false;
	}
</script>

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
				<p>请先配置 <code>PUBLIC_SUPABASE_URL</code> 和 <code>PUBLIC_SUPABASE_ANON_KEY</code>，再使用这个私有空间。</p>
				<p class="state-help">配置方法请参考 <code>docs/private-schedule.md</code>。</p>
			</div>
		</section>
	{:else if !session}
		<section class="schedule-card auth-card">
			<div class="auth-intro">
				<div class="eyebrow"><Icon icon="material-symbols:lock-outline" /> PRIVATE SPACE</div>
				<h2>只有你的账号可以看到</h2>
				<p>日程不会出现在公开博客中，登录后才会加载。</p>
			</div>
			<form class="auth-form" on:submit|preventDefault={submitAuth}>
				<label>
					<span>邮箱</span>
					<input type="email" autocomplete="email" bind:value={email} required placeholder="you@example.com" />
				</label>
				<label>
					<span>密码</span>
					<input type="password" autocomplete={authMode === "sign-in" ? "current-password" : "new-password"} bind:value={password} minlength="6" required placeholder="至少 6 位" />
				</label>
				{#if errorMessage}<p class="form-error">{errorMessage}</p>{/if}
				{#if authMessage}<p class="form-success">{authMessage}</p>{/if}
				{#if authMode === "sign-up" && authMessage}
					<button class="text-button" type="button" on:click={resendConfirmation} disabled={isLoading}>重新发送确认邮件</button>
				{/if}
				<button class="primary-button" type="submit" disabled={isLoading}>
					{isLoading ? "处理中…" : authMode === "sign-in" ? "登录日程" : "创建账号"}
				</button>
				<button class="text-button" type="button" on:click={() => { authMode = authMode === "sign-in" ? "sign-up" : "sign-in"; errorMessage = ""; authMessage = ""; }}>
					{authMode === "sign-in" ? "第一次使用？创建一个账号" : "Already have an account? 登录日程"}
				</button>
			</form>
		</section>
	{:else}
		<section class="schedule-card board-card">
			<header class="board-header">
				<div>
					<div class="eyebrow"><Icon icon="material-symbols:calendar-month-outline-rounded" /> PERSONAL PLANNER</div>
					<h1>我的日程</h1>
					<p class="board-subtitle">安排好Today，也给下一步留一点空间。</p>
				</div>
				<div class="account-actions">
					<span class="account-email" title={session.user.email}>{session.user.email}</span>
					<button class="plain-button" type="button" on:click={signOut}><Icon icon="material-symbols:logout" />退出</button>
				</div>
			</header>

			<div class="toolbar">
				<div class="date-navigation">
					<button class="icon-button" type="button" aria-label="上一个时间段" on:click={() => changeDate(-1)}><Icon icon="material-symbols:chevron-left-rounded" /></button>
					<button class="today-button" type="button" on:click={goToday}>Today</button>
					<button class="icon-button" type="button" aria-label="下一个时间段" on:click={() => changeDate(1)}><Icon icon="material-symbols:chevron-right-rounded" /></button>
					<strong>{dateRangeLabel}</strong>
				</div>
				<div class="toolbar-actions">
					<div class="view-switch" aria-label="切换日程视图">
						<button class:active={viewMode === "day"} type="button" on:click={() => switchView("day")}>日</button>
						<button class:active={viewMode === "week"} type="button" on:click={() => switchView("week")}>周</button>
					</div>
					<button class="primary-button compact" type="button" on:click={() => openNewEditor()}><Icon icon="material-symbols:add" />添加日程</button>
				</div>
			</div>

			{#if errorMessage}<div class="inline-message form-error"><Icon icon="material-symbols:error-outline" />{errorMessage}</div>{/if}

			<div class="schedule-scroller" aria-label="日程时间表">
				<div class="schedule-canvas" style={`--day-count: ${displayedDays.length}; --schedule-height: ${TOTAL_MINUTES / SLOT_MINUTES * SLOT_HEIGHT}px;`}>
					<div class="day-header-row">
						<div class="time-gutter"></div>
						{#each displayedDays as day, index}
							<button class:today={isToday(day)} class="day-heading" type="button" on:click={() => { selectedDate = day; viewMode = "day"; visibleDate = day; }}>
								<span>{DAY_NAMES[indexOfDay(day)]}</span>
								<strong>{formatDay(day)}</strong>
							</button>
						{/each}
					</div>
					<div class="timeline-row">
						<div class="time-axis">
							{#each Array.from({ length: END_HOUR - START_HOUR }, (_, index) => START_HOUR + index) as hour, index}
								<span style={`top: ${index * SLOT_HEIGHT * 2 - 8}px;`}>{formatHour(hour)}</span>
							{/each}
						</div>
						<div class="days-grid">
							{#each displayedDays as day}
								<div class="day-column">
									{#each Array.from({ length: SLOT_COUNT }, (_, index) => index) as slotIndex}
										<button class="time-slot" type="button" style={slotStyle(slotIndex)} aria-label={`添加日程 on ${dateKey(day)}`} on:click={(event) => handleSlotClick(event, day)}></button>
									{/each}
									{#each eventsForDay(day) as event (event.id)}
										<button class={`schedule-event event-${event.color}`} type="button" style={eventStyle(event)} on:click|stopPropagation={() => openEditor(event)}>
											<strong>{event.title}</strong>
											<span>{formatTime(event.start_time)} - {formatTime(event.end_time)}</span>
										</button>
									{/each}
									{#if isToday(day)}
										<div class="current-time-line" style={currentTimeStyle(day)} aria-hidden="true"><span></span></div>
									{/if}
								</div>
							{/each}
						</div>
					</div>
				</div>
			</div>
			{#if isLoading}<div class="loading-note"><Icon icon="svg-spinners:ring-resize" /></div>{/if}
		</section>
	{/if}
</div>

{#if editorOpen}
	<div class="modal-backdrop" role="presentation" on:click={(event) => { if (event.target === event.currentTarget) editorOpen = false; }}>
		<div class="editor-modal" role="dialog" aria-modal="true" aria-labelledby="schedule-editor-title">
			<div class="modal-heading">
				<div>
					<div class="eyebrow">{draft.id ? "修改日程" : "添加日程"}</div>
					<h2 id="schedule-editor-title">{draft.id ? "修改日程" : "添加日程"}</h2>
				</div>
				<button class="icon-button" type="button" aria-label="关闭" on:click={() => editorOpen = false}><Icon icon="material-symbols:close-rounded" /></button>
			</div>
			<form class="editor-form" on:submit|preventDefault={saveEvent}>
				<label class="full-field"><span>事项</span><input bind:value={draft.title} maxlength="120" required placeholder="例如：阅读、会议、运动" /></label>
				<div class="form-grid">
					<label><span>Date</span><input type="date" bind:value={draft.event_date} required /></label>
					<label><span>Color</span><div class="color-options">{#each COLORS as color}<button class:chosen={draft.color === color} class={`color-dot color-${color}`} type="button" aria-label={color} on:click={() => draft.color = color}></button>{/each}</div></label>
					<label><span>Start</span><input type="time" bind:value={draft.start_time} required /></label>
					<label><span>End</span><input type="time" bind:value={draft.end_time} required /></label>
				</div>
				<label class="full-field"><span>备注 <em>可选</em></span><textarea bind:value={draft.description} maxlength="2000" rows="3" placeholder="补充地点、链接或提醒"></textarea></label>
				{#if errorMessage}<p class="form-error">{errorMessage}</p>{/if}
				<div class="modal-actions">
					{#if draft.id}<button class="danger-button" type="button" on:click={deleteEvent} disabled={isDeleting}>{isDeleting ? "删除中…" : "删除"}</button>{/if}
					<div class="modal-main-actions"><button class="plain-button" type="button" on:click={() => editorOpen = false}>取消</button><button class="primary-button compact" type="submit" disabled={isSaving}>{isSaving ? "保存中…" : "保存日程"}</button></div>
				</div>
			</form>
		</div>
	</div>
{/if}

<style>
	.schedule-board {
		--schedule-ink: var(--deep-text);
		--schedule-muted: color-mix(in oklch, var(--schedule-ink) 55%, transparent);
		--schedule-line: color-mix(in oklch, var(--schedule-ink) 10%, transparent);
		--schedule-soft: color-mix(in oklch, var(--primary) 9%, var(--card-bg));
		color: var(--schedule-ink);
	}

	.schedule-card {
		background: color-mix(in oklch, var(--card-bg) 92%, transparent);
		border: 1px solid var(--line-divider);
		border-radius: var(--radius-large);
		box-shadow: 0 18px 60px color-mix(in oklch, var(--schedule-ink) 8%, transparent);
		backdrop-filter: blur(14px);
	}

	.schedule-state {
		min-height: 260px;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 1rem;
		padding: 2rem;
		text-align: left;
	}

	.schedule-state h2,
	.auth-card h2,
	.editor-modal h2 {
		margin: 0;
		font-size: 1.5rem;
		font-weight: 800;
	}

	.schedule-state p,
	.auth-intro p {
		margin: 0.45rem 0 0;
		color: var(--schedule-muted);
		line-height: 1.7;
	}

	.state-orb {
		width: 3rem;
		height: 3rem;
		display: grid;
		place-items: center;
		border-radius: 1rem;
		background: var(--schedule-soft);
		color: var(--primary);
		font-size: 1.4rem;
		flex: 0 0 auto;
	}

	.state-help { font-size: 0.85rem; }
	code { padding: 0.1rem 0.35rem; border-radius: 0.35rem; background: var(--btn-regular-bg); color: var(--btn-content); font-size: 0.85em; }

	.auth-card {
		display: grid;
		grid-template-columns: minmax(0, 1fr) minmax(280px, 380px);
		gap: 3rem;
		padding: clamp(1.5rem, 5vw, 4.5rem);
		align-items: center;
	}

	.auth-intro { max-width: 34rem; }
	.auth-intro h2 { margin-top: 0.7rem; font-size: clamp(2rem, 5vw, 3.5rem); letter-spacing: -0.04em; }
	.eyebrow { display: flex; align-items: center; gap: 0.45rem; color: var(--primary); font-size: 0.72rem; font-weight: 800; letter-spacing: 0.13em; }

	.auth-form, .editor-form { display: grid; gap: 1rem; }
	.auth-form label, .editor-form label { display: grid; gap: 0.45rem; color: var(--schedule-muted); font-size: 0.82rem; font-weight: 700; }
	.auth-form input, .editor-form input, .editor-form textarea {
		width: 100%;
		border: 1px solid var(--line-divider);
		border-radius: 0.75rem;
		background: color-mix(in oklch, var(--page-bg) 38%, var(--card-bg));
		color: var(--schedule-ink);
		padding: 0.72rem 0.8rem;
		outline: none;
		transition: border-color 150ms ease, box-shadow 150ms ease;
	}
	.auth-form input:focus, .editor-form input:focus, .editor-form textarea:focus { border-color: var(--primary); box-shadow: 0 0 0 3px color-mix(in oklch, var(--primary) 18%, transparent); }

	.primary-button, .plain-button, .today-button, .icon-button, .text-button, .danger-button { border: 0; cursor: pointer; font: inherit; transition: transform 150ms ease, background 150ms ease, opacity 150ms ease; }
	.primary-button:active, .plain-button:active, .today-button:active, .icon-button:active, .danger-button:active { transform: translateY(1px) scale(0.98); }
	.primary-button { display: inline-flex; align-items: center; justify-content: center; gap: 0.5rem; min-height: 2.75rem; padding: 0.7rem 1rem; border-radius: 0.75rem; background: var(--primary); color: oklch(0.22 0.03 var(--hue)); font-weight: 800; }
	.primary-button:hover { filter: saturate(1.08) brightness(0.98); }
	.primary-button:disabled { opacity: 0.55; cursor: wait; }
	.primary-button.compact { min-height: 2.4rem; padding: 0.55rem 0.85rem; font-size: 0.86rem; }
	.text-button { background: transparent; color: var(--primary); font-size: 0.82rem; font-weight: 700; }
	.text-button:hover { text-decoration: underline; }
	.form-error, .form-success { margin: 0; font-size: 0.82rem; line-height: 1.5; }
	.form-error { color: #c2413e; }
	.form-success { color: #168267; }

	.board-card { overflow: hidden; }
	.board-header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; padding: clamp(1.25rem, 3vw, 2rem) clamp(1.25rem, 3vw, 2.5rem) 1.2rem; }
	.board-header h1 { margin: 0.35rem 0 0; font-size: clamp(1.7rem, 4vw, 2.55rem); letter-spacing: -0.045em; }
	.board-subtitle { margin: 0.3rem 0 0; color: var(--schedule-muted); font-size: 0.88rem; }
	.account-actions { display: flex; align-items: center; gap: 0.75rem; }
	.account-email { max-width: 16rem; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; color: var(--schedule-muted); font-size: 0.78rem; }
	.plain-button, .today-button { display: inline-flex; align-items: center; justify-content: center; gap: 0.4rem; padding: 0.55rem 0.7rem; border-radius: 0.65rem; background: transparent; color: var(--schedule-muted); font-size: 0.8rem; font-weight: 700; }
	.plain-button:hover, .today-button:hover { background: var(--btn-regular-bg); color: var(--schedule-ink); }

	.toolbar { display: flex; align-items: center; justify-content: space-between; gap: 1rem; padding: 0.85rem clamp(1.25rem, 3vw, 2.5rem); border-top: 1px solid var(--line-divider); border-bottom: 1px solid var(--line-divider); }
	.date-navigation, .toolbar-actions, .modal-main-actions { display: flex; align-items: center; gap: 0.5rem; }
	.date-navigation strong { margin-left: 0.35rem; font-size: 0.95rem; }
	.icon-button { width: 2.25rem; height: 2.25rem; display: inline-grid; place-items: center; border-radius: 0.65rem; background: transparent; color: var(--schedule-muted); font-size: 1.25rem; }
	.icon-button:hover { background: var(--btn-regular-bg); color: var(--schedule-ink); }
	.view-switch { display: flex; gap: 0.2rem; padding: 0.2rem; border-radius: 0.65rem; background: var(--btn-regular-bg); }
	.view-switch button { border: 0; border-radius: 0.5rem; padding: 0.38rem 0.7rem; background: transparent; color: var(--schedule-muted); cursor: pointer; font: inherit; font-size: 0.8rem; font-weight: 800; }
	.view-switch button.active { background: var(--card-bg); color: var(--schedule-ink); box-shadow: 0 2px 8px color-mix(in oklch, var(--schedule-ink) 10%, transparent); }
	.inline-message { display: flex; align-items: center; gap: 0.45rem; margin: 0.8rem 1.25rem 0; padding: 0.7rem 0.8rem; border-radius: 0.65rem; background: color-mix(in oklch, #c2413e 8%, transparent); }

	.schedule-scroller { overflow-x: auto; scrollbar-width: thin; }
	.schedule-canvas { min-width: 720px; }
	.day-header-row, .timeline-row { display: grid; grid-template-columns: 4.5rem minmax(0, 1fr); }
	.day-header-row { border-bottom: 1px solid var(--line-divider); }
	.time-gutter { border-right: 1px solid var(--line-divider); }
	.day-header-row > :not(.time-gutter) { display: grid; grid-template-columns: repeat(var(--day-count), minmax(0, 1fr)); }
	.day-heading { min-height: 4rem; display: flex; align-items: center; justify-content: center; gap: 0.25rem; flex-direction: column; border: 0; border-left: 1px solid var(--line-divider); background: transparent; color: var(--schedule-muted); cursor: pointer; font: inherit; }
	.day-heading span { font-size: 0.72rem; }
	.day-heading strong { color: var(--schedule-ink); font-size: 0.85rem; }
	.day-heading.today strong { color: var(--primary); }
	.timeline-row { min-height: var(--schedule-height); }
	.time-axis { position: relative; border-right: 1px solid var(--line-divider); }
	.time-axis span { position: absolute; right: 0.6rem; color: var(--schedule-muted); font-size: 0.68rem; transform: translateY(-50%); }
	.days-grid { position: relative; display: grid; grid-template-columns: repeat(var(--day-count), minmax(0, 1fr)); }
	.day-column { position: relative; min-height: var(--schedule-height); border-left: 1px solid var(--schedule-line); background-image: repeating-linear-gradient(to bottom, transparent 0, transparent calc(34px - 1px), var(--schedule-line) 34px); }
	.time-slot { position: absolute; z-index: 1; left: 0; width: 100%; border: 0; border-top: 1px solid transparent; background: transparent; cursor: crosshair; }
	.time-slot:hover { background: color-mix(in oklch, var(--primary) 7%, transparent); }
	.schedule-event { position: absolute; z-index: 3; left: 0.3rem; right: 0.3rem; overflow: hidden; display: flex; align-items: flex-start; flex-direction: column; gap: 0.1rem; padding: 0.38rem 0.48rem; border: 1px solid color-mix(in oklch, var(--event-color) 35%, transparent); border-left: 3px solid var(--event-color); border-radius: 0.55rem; background: color-mix(in oklch, var(--event-color) 17%, var(--card-bg)); color: var(--schedule-ink); cursor: pointer; text-align: left; box-shadow: 0 4px 12px color-mix(in oklch, var(--event-color) 12%, transparent); }
	.schedule-event:hover { filter: brightness(0.98); transform: translateY(-1px); }
	.schedule-event strong { max-width: 100%; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; font-size: 0.76rem; }
	.schedule-event span { color: var(--schedule-muted); font-size: 0.65rem; }
	.event-teal { --event-color: #159a8c; } .event-violet { --event-color: #8067c8; } .event-amber { --event-color: #d28a2e; } .event-rose { --event-color: #c65c73; }
	.current-time-line { position: absolute; z-index: 4; left: -0.3rem; right: 0; height: 2px; background: #df5d55; pointer-events: none; }
	.current-time-line span { position: absolute; left: -0.23rem; top: -0.18rem; width: 0.48rem; height: 0.48rem; border-radius: 50%; background: #df5d55; }
	.loading-note { display: flex; justify-content: center; align-items: center; gap: 0.45rem; padding: 0.8rem; color: var(--schedule-muted); font-size: 0.75rem; }

	.modal-backdrop { position: fixed; z-index: 100; inset: 0; display: grid; place-items: center; padding: 1rem; background: color-mix(in oklch, #0b1020 48%, transparent); backdrop-filter: blur(5px); }
	.editor-modal { width: min(100%, 540px); max-height: min(90dvh, 700px); overflow: auto; padding: 1.35rem; border: 1px solid var(--line-divider); border-radius: var(--radius-large); background: var(--card-bg); box-shadow: 0 24px 80px color-mix(in oklch, #000 28%, transparent); }
	.modal-heading { display: flex; align-items: flex-start; justify-content: space-between; margin-bottom: 1.25rem; }
	.modal-heading h2 { margin-top: 0.3rem; }
	.form-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 1rem; }
	.full-field { grid-column: 1 / -1; }
	.editor-form em { color: var(--schedule-muted); font-size: 0.75rem; font-style: normal; font-weight: 400; }
	.editor-form textarea { resize: vertical; }
	.color-options { display: flex; align-items: center; gap: 0.65rem; min-height: 2.75rem; }
	.color-dot { width: 1.35rem; height: 1.35rem; border: 3px solid transparent; border-radius: 50%; cursor: pointer; outline: 2px solid transparent; outline-offset: 2px; }
	.color-dot.chosen { outline-color: var(--schedule-ink); }
	.color-teal { background: #159a8c; } .color-violet { background: #8067c8; } .color-amber { background: #d28a2e; } .color-rose { background: #c65c73; }
	.modal-actions { display: flex; align-items: center; justify-content: space-between; gap: 1rem; margin-top: 0.25rem; }
	.danger-button { padding: 0.55rem 0.7rem; border-radius: 0.65rem; background: transparent; color: #c2413e; font-size: 0.8rem; font-weight: 800; }
	.danger-button:hover { background: color-mix(in oklch, #c2413e 8%, transparent); }

	@media (max-width: 700px) {
		.auth-card { grid-template-columns: 1fr; gap: 2rem; padding: 1.25rem; }
		.board-header, .toolbar { align-items: flex-start; flex-direction: column; }
		.account-actions, .toolbar-actions { width: 100%; justify-content: space-between; }
		.account-email { max-width: 13rem; }
		.date-navigation { width: 100%; }
		.date-navigation strong { margin-left: auto; }
		.form-grid { grid-template-columns: 1fr; }
		.full-field { grid-column: auto; }
	}

	@media (prefers-reduced-motion: reduce) {
		.schedule-event, .primary-button, .plain-button, .today-button, .icon-button { transition: none; }
	}
</style>
