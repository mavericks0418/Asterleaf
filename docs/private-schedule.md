# 私有日程功能配置

日程页面地址：`/Asterleaf/schedule/`

这个功能使用 Supabase Auth 和 PostgreSQL RLS。文章站点仍然是静态部署，但日程数据只通过 Supabase API 按登录用户读取，不会写入 Astro 构建产物。

## 配置步骤

1. 创建一个 Supabase 项目。
2. 在 Supabase 的 SQL Editor 中依次执行 `supabase/schedule.sql`（定时日程）和 `supabase/schedule_tasks.sql`（非时段任务）。首次配置时各执行一次；如果任务面板提示 RLS 权限不完整，可以安全地重新执行 `supabase/schedule_tasks.sql`。
3. 在 Supabase 的 Authentication -> URL Configuration 中，将网站地址加入 Site URL 和 Redirect URLs，例如：

   `https://mavericks0418.github.io/Asterleaf/`

4. 在项目根目录创建 `.env`，填写 Supabase 项目设置中的 URL 和 anon public key：

   ```env
   PUBLIC_SUPABASE_URL=https://你的项目.supabase.co
   PUBLIC_SUPABASE_ANON_KEY=你的-anon-public-key
   ```

5. 本地运行 `pnpm dev`，打开 `/Asterleaf/schedule/` 注册你的账号。
6. 在部署平台的环境变量中添加同样的两个 `PUBLIC_` 变量，然后重新构建部署。

## 隐私说明

Supabase 的 anon key 可以出现在浏览器端，不能把 service role key 放进 `.env` 或前端代码。真正的权限由 `supabase/schedule.sql` 中的 RLS 策略保证：每条记录必须属于当前登录用户，其他账号无法读取、插入、修改或删除。

`schedule_events` 和 `schedule_tasks` 都启用了同样的用户级 RLS。可以在 Supabase 的 Table Editor 中分别打开这两张表查看记录，也可以在 SQL Editor 中执行：

```sql
select * from public.schedule_events order by event_date, start_time;
select * from public.schedule_tasks order by is_completed, position, created_at;
```
