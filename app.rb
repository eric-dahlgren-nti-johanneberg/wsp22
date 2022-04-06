require 'sinatra'
require 'sinatra/reloader' if development?
require 'extralite'
require 'sqlite3'

require_relative 'elo'
require_relative 'models'

configure :development do
  register Sinatra::Reloader
end

enable :sessions

include Models # Wat dis?
helpers do
  def partial(name, path: '/components', locals: {})
    Slim::Template.new("#{settings.views}#{path}/#{name}.slim").render(self, locals)
  end
end

get '/' do
  users = fetch_users
  results = fetch_latest_matches

  slim :"application/index", locals: { users: users, results: results }
end

def verify_params(params, keys)
  keys.each do |key|
    return { key: key, message: "#{key} is invalid" } if params[key] == ''
  end
  return nil
end

get '/sign-in' do
  slim :"users/sign-in"
end

get '/user/:uid' do |uid|
  @user = fetch_user(uid.to_i)
  @user_matches = fetch_users_latest_matches(uid.to_i)
  slim :'users/profile'
end

post '/user/signin' do
  error = verify_params(params, %w[username password])
  return redirect '/sign-in' if error
  
  sign_in_err = sign_in(params[:username], params[:password])
  p sign_in_err
  return redirect '/sign-in' if sign_in_err

  redirect '/'
end

post '/user/new' do
  error = verify_params(params, %w[username password])
  redirect '/sign-in' if error

  add_user(params[:username], params[:password])
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

    db.query('update users set elo = $1 where id = $2', match.updated_ratings[0], winner)
    db.query('update users set elo = $1 where id = $2', match.updated_ratings[1], loser)

  end

  redirect '/'
end
get '/test' do
  Achievement.init(db)
  ExistAchievement.try_award(1)

  redirect '/'
end
