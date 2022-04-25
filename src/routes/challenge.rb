# frozen_string_literal: true

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

# Raderar en utmaning
#
# @param [Integer] id utmaningens id
post '/challenge/:id/delete' do |_id|
  # delete_challenge(id.to_i)
  redirect '/'
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
