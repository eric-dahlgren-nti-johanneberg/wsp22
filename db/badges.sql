drop table if exists badges; 
drop table if exists badges_users;; 

create table badges (
    bd_id integer PRIMARY key AUTOINCREMENT,
    bd_desc text,
    bd_name text
);

create table badges_users (
    bd_id integer references badges(bd_id),
    user_id integer references users(id),
    assigned_at text default CURRENT_TIMESTAMP
);