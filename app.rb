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
include Checks

# Visar framsidan
#
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

# Visar inloggningssidan
#
get '/sign-in' do
  slim :"users/sign-in"
end

# Loggar ut en användare
#
get '/user/signout' do
  session&.destroy
  redirect '/'
end

# Omdirigerar till användaren eller inlogg
#
get '/user' do
  if session[:user]
    redirect "/user/#{session[:user][:id]}"
  else
    redirect '/sign-in'
  end
end

# Visar profilsidan för en användare
#
# @param [Integer] uid användarens id
get '/user/:uid' do |uid|
  @user = fetch_user(uid.to_i)
  @user_matches = fetch_latest_matches(uid.to_i)
  slim :'users/profile'
end

# Loggar in användaren
#
# @param [String] username
# @param [String] password
post '/user/signin' do
  error = verify_params(params, %w[username password])
  return redirect '/sign-in' if error

  sign_in_err = sign_in(params[:username], params[:password])
  return redirect '/sign-in' if sign_in_err

  redirect '/'
end

before '/users/new' do
  error = verify_params(params, %w[username password])
  if error
    session[:signup_error] = 'Användare eller lösenord saknas'
    redirect '/sign-in' if error
  end
  if user_exists(params[:username])
    session[:signup_error] = 'Användarnamnet används redan'
    return redirect '/sign-in'
  end
end

# Skapar en användare om kriterierna uppfylls
# - Användarnamn och lösenord är ifyllt
# - Användarnamnet är ledigt
#
# @param [String] username
# @param [String] password
post '/user/new' do
  session[:signup_error] = ''
  add_user(params[:username], params[:password])
  redirect '/'
end

# Returnerar alla användare som json
#
get '/api/users' do
  users = fetch_users
  users.to_json
end

# Check för om användare kan tävla
#
before '/challenge/:id' do
  redirect '/sign-in' unless auth?
  # redirect '/' if disabled?(id.to_i) && request.get?
  next unless request.post?

  redirect "/challenge/#{user}" unless params
end

# Visar utmaningssidan
#
# @param [Integer] id den utmanades id
get '/challenge/:id' do |id|
  @opponent = fetch_user(id.to_i)
  @action = "/challenge/#{id}"

  slim :"matches/challenge"
end

# Skapar en utmaning
#
# @param [Integer] id den utmanades id
# @param [String] move
post '/challenge/:id' do |id|
  user = id.to_i
  move = params[:move]

  create_challenge(session[:user][:id], user, move)

  redirect '/'
end

# Check om användaren har tillgång till utmaningen
#
# @param [Integer] tävlingens användarens id
before '/challenge/:id/*' do
  redirect '/' unless allow_challenge(params[:id])
end

# Visar sidan för att svara på en utmaning
#
# @param [Integer] id utmaningens id
get '/challenge/:id/accept' do |id|
  @opponent = fetch_challenge(id)
  @action = "/challenge/#{id}/answer"

  slim :"matches/challenge"
end

# Svarar på en utmaning
#
# @param [Integer] id utmaningens id
# @param [String] move spelarens drag
post '/challenge/:id/answer' do |id|
  challenge = fetch_challenge(id.to_i)
  move = params[:move]

  result = [{ id: challenge[:opponent_id], move: challenge[:challenger_move] }, { id: session[:user][:id], move: move }]

  winner, loser = determine_winner(result)

  w, l = play_match(winner[:id], loser[:id])
  end_challenge(id.to_i, move, w, l)

  redirect "/user/#{session[:user][:id]}"
end

# Check om användaren är admin
#
before '/challenge/:id/delete' do
  redirect '/' unless admin?
end

# Raderar en utmaning
#
# @param [Integer] id utmaningens id
post '/challenge/:id/delete' do |_id|
  # delete_challenge(id.to_i)
  redirect '/'
end

# Check om användaren kan skapa ett resultat
before '/result' do
  redirect '/sign-in' unless admin?
  verified_error = verify_params(params, %w[winner loser challenger_move challenged_move]).nil?
  unless verified_error.nil?
    session[:result_error] = 'Alla fält måste fyllas i'
    redirect '/'
  end
end

# skapar ett resultat
#
# @param [Integer] winner spelare 1 ID
# @param [Integer] loser spelare 2 ID
# @param [String] challenger_move spelare 1 drag
# @param [String] challenged_move spelare 3 drag
post '/result' do
  winner = params[:winner].to_i
  loser = params[:loser].to_i

  session[:result_error] = ''

  players = [{ id: winner, move: params[:challenger_move] }, { id: loser, move: params[:challenged_move] }]
  result = determine_winner(players)

  fake_challenge(result)

  redirect '/'
end
