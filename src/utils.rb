# Datahanteringsmetoder
#
module Utils
  # Hämtar nuvarande användare
  # @return [User]
  # @return [false] om ingen användare
  def current_user
    User.find_by_id(session[:user_id]) || false
  end

  # @param [String] component
  # @param [String] folder
  # @param [Hash] locals
  def partial(component, folder = '/components', locals: {})
    slim :"#{folder}/#{component}", locals: locals
  end

  # Bestämmer vinnaren av en match
  #
  # @param [Array<Hash>] players Spelarna och deras drag
  # @return [Array<Hash>] Samma array, men vinnaren är på index 0
  def determine_winner(players)
    winning_moves = { rock: 'paper', paper: 'scissor', scissor: 'rock' }

    if winning_moves[:"#{players[0][:move]}"] == players[1][:move]
      # spelare 2 vann
      [{ id: players[1][:id], move: players[1][:move] }, { id: players[0][:id], move: players[0][:move] }]
    else
      # spelare 1 vann
      [{ id: players[0][:id], move: players[0][:move] }, { id: players[1][:id], move: players[1][:move] }]

    end
  end

  # Beräknar vad spelare kommer vinna och förlora
  #
  # @param [Integer] player1 ELO för spelare 1
  # @param [Integer] player2 ELO för spelare 2
  # @return [Integer] elo
  def self.calculate_elo_change(player1, player2)
    match = EloRating::Match.new

    match.add_player(rating: player1, winner: true)
    match.add_player(rating: player2)

    match.updated_ratings[0] - player1
  end

  # Omvandlar ett drag till svenska
  #
  # @param ['rock', 'paper', 'scissors'] move
  # @return ['Sten', 'Papper', 'Påse']
  def move_to_sv(move)
    case move
    when 'rock'
      'Sten'
    when 'scissors'
      'Sax'
    when 'paper'
      'Påse'
    end
  end

  # Verifierar att alla nycklar i ett objekt har värden
  #
  # @param [Hash<String, String>] params
  # @param [Array<String>] keys
  def verify_params(params, keys)
    keys.each do |key|
      return { key: key, message: "#{key} is invalid" } if params[key] == ''
    end
    nil
  end
end
