drop table if exists users;
drop table if exists user_activity;

create table users (
    id integer primary key AUTOINCREMENT,
    username text UNIQUE,
    pwDigest text not null,
    admin integer default 0,
    elo integer DEFAULT 1500
);

create table user_acitvity (
    user_id integer references users(id) not null,
    matches integer default 0,
    wins integer default 0,
    losses integer default 0,
    streak integer default 0
);