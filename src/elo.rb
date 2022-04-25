# frozen_string_literal: true

##
# EloRating helps you calculate Elo ratings.
#
# See the README for an introduction.
module EloRating
  # Default K-factor.
  @k_factor = proc do |_rating|
    24
  end

  # Calls the K-factor function with the provided rating.
  def self.k_factor(rating = nil)
    @k_factor.call(rating)
  end

  # Sets the K-factor by providing a block that optionally takes a +rating+
  # argument:
  #
  #   EloRating::set_k_factor do |rating|
  #     if rating && rating > 2500
  #       24
  #     else
  #       16
  #     end
  #   end
  #
  # Raises an +ArgumentError+ if an exception is encountered when calling the provided block with nil as the argument
  def self.set_k_factor(&k_factor)
    k_factor.call(nil)
    @k_factor = k_factor
  rescue StandardError => e
    raise ArgumentError, "Error encountered in K-factor block when passed nil rating: #{e}"
  end

  # Sets the K-factor to a number.
  def self.k_factor=(k_factor)
    @k_factor = proc do
      k_factor
    end
  end

  # Calculates the expected score of a player given their rating (+player_rating+)
  # and their opponent's rating (+opponent_rating+).
  #
  # Returns a float between 0 and 1 where 0.999 represents high certainty of the
  # first player winning.
  def self.expected_score(player_rating, opponent_rating)
    1.0 / (1 + (10**((opponent_rating - player_rating) / 400.0)))
  end

  # Calculates the amount a player's rating should change.
  #
  # ==== Arguments
  # * +expected_score+: a float between 0 and 1, representing the probability of
  # the player winning
  # * +actual_score+: 0, 0.5, or 1, whether the outcome was a loss, draw, or win
  # (respectively)
  # * +rating+ (optional): the rating of the player, used by the K-factor function
  # * +k_factor+ (optional): the K-factor to use for this calculation to be used
  # instead of the normal K-factor or K-factor function
  #
  # Returns a positive or negative float representing the amount the player's
  # rating should change.
  def self.rating_adjustment(expected_score, actual_score, rating: nil, k_factor: nil)
    k_factor ||= k_factor(rating)
    k_factor * (actual_score - expected_score)
  end
end

class EloRating::Match
  # All the players of the match.
  attr_reader :players

  # Creates a new match with no players.
  def initialize
    @players = []
  end

  # Adds a player to the match
  #
  # ==== Attributes
  # * +rating+: the Elo rating of the player
  # * +winner+ (optional): boolean, whether this player is the winner of the match
  # * +place+ (optional): a number representing the rank of the player within the match; the lower the number, the higher they placed
  #
  # Raises an +ArgumentError+ if the rating or place is not numeric, or if
  # both winner and place is specified.
  def add_player(player_attributes)
    player = Player.new(self, player_attributes[:rating], player_attributes[:place], player_attributes[:winner])
    players << player

    self
  end

  # Calculates the updated ratings for each of the players in the match.
  #
  # Raises an +ArgumentError+ if more than one player is marked as the winner or
  # if some but not all players have +place+ specified.
  def updated_ratings
    validate_players!
    players.map(&:updated_rating)
  end

  private

  def validate_players!
    raise ArgumentError, 'Only one player can be the winner' if multiple_winners?
    raise ArgumentError, 'All players must have places if any do' if inconsistent_places?
  end

  def multiple_winners?
    players.select { |player| player.winner? }.size > 1
  end

  def inconsistent_places?
    players.select { |player| player.place }.any? &&
      players.select { |player| !player.place }.any?
  end

  class Player
    # :nodoc:
    attr_reader :rating, :place, :match

    def initialize(match, rating, place = nil, winner = nil)
      validate_attributes!(rating: rating, place: place, winner: winner)
      @match = match
      @rating = rating
      @place = place
      @winner = winner
    end

    def winner?
      @winner
    end

    def validate_attributes!(rating:, place:, winner:)
      raise ArgumentError, 'Rating must be numeric' unless rating.is_a? Numeric
      raise ArgumentError, 'Winner and place cannot both be specified' if place && winner
      raise ArgumentError, 'Place must be numeric' unless place.nil? || place.is_a?(Numeric)
    end

    def opponents
      match.players - [self]
    end

    def updated_rating
      (rating + total_rating_adjustments).round
    end

    def total_rating_adjustments
      opponents.map do |opponent|
        rating_adjustment_against(opponent)
      end.reduce(0, :+)
    end

    def rating_adjustment_against(opponent)
      EloRating.rating_adjustment(
        expected_score_against(opponent),
        actual_score_against(opponent),
        rating: rating
      )
    end

    def expected_score_against(opponent)
      EloRating.expected_score(rating, opponent.rating)
    end

    def actual_score_against(opponent)
      if won_against?(opponent)
        1
      elsif opponent.won_against?(self)
        0
      else # draw
        0.5
      end
    end

    def won_against?(opponent)
      winner? || placed_ahead_of?(opponent)
    end

    def placed_ahead_of?(opponent)
      place < opponent.place if place && opponent.place
    end
  end
end
