export type ScheduleColor = "teal" | "violet" | "amber" | "rose";

export type ScheduleEvent = {
	id: string;
	user_id: string;
	title: string;
	description: string | null;
	event_date: string;
	start_time: string;
	end_time: string;
	color: ScheduleColor;
	created_at?: string;
	updated_at?: string;
};

export type ScheduleEventDraft = {
	id?: string;
	title: string;
	description: string;
	event_date: string;
	start_time: string;
	end_time: string;
	color: ScheduleColor;
};
