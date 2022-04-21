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
  p results

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

get '/sign-out' do
  session&.destroy
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
  redirect '/sign-in' unless auth?
  # redirect '/' if disabled?(id.to_i)

  @opponent = fetch_user(id.to_i)
  @action = "/challenge/#{id}"

  slim :"matches/challenge"
end

post '/challenge/:id' do |id|
  user = id.to_i
  redirect '/sign-in' unless auth?
  redirect "/challenge/#{user}" unless params

  move = params[:move]

  create_challenge(session[:user][:id], user, move)

  redirect '/'
end
before '/challenge/:id/*' do
  redirect '/' unless allow_challenge(params[:id])
end

get '/challenge/:id/accept' do |id|
  @opponent = fetch_challenge(id)
  @action = "/challenge/#{id}/answer"

  slim :"matches/challenge"
end

post '/challenge/:id/answer' do |id|
  challenge = fetch_challenge(id.to_i)
  move = params[:move]

  result = [{ id: challenge[:opponent_id], move: challenge[:challenger_move] }, { id: session[:user][:id], move: move }]

  winner, loser = determine_winner(result)

  w, l = play_match(winner[:id], loser[:id])
  end_challenge(id.to_i, move, w, l)

  redirect "/user/#{session[:user][:id]}"
end

post '/result' do
  redirect '/' unless admin?

  winner = params[:winner].to_i
  loser = params[:loser].to_i

  return redirect '/' if winner.nil? || loser.nil?

  result = [{ id: winner, move: params[:challenger_move] }, { id: loser, move: params[:challenged_move] }]
  result = determine_winner(result)

  fake_challenge(result)

  redirect '/'
end

#
#   ----------------------------------------------------------------------------
#                                  Kommentarer
#   ----------------------------------------------------------------------------
#

post '/user/:id/comment' do |id|
end
