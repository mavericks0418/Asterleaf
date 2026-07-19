# 日程云端数据检查

日程数据保存在 Supabase 项目的 `public.schedule_events` 表中。网页上的新增、修改和删除都会直接操作这张表。

## 在控制台查看

1. 打开 Supabase Dashboard，并进入当前项目。
2. 选择 **Table Editor**。
3. 打开 `schedule_events` 表。
4. 按 `event_date` 或 `updated_at` 排序。

字段含义：

- `id`：日程的唯一标识，修改时保持不变。
- `user_id`：日程所属的 Supabase Auth 用户。
- `title`、`description`：事项和备注。
- `event_date`、`start_time`、`end_time`：日期与时间。
- `color`：日历颜色。
- `created_at`：首次创建时间。
- `updated_at`：最后修改时间。

## 在 SQL Editor 查询

查看全部现存日程：

```sql
select
  id,
  user_id,
  title,
  event_date,
  start_time,
  end_time,
  color,
  created_at,
  updated_at
from public.schedule_events
order by event_date, start_time;
```

同时显示账号邮箱：

```sql
select
  users.email,
  events.id,
  events.title,
  events.event_date,
  events.start_time,
  events.end_time,
  events.created_at,
  events.updated_at
from public.schedule_events as events
join auth.users as users on users.id = events.user_id
order by events.event_date, events.start_time;
```

只查最近修改的记录：

```sql
select *
from public.schedule_events
order by updated_at desc
limit 20;
```

## 如何判断操作是否成功

- 新增：出现一个新的 `id`，`created_at` 和 `updated_at` 接近当前时间。
- 修改：`id` 不变，字段内容和 `updated_at` 更新。
- 删除：对应 `id` 从 `schedule_events` 表消失。

当前表只保存现存日程，删除后无法再从这张表查询历史记录。如需保留删除历史，需要另外增加审计表或软删除字段。

不要在 SQL Editor 中粘贴前端使用的 publishable key 或密码；查看数据不需要这些内容。
