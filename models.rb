require 'extralite'
require 'bcrypt'
require_relative 'elo'

# Modeller
#
module Models
  def db
    Extralite::Database.new 'db/dev.sqlite'
  end

  def verify_params(params, keys)
    keys.each do |key|
      return { key: key, message: "#{key} is invalid" } if params[key] == ''
    end
    nil
  end

  #
  #
  # -------- USERS --------
  #
  #

  def auth?
    !session[:user].nil?
  end

  def disabled?(u_id)
    disabled = db.query_single_value('select disabled_until from users where id = ?', u_id)
    return false unless disabled.nil? || disabled < '1'

    true
  end

  def admin?
    return false unless auth?

    user = session[:user][:id]
    db.query_single_value('select admin from users where id = ?', user).positive?
  end

  def can_modify(user)
    return false if user.nil? || !auth?

    user_rank = db.query_single_value('select admin from users where id = ?', user[:id])
    me_rank = db.query_single_value('select admin from users where id = ?', session[:user][:id])

    me_rank > user_rank
  end

  def fetch_user(uid)
    db.query_single_row('select * from users where id = ?', uid)
  end

  def fetch_users(disabled: false)
    str = 'select * from users order by elo desc'
    # str += " where disabled_until < CURRENT_TIMESTAMP" unless disabled
    db.query(str)
  end

  def user_exists(name)
    !db.query_single_value('select id from users where username = ?', name).nil?
  end

  def add_user(username, password)
    pw_hash = BCrypt::Password.create(password)
    db.query('insert into users (pw_hash, username) values($1, $2)', pw_hash, username)

    sign_in(username, password)
  end

  def sign_in(username, password)
    # är lösenordet rätt?
    db_password = db.query_single_value('select pw_hash from users where username = ?', username)
    p BCrypt::Password.create(password)
    match = BCrypt::Password.new(db_password) == password
    return 'No match' unless match

    user = db.query_single_row('select * from users where username = ?', username)
    session[:user] = user
    nil
  end

  def sign_out
    session&.destroy
  end

  def disable_user_1_week(id)
    return unless admin?

    db.query("update users set disabled = date('now', '+1 week') where id = ?", id)

  end

  #
  #
  # ------- Matches -------
  #
  #

  def create_challenge(challenger, challenged, move)
    db.query('insert into challenges (challenger_id, challenged_id, move) values (?, ?, ?)', challenger, challenged, move)
  end

  def fetch_challenges(user)
    return nil unless user
    return nil unless user[:id]

    db.query('select ch.username, ch.id as opponent_id, c.id as challenge_id from challenges c left join users ch on c.challenger_id = ch.id where challenged_id = ?', user[:id])
  end

  def fetch_challenge(id)
    db.query_single_row('select ch.username, ch.id, move as opponent_id from challenges c left join users ch on c.challenger_id = ch.id where c.id = ?', id)
  end

  def allow_challenge(id)
    return false unless auth?

    ch = db.query_single_value('select challenged_id from challenges where id = ?', id)
    me = session[:user][:id]
    ch == me
  end

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

  def update_elo(winner, loser)
    winner_elo = db.query_single_value('select elo from users where id = $1', winner)
    loser_elo = db.query_single_value('select elo from users where id = $1', loser)

    match = EloRating::Match.new

    match.add_player(rating: winner_elo, winner: true)
    match.add_player(rating: loser_elo)

    winner_elo_change = match.updated_ratings[0] - winner_elo
    loser_elo_change = match.updated_ratings[1] - loser_elo

    return unless winner_elo_change && loser_elo_change

    db.query('insert into results (winner, loser, winner_elo_change, loser_elo_change) values ($1, $2, $3, $4)',
             winner,
             loser,
             winner_elo_change,
             loser_elo_change)

    db.query('update users set elo = $1 where id = $2', match.updated_ratings[0], winner)
    db.query('update users set elo = $1 where id = $2', match.updated_ratings[1], loser)
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
