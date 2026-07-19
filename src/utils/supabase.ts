import { createClient, type SupabaseClient } from "@supabase/supabase-js";

let client: SupabaseClient | null | undefined;

/**
 * The public Supabase anon key is safe to ship to the browser. Privacy is
 * enforced by the database RLS policies in supabase/schedule.sql.
 */
export function getSupabaseClient(): SupabaseClient | null {
	if (client !== undefined) return client;

	const url = import.meta.env.PUBLIC_SUPABASE_URL;
	const anonKey = import.meta.env.PUBLIC_SUPABASE_ANON_KEY;

	client = url && anonKey ? createClient(url, anonKey) : null;
	return client;
}
