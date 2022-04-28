# frozen_string_literal: true

# Visar utmaningssidan
#
# @param [Integer] id den utmanades id
get '/challenge/:id' do |id|
  @opponent = User.find_by_id(id.to_i)
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

  Challenge.skapa(current_user.id, user, move)

  redirect '/'
end

# Visar sidan för att svara på en utmaning
#
# @param [Integer] id utmaningens id
get '/challenge/:id/accept' do |id|
  @opponent = Challenge.find_by_id(id).find { |c| c.user.id != session[:user_id] }
  @action = "/challenge/#{id}/answer"

  slim :"matches/challenge"
end

# Svarar på en utmaning
#
# @param [Integer] id utmaningens id
# @param [String] move spelarens drag
post '/challenge/:id/answer' do |id|
  challenge = Challenge.find_by_id(id.to_i)
  result = Result.find_by_id(challenge.result_id)
  move = params[:move]

  players = [{ id: challenge[:opponent_id], move: challenge[:challenger_move] }, { id: current_user.id, move: move }]
  winner, _loser = determine_winner(players)

  result.status = 1 # klar
  result.winner = winner[:id]

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
