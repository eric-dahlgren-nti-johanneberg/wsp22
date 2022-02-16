drop table if exists users;

create table users (
    id integer primary key AUTOINCREMENT,
    username text UNIQUE,
    pwDigest text not null,
    admin integer default 0,
    elo integer DEFAULT 1500
);