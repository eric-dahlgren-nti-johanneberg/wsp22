require 'extralite'
require 'bcrypt'
require_relative 'elo'

# Checkar och verifieringar
#
module Checks
  # Verifierar att valda nycklar inte är tomma
  #
  # @param [Hash<Symbol, String>] params Värdet att testa
  # @param [Array<String>] keys Nycklarna att testa
  #
  # @return [{ key: String, message: String }, nil] Error om fel, nil om inga fel
  def verify_params(params, keys)
    keys.each do |key|
      return { key: key, message: "#{key} is invalid" } if params[key] == '' || params[key].nil?
    end
    nil
  end

  # Check om en användare är inloggad
  #
  # @return [Boolean]
  def auth?
    !session[:user].nil?
  end

  # Check om inloggad användare är admin
  #
  # @return [Boolean]
  def admin?
    return false unless auth?

    user = session[:user][:id]
    db.query_single_value('select admin from users where id = ?', user).positive?
  end

  # Check om inloggad användare har högre rank än en annan användare
  #
  # @param [Hash] user
  # @option user [String] id användarens id
  # @return [Boolean]
  def can_modify(user)
    return false if user.nil? || !auth?

    user_rank = db.query_single_value('select admin from users where id = ?', user[:id])
    me_rank = db.query_single_value('select admin from users where id = ?', session[:user][:id])

    me_rank > user_rank
  end

  # Check om en användare är avstängd
  #
  # @param [Integer] u_id användarens id
  # @return [Boolean]
  def disabled?(u_id)
    disabled = db.query_single_value('select disabled_until from users where id = ?', u_id)
    return false unless disabled.nil? || disabled < '1'

    true
  end

  # Check för att se om en användare finns
  #
  # @param [String] name
  # @return [Boolean]
  def user_exists(name)
    val = !db.query_single_value('select id from users where username = ?', name).nil?
    p val
    val
  end

  # Check för att se om användaren har tillgång till utmaningen
  #
  # @param [Integer] id utmaningens id
  # @return [Boolean]
  def allow_challenge(id)
    return false unless auth?

    ch = db.query_single_value('select challenged_id from challenges where id = ?', id)
    me = session[:user][:id]
    ch == me
  end
end

# Modeller
#
module Models
  # hjälpfunktion för att använda databasen
  #
  # @return [Class] databas
  def db
    @db ||= Extralite::Database.new 'db/dev.sqlite'
  end

  # Enklare sätt att lägga in vyer inuti andra vyer
  #
  # @param [String] name Filens namn
  # @param [String] path Filens mapp, relativt till root
  # @param [Hash] locals Lokala variabler till vyn
  #
  # @return [String] html
  def partial(name, path: '/components', locals: {})
    Slim::Template.new("#{settings.views}#{path}/#{name}.slim").render(self, locals)
  end

  # Hämta en användare från databasen beroende på dess id
  #
  # @param [Integer] uid användarens id
  # @return [Hash] user
  def fetch_user(uid)
    db.query_single_row('select * from users where id = ?', uid)
  end

  # Hämta flera användare från databasen
  #
  # @param [Boolean] disabled hämta även avstängda användare
  # @return [Array<Hash>] användare
  def fetch_users(disabled: false)
    str = 'select * from users order by elo desc'
    # str += " where disabled_until < CURRENT_TIMESTAMP" unless disabled
    db.query(str)
  end

  # Skapar en ny användare
  #
  # @param [String] username
  # @param [String] password
  # @return [void]
  def add_user(username, password)
    pw_hash = BCrypt::Password.create(password)
    db.query('insert into users (pw_hash, username) values($1, $2)', pw_hash, username)

    sign_in(username, password)
  end

  # Loggar in en användare
  #
  # @param [String] username
  # @param [String] password
  # @return [nil]
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

  # Förstör sessionen
  #
  # @return [void]
  def sign_out
    session&.destroy
  end

  # Stänger av en användare 1 vecka
  #
  # @param [Integer] id
  # @return [void]
  def disable_user_1_week(id)
    return unless admin?

    db.query("update users set disabled = date('now', '+1 week') where id = ?", id)
  end

  # Skapar en utmaning
  #
  # @param [Integer] challenger
  # @param [Integer] challenged
  # @param [String] move
  # @return [void]
  def create_challenge(challenger, challenged, move)
    db.query('insert into challenges (challenger_id, challenged_id, challenger_move) values (?, ?, ?)', challenger, challenged, move)
  end

  # Hämtar alla utmaningar för en viss användare
  #
  # @param [Hash] user
  # @return [Array<Hash>]
  def fetch_challenges(user)
    return [] unless user && user[:id]

    db.query('select u.username, u.id as opponent_id, c.id as challenge_id from challenges c left join users u on c.challenger_id = u.id where challenged_id = ? and done = 0', user[:id])
  end

  # Hämtar en specifik utmaning
  #
  # @param [Integer] id utmaningens id
  # @return [Hash] utmaningen
  def fetch_challenge(id)
    db.query_single_row('select u.username, u.id as opponent_id, c.challenger_move from challenges c left join users u on c.challenger_id = u.id where c.id = ?', id)
  end

  # Hämtar senaste matcherna, om en användare är angiven hämtas bara dens matcher
  #
  # @param [Integer, nil] user
  # @return [Array<Hash>]
  def fetch_latest_matches(user = nil)
    query_str = "select rs.id, rs.timestamp, challenged_elo_change, challenger_elo_change,
                  w.username as challenged_username, l.username as challenger_username,
                  challenged_id, challenger_id,
                  challenger_move, challenged_move
                  from challenges rs
                  left join users w on rs.challenged_id = w.id
                  left join users l on rs.challenger_id = l.id
                  where done = 1"

    query_str += ' and (l.id = $1 or w.id = $1)' unless user.nil?

    db.query("#{query_str} order by rs.timestamp desc limit 5", user)
  end

  # Bestämmer vinnaren av en match
  #
  # @param [Array<Hash>] players Spelarna och deras drag
  # @return [Array<Hash>] Samma array, men vinnaren är på index 0
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

  # Avslutar en utmaning i databasen
  #
  # @param [Integer] id
  # @param [String] move
  # @param [Integer] winner_elo_change
  # @param [Integer] loser_elo_change
  def end_challenge(id, move, winner_elo_change, loser_elo_change)
    db.query('update challenges set challenged_move = $4, challenged_elo_change = $2, challenger_elo_change = $3, timestamp = CURRENT_TIMESTAMP where id = $1',
             id,
             winner_elo_change,
             loser_elo_change,
             move)
  end

  # Uppdaterar spelarnas elo-rankning i databasen
  #
  # @param [Integer] winner
  # @param [Integer] loser
  # @return [Array<Integer>] spelarnas elo-förändring
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

  # Lägger till ett resultat utan att någon spelare blir utmanad
  #
  # @param [Array<Hash>] result det önskade resultatet
  # @return [void]
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

  # Omvandlar ett drag till svenska
  #
  # @param ['rock', 'paper', 'scissors'] move
  # @return ['Sten', 'Papper', 'Påse']
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
