# frozen_string_literal: true

require 'sinatra'
require 'sinatra/reloader' if development?
require 'extralite'
require 'sqlite3'

require_relative 'elo'
require_relative 'models/achievement'

require 'sinatra-websocket'

set :server, 'thin'
set :sockets, []

configure :development do
  register Sinatra::Reloader
end

db = Extralite::Database.new 'db/dev.sqlite'

get '/' do
  scripts = ['socket.js']

  users = db.query('select * from users order by elo desc')

  results = db.query('select rs.timestamp, winner_elo_change, loser_elo_change, w.username as winner_username, l.username as loser_username from results rs
                        left join users w on rs.winner = w.id
                        left join users l on rs.loser = l.id
                        order by rs.timestamp desc limit 5')

  achievements = db.query('select * from badges')

  slim :index, locals: { scripts: scripts, users: users, results: results, achievements: achievements }
end

def verify_params(params, keys, to)
  keys.each do |key|
    redirect to if params[key] == ''
  end
end

post '/user' do
  verify_params(params, %w[username password], '/')

  db.query('insert into users (pwDigest, username) values($1, $2)', params[:password], params[:username])
  redirect '/'
end

post '/result' do
  winner = params[:winner].to_i
  loser = params[:loser].to_i

  return redirect '/' if winner.nil? || loser.nil?

  winner_elo = db.query_single_value('select elo from users where id = $1', winner)
  loser_elo = db.query_single_value('select elo from users where id = $1', loser)

  match = EloRating::Match.new

  match.add_player(rating: winner_elo, winner: true)
  match.add_player(rating: loser_elo)

  winner_elo_change = match.updated_ratings[0] - winner_elo
  loser_elo_change = match.updated_ratings[1] - loser_elo

  if winner_elo_change && loser_elo_change
    db.query('insert into results (winner, loser, winner_elo_change, loser_elo_change) values ($1, $2, $3, $4)',
             winner,
             loser,
             winner_elo_change,
             loser_elo_change)

    db.query('update users set elo = $1 where id = $2', match.updated_ratings[1], winner)
    db.query('update users set elo = $1 where id = $2', match.updated_ratings[0], loser)

  end

  redirect '/'
end
get '/test' do
  Achievement.init(db)
  ExistAchievement.try_award(1)

  redirect '/'
end
