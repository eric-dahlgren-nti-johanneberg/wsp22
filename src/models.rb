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
    @id = data['id']
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
    data = db.query("SELECT * FROM #{table_name} WHERE id = ?", id).first
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
    @disabled = data[:disabled]
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

  def self.leaderboard
    db.query("select * from #{table_name} order by elo desc")
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
      `timestamp`			TEXT DEFAULT CURRENT_TIMESTAMP
    )")
  end

  def initialize(data)
    super(data)
    @status = data[:status]
    @elo_change = data[:elo_change]
    @timestamp = Time.at(data[:timestamp])
    @players = Challenge.find_by_result_id(data[:id])
  end

  # Skapar ett resultat, effektivt en match
  # @param [Integer] elo_diff
  # @return [Integer] row_id
  def self.skapa(elo_diff)
    transaction = db
    transaction.query("INSERT INTO #{table_name} (elo_change) values(?)", elo_diff)
    transaction.last_insert_rowid
  end

  # Hämtar senaste resultaten
  def self.senaste(user = nil)
    query = "select * from #{table_name} r left join #{Challenge.table_name} c on r.id = c.result_id"
    query += ' where user_id = $1' if user
    db.query("#{query} order by r.timestamp")
  end
end

# Entiteten Challenge
class Challenge < Entitet
  attr_reader :user, :move, :active

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
      FOREIGN KEY(`user_id`) REFERENCES `#{User.table_name}`(`id`),
      FOREIGN KEY(`result_id`) REFERENCES `#{Resultat.table_name}`(`id`)
      )")
  end

  def initialize(data)
    super(data)
    @user = User.find_by_id(data[:user_id])
    @move = data[:move]
    @active = data[:move].nil?
  end

  # @param [Integer] challenger_id
  # @param [Integer] opponent_id
  # @param [String] move
  def self.skapa(challenger_id, opponent_id, move)
    challenger_elo = User.find_by_id(challenger_id)[:elo]
    opponent_elo = User.find_by_id(opponent_id)[:elo]

    diff = Utils.calculate_elo_change(challenger_elo, opponent_elo)

    resultat_id = Resultat.skapa(diff)
    add_user(resultat_id, challenger_id, move)
    add_user(resultat_id, opponent_id, nil)
  end

  # @param [Integer] result_id
  # @return [Array<Challenge>]
  def self.find_by_result_id(result_id)
    db.query("SELECT * FROM #{table_name} WHERE result_id = ?", result_id).map do |data|
      new(data)
    end
  end
end

User.create_table
Resultat.create_table
Challenge.create_table
