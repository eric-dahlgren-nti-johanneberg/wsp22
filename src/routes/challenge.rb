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
  challenge = Challenge.find_by_id(id.to_i)
  result = challenge.result

  p challenge

  @opponent = result.players.find { |u| u.hash[:user_id] != session[:user_id] }.user
  @action = "/challenge/#{id}/answer"

  slim :"matches/challenge"
end

# Svarar på en utmaning
#
# @param [Integer] id utmaningens id
# @param [String] move spelarens drag
post '/challenge/:id/answer' do |id|
  challenge = Challenge.find_by_id(id.to_i)
  result = challenge.result
  p challenge.user.username

  challenge = Challenge.find_by_result_id_and_user(result.id, session[:user_id])
  result = challenge.result

  move = params[:move]

  p challenge.user.username

  challenge.update_move(move, session[:user_id])

  me = { move: move, id: session[:user_id] }
  opponent = result.players.find { |u| u.id != session[:user_id] }
  return redirect "/user/#{session[:user_id]}" if move == opponent.move

  players = [me, { id: opponent.hash[:id], move: opponent.move }]
  winner, _loser = determine_winner(players)

  result.winner = winner[:id]

  result.status = 1
  redirect "/user/#{session[:user_id]}"
end

# Raderar en utmaning
#
# @param [Integer] id utmaningens id
post '/challenge/:id/delete' do |id|
  result = Resultat.find_by_id(id.to_i)
  result.delete!
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

  challenge_id, resultat_id = Challenge.skapa(winner, loser, params[:challenger_move])

  players = [{ id: winner, move: params[:challenger_move] }, { id: loser, move: params[:challenged_move] }]
  winner, _loser = determine_winner(players)

  challenge = Challenge.find_by_id(challenge_id)
  resultat = Resultat.find_by_id(resultat_id)

  challenge.update_move(params[:challenged_move], loser)
  resultat.winner = winner[:id]

  resultat.status = 1

  redirect '/'
end
