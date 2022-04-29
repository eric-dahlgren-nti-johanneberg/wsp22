require 'extralite'
require 'bcrypt'
require_relative 'elo'
require_relative 'utils'

# hjälpfunktion för att använda databasen
#
# @return [Extralite::Database] databas
def db
  db = Extralite::Database.new File.join(File.dirname(__FILE__), './data.db')
  # Så att foreign keys fungerar
  db.query('PRAGMA foreign_keys = true')
  db
end

# Abstrakt klass för tabeller
class Entitet
  # @return [Integer]
  attr_reader :id

  # @return [Hash<String, String>]
  attr_reader :hash

  def self.table_name; end

  def self.create_table; end

  def table_name
    self.class.table_name
  end

  def initialize(data)
    @hash = data
    @id = data[:id]
  end

  def ==(other)
    return false if other.nil?
    return @id == other if other.is_a?(Numeric)

    @id == other.id
  end

  # Hämtar ett objekt beroende på id
  # @param [Integer] id
  # @return [Hash<String, String>]
  def self.find_by_id(id)
    data = db.query("SELECT * FROM #{table_name} WHERE id = $1", id).first
    data && new(data)
  end
end

# Användarens databasmodell
#
class User < Entitet
  attr_reader :username, :admin, :elo, :pw_hash, :disabled, :id

  def self.table_name
    'users'
  end

  def self.create_table
    db.query("CREATE TABLE `#{table_name}` (
      `id`			    integer PRIMARY KEY,
      `username`		text UNIQUE,
      `admin`			  integer DEFAULT 0,
      `elo`		    	integer DEFAULT 1500,
      `pw_hash`		  text NOT NULL,
      `disabled`		integer NOT NULL DEFAULT 0
    )")
  end

  def initialize(data)
    super(data)
    @id = data[:id]
    @username = data[:username]
    @admin = data[:admin].positive?
    @elo = data[:elo]
    @pw_hash = BCrypt::Password.new(data[:pw_hash])
    @disabled = data[:disabled].positive?
  end

  # alias för @disabled
  # return [Boolean]
  def disabled?
    @disabled
  end

  # Skapar en användare
  #
  # @param [String] username
  # @param [String] pws password
  # @return [Integer, nil]
  def self.skapa(username, pwd)
    database = db

    hash = BCrypt::Password.create(pwd)
    return nil unless database.query("SELECT * FROM #{table_name} WHERE username = ?", username).empty?

    database.query("insert into #{table_name}
      (username, pw_hash) values(?, ?)", username, hash)
    database.last_insert_rowid
  end

  # Hittar en användare på dess användarnamn
  #
  # @param [String] username
  # @return [nil, User]
  def self.find_by_username(username)
    return nil if username.empty?

    data = db.query_single_row("SELECT * FROM #{table_name} WHERE username = ?", username)
    data && new(data)
  end

  # Kollar om lösenordet är korrekt
  #
  # @param [Integer] password
  # @return [Boolean]
  def password_matches(password)
    @pw_hash == password
  end

  # Hämtar de 10 högst rankade användare
  #
  # @return [Array<User>]
  def self.leaderboard
    db.query("select * from #{table_name} where disabled = 0 order by elo desc limit 10").map do |data|
      new(data)
    end
  end

  def self.all
    db.query('select * from users where disabled = 0')
  end

  # @param [Boolean] value is admin?
  def admin=(value)
    db.query("update #{table_name} set admin = ?", value ? 1 : 0)
  end

  # Stänger av användaren
  def disable!
    db.query("update #{table_name} set disabled = 1 where id = ?", @id)
  end

  # Tar bort avstängning för användaren
  def undisable!
    db.query("update #{table_name} set disabled = 0 where id = ?", @id)
  end

  # raderar användaren
  def delete!
    db.query("delete from #{table_name} where id = ?", @id)
  end

  # ändrar elo-värdet
  # @param [Integer] elo_change
  def update_elo(elo_change)
    new_elo = @elo + elo_change
    db.query('update users set elo = ? where id = ?', new_elo, @id)
  end
end

# Alla resultat
#
class Resultat < Entitet
  attr_reader :status, :elo_change, :timestamp, :players

  def self.table_name
    'results'
  end

  def self.create_table
    db.query("CREATE TABLE `#{table_name}` (
      `id`				    INTEGER PRIMARY KEY,
      `status`		  	INTEGER DEFAULT 0,
      `elo_change`		INTEGER NOT NULL DEFAULT 0,
      `timestamp`			TEXT DEFAULT CURRENT_TIMESTAMP,
      `challenger_id` INTEGER
    )")
  end

  def initialize(data)
    super(data)
    @status = data[:status]
    @elo_change = data[:elo_change]
    @timestamp = (data[:timestamp])
    @players = Challenge.find_by_result_id(data[:id])
  end

  # Skapar ett resultat, effektivt en match
  # @param [Integer] challenger_id
  # @param [Integer] elo_diff
  # @return [Integer] row_id
  def self.skapa(elo_diff, challenger_id)
    transaction = db
    transaction.query("INSERT INTO #{table_name} (elo_change, challenger_id) values(?, ?)", elo_diff, challenger_id)
    transaction.last_insert_rowid
  end

  # Hämtar senaste resultaten
  # @param [nil, String] user
  # @param [Boolean] :finished
  # @param [Boolean] :to from user
  # @param [Boolean] :from to user
  def self.senaste(user = nil, finished: true, to: true, from: true)
    base_query = 'select distinct r.* from challenges left join results r on result_id = r.id'

    unless to && from
      send_or_recieve = 'and user_id <> challenger_id' if to
      send_or_recieve = 'and user_id == challenger_id' if from
    end

    conditions = "where status = #{finished ? 1 : 0} #{send_or_recieve} #{user.nil? ? '' : 'and user_id = ?'}"

    query = "#{base_query} #{conditions} order by timestamp desc limit 10"
    db.query(query, user).map do |res|
      Resultat.find_by_id(res[:id])
    end
  end

  # @param [Integer] value 0 eller 1, väntar eller klar.
  def status=(value)
    if value == 1
      @players.each do |player|
        player.user.update_elo(player.win ? @elo_change : -@elo_change)
      end

    end

    db.query("update #{table_name} set status = ? where id = ?", value, @hash[:id])
  end

  # @param [Integer] user_id
  def winner=(user_id)
    db.query("update #{Challenge.table_name} set win = 1 where result_id = ? and user_id = ?", @hash[:id], user_id)
    @players = Challenge.find_by_result_id(@id)
  end

  # @return [User]
  def winner
    @players.find { |player| player.win == 1 }
  end

  # @return [User]
  def loser
    @players.find { |player| player.win.zero? }
  end

  # Raderar ett resultat
  def delete!
    db.query("delete from #{Challenge.table_name} where result_id = ?", @id)
    db.query("delete from #{table_name} where id = ?", @id)
  end
end

# Entiteten Challenge
class Challenge < Entitet
  attr_reader :user, :move, :active, :win

  def self.table_name
    'challenges'
  end

  def self.create_table
    db.query("CREATE TABLE #{table_name} (
      `id`                INTEGER PRIMARY KEY AUTOINCREMENT,
      `user_id`           INTEGER,
      `result_id`         INTEGER,
      `move`              TEXT,
      `win`               INTEGER,
      FOREIGN KEY(`user_id`) REFERENCES `#{User.table_name}`(`id`) ON DELETE SET NULL,
      FOREIGN KEY(`result_id`) REFERENCES `#{Resultat.table_name}`(`id`)
      )")
  end

  def initialize(data)
    super(data)

    @id = data[:id]
    @user = User.find_by_id(data[:user_id])
    @move = data[:move]
    @active = data[:move].nil?
    @win = data[:win] == 1
  end

  # @param [Integer] result_id
  # @param [Integer] user_id
  # @return [User]
  def self.get_opponent(result_id, user_id)
    opponent_id = db.query("select user_id from #{Challenge.table_name} where result_id = ? and user_id <> ?", result_id, user_id)
    User.find_by_id(opponent_id)
  end

  # @param [Integer] challenger_id from user
  # @param [Integer] opponent_id to user
  # @param [String] move
  # @return [Integer] resultatets id
  def self.skapa(challenger_id, opponent_id, move)
    challenger_elo = User.find_by_id(challenger_id).elo
    opponent_elo = User.find_by_id(opponent_id).elo

    diff = Utils.calculate_elo_change(challenger_elo, opponent_elo)

    resultat_id = Resultat.skapa(diff, challenger_id)
    add_user(resultat_id, challenger_id, move)
    challenge_id = add_user(resultat_id, opponent_id, nil)

    [challenge_id, resultat_id]
  end

  def result
    data = db.query_single_row("select * from #{Resultat.table_name} where id = ?", @hash[:result_id])
    data && Resultat.new(data)
  end

  # @param [Integer] result_id
  # @return [Array<Challenge>]
  def self.find_by_result_id(result_id, active: true)
    query = "SELECT * FROM #{table_name} WHERE result_id = ?"
    query += 'AND MOVE IS NOT NULL' if active
    db.query(query, result_id).map do |data|
      new(data)
    end
  end

  # @param [Integer] user_id
  # @return [Array<Challenge>]
  def self.find_by_user(user_id)
    db.query("select * from #{table_name} where user_id = ?", user_id).map do |data|
      new(data)
    end
  end

  # @param [Integer] resultat_id
  # @param [Integer] player_id
  # @param [String] move
  # @return [Integer] challenge id
  def self.add_user(resultat_id, player_id, move)
    sess = db
    sess.query('insert into challenges (result_id, user_id, move) values(?, ?, ?)', resultat_id, player_id, move)
    sess.last_insert_rowid
  end

  # @param [Integer] result_id
  # @param [Integer] user_id
  # @return [Boolean]
  def self.can_access?(result_id, user_id)
    count = db.query_single_value("select COUNT(id) from #{table_name} where result_id = ? and user_id = ?", result_id, user_id)
    count.positive?
  end

  # @param [String] values
  def update_move(value, user_id)
    @move = value
    db.query('update challenges set move = ? where user_id = ? and result_id = ?', value, user_id, @hash[:result_id])
  end

  def self.find_by_result_id_and_user(result_id, user_id)
    data = db.query_single_row('select * from challenges where result_id = ? and user_id = ?', result_id, user_id)
    data && new(data)
  end
end

User.create_table
Resultat.create_table
Challenge.create_table

eric = User.skapa('eric', 'test')
User.find_by_id(eric).admin = true
johnny = User.skapa('johnny', 'test')
User.skapa('admin', 'password')

# från eric till johnny
Challenge.skapa(eric, johnny, 'rock')
# tvärtom
Challenge.skapa(johnny, eric, 'rock')
