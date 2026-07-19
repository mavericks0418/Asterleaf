<script lang="ts">
import "temporal-polyfill/global";
import {
	type CalendarApp,
	type CalendarEvent,
	createCalendar,
	createViewDay,
	createViewMonthGrid,
	createViewWeek,
} from "@schedule-x/calendar";
import { createEventsServicePlugin } from "@schedule-x/events-service";
import { ScheduleXCalendar } from "@schedule-x/svelte";
import { onMount } from "svelte";
import { Temporal } from "temporal-polyfill";
import "@schedule-x/theme-default/dist/index.css";
import type { ScheduleEvent } from "@/types/schedule";

export let events: ScheduleEvent[] = [];
export let onEdit: (event: ScheduleEvent) => void;
export let onCreate: (date: string, start: string) => void;

const TIMEZONE = "Asia/Shanghai";
const eventsService = createEventsServicePlugin();
let calendarApp: CalendarApp | null = null;
let themeObserver: MutationObserver | null = null;
let calendarReady = false;
let readyFrame: number | null = null;

$: if (calendarApp && calendarReady) {
	eventsService.set(events.map(toCalendarEvent));
}

onMount(() => {
	calendarApp = createCalendar(
		{
			views: [createViewWeek(), createViewDay(), createViewMonthGrid()],
			defaultView: "week",
			selectedDate: Temporal.PlainDate.from(localDateKey()),
			locale: "zh-CN",
			timezone: TIMEZONE,
			firstDayOfWeek: 1,
			dayBoundaries: { start: "06:00", end: "24:00" },
			weekOptions: {
				gridHeight: 1150,
				gridStep: 30,
				eventOverlap: true,
			},
			calendars: {
				teal: calendarColors(
					"#159a8c",
					"#d8f3ee",
					"#0b4e48",
					"#153f3a",
					"#9be4d8",
					"#e8fffb",
				),
				violet: calendarColors(
					"#8067c8",
					"#eee8ff",
					"#443082",
					"#4a3f70",
					"#cfc3ff",
					"#f8f5ff",
				),
				amber: calendarColors(
					"#c98222",
					"#fff0d2",
					"#6a3e08",
					"#62451e",
					"#f0ca82",
					"#fff8e9",
				),
				rose: calendarColors(
					"#c65c73",
					"#ffe5eb",
					"#75263a",
					"#6d3442",
					"#efb0bd",
					"#fff2f5",
				),
			},
			callbacks: {
				onEventClick: (event) => {
					const source = events.find((item) => item.id === String(event.id));
					if (source) onEdit(source);
				},
				onDoubleClickDateTime: (dateTime) => {
					onCreate(dateTime.toPlainDate().toString(), timeKey(dateTime));
				},
			},
			events: events.map(toCalendarEvent),
		},
		[eventsService],
	);
	readyFrame = window.requestAnimationFrame(() => {
		calendarReady = true;
	});

	syncTheme();
	themeObserver = new MutationObserver(syncTheme);
	themeObserver.observe(document.documentElement, {
		attributes: true,
		attributeFilter: ["class"],
	});

	return () => {
		if (readyFrame !== null) window.cancelAnimationFrame(readyFrame);
		themeObserver?.disconnect();
		calendarApp?.destroy();
	};
});

