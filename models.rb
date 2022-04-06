require 'extralite'
require 'bcrypt'

# Modeller
#
module Models
  def db
    Extralite::Database.new 'db/dev.sqlite'
  end

  #
  #
  # -------- USERS --------
  #
  #

  def fetch_user(uid)
    db.query_single_row('select * from users where id = ?', uid)
  end

  def fetch_users
    db.query('select * from users order by elo desc')
  end

  def add_user(username, password)
    pw_hash = BCrypt::Password.create(password)
    db.query('insert into users (pw_hash, username) values($1, $2)', pw_hash, username)

    sign_in(username, password)
  end

  def sign_in(username, password)
    # är lösenordet rätt?
    db_password = db.query_single_value('select pw_hash from users where username = ?', username)
    match = BCrypt::Password.new(db_password) == password
    return 'No match' unless match

    user = db.query_single_row('select * from users where username = ?', username)
    session[:user] = user
    p user
  end

  def sign_out
    session&.destroy
  end

  #
  #
  # ------- Matches -------
  #
  #

  def fetch_latest_matches
    db.query('select

              rs.timestamp, winner_elo_change, loser_elo_change,
              w.username as winner_username, l.username as loser_username,
              winner, loser

              from results rs
              left join users w on rs.winner = w.id
              left join users l on rs.loser = l.id
              order by rs.timestamp desc limit 5')
  end

  def fetch_users_latest_matches(uid)
    db.query('select
    rs.timestamp, winner_elo_change, loser_elo_change,
    w.username as winner_username, l.username as loser_username,
    winner, loser

    from results rs
    left join users w on rs.winner = w.id
    left join users l on rs.loser = l.id
    where l.id = $1 or w.id = $1
    order by rs.timestamp desc limit 5', uid)
  end

  #
  #
  # ----- Achievements -----
  #
  #

  def fetch_avalible_achievements
    db.query('select * from badges')
  end
end
