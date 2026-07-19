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
export type ScheduleTask = {
	id: string;
	user_id: string;
	title: string;
	notes: string;
	due_date: string | null;
	is_completed: boolean;
	position: number;
	created_at?: string;
	updated_at?: string;
};
