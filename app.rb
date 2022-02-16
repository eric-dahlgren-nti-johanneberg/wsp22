# frozen_string_literal: true

require 'sinatra'
require 'sinatra/reloader' if development?
require 'extralite'
require 'sqlite3'

require 'sinatra-websocket'

set :server, 'thin'
set :sockets, []

configure :development do
  register Sinatra::Reloader
end

db = Extralite::Database.new 'db/dev.db'

get '/' do
  if !request.websocket?

    scripts = ['socket.js']
    users = db.query('select * from users')
    results = db.query('select ( timestamp ) from results inner join users on results.winner = users.id')

    p results

    slim :index, locals: { scripts: scripts, users: users, results: results }
  else
    request.websocket do |ws|
      ws.onopen do
        ws.send('Hello World!')
        settings.sockets << ws
      end
      ws.onmessage do |msg|
        EM.next_tick { settings.sockets.each { |s| s.send(msg) } }
      end
      ws.onclose do
        warn('websocket closed')
        settings.sockets.delete(ws)
      end
    end
  end
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

  winner_elo_change = 10
  loser_elo_change = -10

  db.query('insert into results (winner, loser, winner_elo_change, loser_elo_change) values ($1, $2, $3, $4)',
           winner,
           loser,
           winner_elo_change,
           loser_elo_change)

  redirect '/'
end
