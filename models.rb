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
    db.query('insert into challenges (challenger_id, challenged_id, challenger_move) values (?, ?, ?)', challenger, challenged, move)
  end

  def fetch_challenges(user)
    return nil unless user
    return nil unless user[:id]

    db.query('select u.username, u.id as opponent_id, c.id as challenge_id from challenges c left join users u on c.challenger_id = u.id where challenged_id = ? and done = 0', user[:id])
  end

  def fetch_challenge(id)
    db.query_single_row('select u.username, u.id as opponent_id, c.challenger_move from challenges c left join users u on c.challenger_id = u.id where c.id = ?', id)
  end

  def allow_challenge(id)
    return false unless auth?

    ch = db.query_single_value('select challenged_id from challenges where id = ?', id)
    me = session[:user][:id]
    ch == me
  end

  def fetch_latest_matches
    db.query('select

              rs.timestamp, challenged_elo_change, challenger_elo_change,
              w.username as challenged_username, l.username as challenger_username,
              challenged_id, challenger_id,
              challenger_move, challenged_move

              from challenges rs
              left join users w on rs.challenged_id = w.id
              left join users l on rs.challenger_id = l.id

              where done = 1
              order by rs.timestamp desc limit 5')
  end

  def fetch_users_latest_matches(uid)
    db.query('select
              rs.timestamp, challenged_elo_change, challenger_elo_change,
              w.username as challenged_username, l.username as challenger_username,
              challenged_id, challenger_id,
              challenger_move, challenged_move

              from challenges rs
              left join users w on rs.challenged_id = w.id
              left join users l on rs.challenger_id = l.id

              where done = 1 or l.id = $1 or w.id = $1
              order by rs.timestamp desc limit 5', uid)
  end

  def determine_winner(players)
    winning_moves = { rock: 'paper', paper: 'scissor', scissor: 'rock' }

    if winning_moves[:"#{players[0][:move]}"] == players[1][:move]
      # spelare 2 vann
      [{ id: players[1][:id], move: players[1][:move] }, { id: players[0][:id], move: players[0][:move] }]
    else
      # spelare 1 vann
      [{ id: players[0][:id], move: players[0][:move] }, { id: players[1][:id], move: players[1][:move] }]

    end
  end

  def end_challenge(id, move, winner_elo_change, loser_elo_change)
    db.query('update challenges set challenged_move = $4, challenged_elo_change = $2, challenger_elo_change = $3, timestamp = CURRENT_TIMESTAMP where id = $1',
             id,
             winner_elo_change,
             loser_elo_change,
             move)
  end

  def play_match(winner, loser)
    winner_elo = db.query_single_value('select elo from users where id = $1', winner)
    loser_elo = db.query_single_value('select elo from users where id = $1', loser)

    match = EloRating::Match.new

    match.add_player(rating: winner_elo, winner: true)
    match.add_player(rating: loser_elo)

    winner_elo_change = match.updated_ratings[0] - winner_elo
    loser_elo_change = match.updated_ratings[1] - loser_elo

    db.query('update users set elo = $1 where id = $2', match.updated_ratings[0], winner)
    db.query('update users set elo = $1 where id = $2', match.updated_ratings[1], loser)

    [winner_elo_change, loser_elo_change]
  end

  def fake_challenge(result)
    winner, loser = play_match(result[0][:id], result[1][:id])

    db.query('insert into challenges
              (challenger_id,
              challenged_id,
              challenged_move,
              challenger_move,
              challenged_elo_change,
              challenger_elo_change,
              done)
              values (?, ?, ?, ?, ?, ?, 1)
              ',
             result[0][:id],
             result[1][:id],
             result[0][:move],
             result[1][:move],
             winner,
             loser)
  end

  #
  #
  # ----- Achievements -----
  #
  #

  def fetch_avalible_achievements
    db.query('select * from badges')
  end

  #
  #
  # ----- Annat -----
  #
  #

  def move_to_sv(move)
    case move
    when 'rock'
      'Sten'
    when 'scissors'
      'Sax'
    when 'paper'
      'Påse'
    end
  end
end
