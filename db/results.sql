-- SQLite
drop table if exists results;

create table results (
    winner int,
    loser int,
    winner_elo_change int not null,
    loser_elo_change int not null,
    timestamp text DEFAULT CURRENT_TIMESTAMP
);