function calendarColors(
	lightMain: string,
	lightContainer: string,
	lightText: string,
	darkMain: string,
	darkContainer: string,
	darkText: string,
) {
	return {
		colorName: "custom",
		lightColors: {
			main: lightMain,
			container: lightContainer,
			onContainer: lightText,
		},
		darkColors: {
			main: darkMain,
			container: darkContainer,
			onContainer: darkText,
		},
	};
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

function toZonedDateTime(date: string, time: string): Temporal.ZonedDateTime {
	return Temporal.ZonedDateTime.from(
		`${date}T${normalizeTime(time)}:00+08:00[${TIMEZONE}]`,
	);
}

function toCalendarEvent(event: ScheduleEvent): CalendarEvent {
	return {
		id: event.id,
		title: event.title,
		description: event.description ?? "",
		start: toZonedDateTime(event.event_date, event.start_time),
		end: toZonedDateTime(event.event_date, event.end_time),
		calendarId: event.color,
		_options: {
			disableDND: true,
			disableResize: true,
		},
	};
}

function timeKey(dateTime: Temporal.ZonedDateTime): string {
	return `${String(dateTime.hour).padStart(2, "0")}:${String(dateTime.minute).padStart(2, "0")}`;
}

function syncTheme(): void {
	calendarApp?.setTheme(
		document.documentElement.classList.contains("dark") ? "dark" : "light",
	);
}
</script>

<div class="calendar-shell">
	{#if calendarApp}
		<ScheduleXCalendar {calendarApp} />
	{:else}
		<div class="calendar-skeleton" aria-label="正在加载日历">
			<div></div><div></div><div></div><div></div>
		</div>
	{/if}
</div>

<style>
	.calendar-shell {
		--sx-color-primary: #159a8c;
		--sx-color-on-primary: #ffffff;
		--sx-color-primary-container: #d8f3ee;
		--sx-color-on-primary-container: #0b4e48;
		--sx-color-secondary: #58736f;
		--sx-color-on-secondary: #ffffff;
		--sx-color-secondary-container: #dce9e6;
		--sx-color-on-secondary-container: #243f3b;
		--sx-color-tertiary: #8067c8;
		--sx-color-on-tertiary: #ffffff;
		--sx-color-tertiary-container: #eee8ff;
		--sx-color-on-tertiary-container: #443082;
		--sx-color-background: var(--card-bg);
		--sx-color-surface: var(--card-bg);
		--sx-color-surface-container: color-mix(in oklch, var(--page-bg) 45%, var(--card-bg));
		--sx-color-surface-container-low: color-mix(in oklch, var(--page-bg) 25%, var(--card-bg));
		--sx-color-surface-container-high: color-mix(in oklch, var(--page-bg) 60%, var(--card-bg));
		--sx-color-on-surface: var(--schedule-ink);
		--sx-color-on-background: var(--schedule-ink);
		--sx-color-outline: var(--schedule-muted);
		--sx-color-outline-variant: var(--schedule-line);
		--sx-internal-color-text: var(--schedule-ink);
		--sx-internal-color-light-gray: var(--schedule-soft);
		--sx-border: 1px solid var(--schedule-line);
		height: clamp(680px, 78vh, 980px);
		min-height: 680px;
		padding: 0 1rem 1rem;
	}

	:global(:root.dark) .calendar-shell {
		--sx-color-primary: #72d6c5;
		--sx-color-on-primary: #102b27;
		--sx-color-primary-container: #153f3a;
		--sx-color-on-primary-container: #e8fffb;
		--sx-color-secondary: #b8d1cc;
		--sx-color-on-secondary: #203733;
		--sx-color-secondary-container: #334a46;
		--sx-color-on-secondary-container: #e1f2ef;
		--sx-color-tertiary: #cfc3ff;
		--sx-color-on-tertiary: #35265f;
		--sx-color-tertiary-container: #4a3f70;
		--sx-color-on-tertiary-container: #f8f5ff;
	}

	:global(.calendar-shell .sx__calendar) {
		border-radius: 0.9rem;
		font-family: inherit;
	}

	:global(.calendar-shell .sx__calendar-header) {
		border-bottom: 1px solid var(--schedule-line);
	}

	:global(.calendar-shell .sx__time-grid-event) {
		border-radius: 0.5rem;
		box-shadow: 0 4px 14px color-mix(in oklch, var(--schedule-ink) 8%, transparent);
	}

	:global(.calendar-shell .sx__time-grid-event-title) {
		font-weight: 800;
	}

	:global(.calendar-shell button:focus-visible) {
		outline: 2px solid var(--primary);
		outline-offset: 2px;
	}

	.calendar-skeleton {
		display: grid;
		grid-template-columns: repeat(4, 1fr);
		gap: 1px;
		height: 100%;
		min-height: 680px;
		border: 1px solid var(--schedule-line);
		border-radius: 0.9rem;
		overflow: hidden;
		background: var(--schedule-line);
	}

	.calendar-skeleton div {
		background: linear-gradient(100deg, var(--card-bg) 20%, var(--schedule-soft) 45%, var(--card-bg) 70%);
		background-size: 220% 100%;
		animation: calendar-loading 1.4s ease-in-out infinite;
	}

	@keyframes calendar-loading {
		to { background-position-x: -220%; }
	}

	@media (max-width: 700px) {
		.calendar-shell {
			height: 720px;
			min-height: 720px;
			padding: 0 0.65rem 0.65rem;
		}
	}

	@media (prefers-reduced-motion: reduce) {
		.calendar-skeleton div { animation: none; }
	}
</style>
