CREATE TABLE "users" (
	"id"			integer PRIMARY KEY,
	"username"		text UNIQUE,
	"admin"			integer DEFAULT 0,
	"elo"			integer DEFAULT 1500,
	"pw_hash"		text NOT NULL DEFAULT 'hello',
	"disabled"		INTEGER NOT NULL DEFAULT 0
)

CREATE TABLE "results" (
	"id"				INTEGER,
	"status"			INTEGER DEFAULT 0,
	"elo_change"		int NOT NULL DEFAULT 0,
	"timestamp"			TEXT DEFAULT CURRENT_TIMESTAMP,
	PRIMARY KEY("id")
)

CREATE TABLE "challenges" (
	"user_id"			INTEGER,
	"result_id" 		INTEGER,
	"move"				text DEFAULT 'rock',
	FOREIGN KEY("user_id") REFERENCES "users"("id"),
	FOREIGN KEY("result_id") REFERENCES "results"("id")
)

