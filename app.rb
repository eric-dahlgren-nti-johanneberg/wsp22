require 'sinatra'
require 'sinatra/reloader' if development?
require 'extralite'
require 'sqlite3'

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

  def auth?
    !session[:user].nil?
  end
end

get '/' do
  users = fetch_users
  results = fetch_latest_matches
  challenges = fetch_challenges(session[:user]) || []

  slim :"application/index", locals: { users: users, results: results, challenges: challenges }
end

#
#   ----------------------------------------------------------------------------
#                                     Användare
#   ----------------------------------------------------------------------------
#

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
  return redirect '/sign-in' if sign_in_err

  redirect '/'
end

post '/user/new' do
  error = verify_params(params, %w[username password])
  redirect '/sign-in' if error
  return redirect '/sign-in' if user_exists(params[:username])

  add_user(params[:username], params[:password])
  redirect '/'
end

get '/api/users' do
  users = fetch_users
  users.to_json
end

#
#   ----------------------------------------------------------------------------
#                                     Matcher
#   ----------------------------------------------------------------------------
#

get '/challenge/:id' do |id|
  redirect '/sign-in' unless check_auth(session)
  redirect '/' unless check_user(id.to_i)

  @user = fetch_user(id.to_i)

  slim :"matches/challenge"
end

post '/challenge/:id' do |id|
  user = id.to_i
  redirect '/sign-in' unless check_auth(session)
  redirect "/challenge/#{user}" unless params

  move = params[:move]

  create_challenge(session[:user][:id], user, move)

  redirect '/'
end

before '/challenge/:id/accept' do |id|
  redirect '/' unless allow_challenge(id)
end

get '/challenge/:id/accept' do |id|
  @opponent = get_challenge(id)
  
  slim :"matches/challenge"
end

post '/result' do
  winner = params[:winner].to_i
  loser = params[:loser].to_i

  return redirect '/' if winner.nil? || loser.nil?

  update_elo(winner, loser)

  redirect '/'
end

#
#   ----------------------------------------------------------------------------
#                                  Achievements
#   ----------------------------------------------------------------------------
#

get '/test' do
  Achievement.init(db)
  ExistAchievement.try_award(1)

  redirect '/'
end
