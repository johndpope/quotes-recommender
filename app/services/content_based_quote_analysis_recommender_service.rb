# app/services/content_based_binary_recommender_service.rb
class ContentBasedQuoteAnalysisRecommenderService < RecommenderService
  def initialize(params)
    super(params)
  end

  # Recommendation based on number of words and length of words of quote.
  #
  # User profile for these attributes is computed in RatingsController
  #
  # Build score board of all quotes based on these attributes.
  # Score of quote is determined separately for quote length (number of words) and average quote word lenght
  #
  # score for quote length = user_preference_for_quote_length * log_10(number_of_quotes/ number_of_quotes_of_this_length)
  # score for avg word length = user_preference_for_quote_length * log_10(number_of_quotes/ number_of_quotes_of_this_length)
  #
  # In final decision, user preferenco for both parameters are taken with same weight.
  # If we don't have user preference profile, we return random unseen quote
  def recommend_next
    # quote.id -> expectation on how much user likes this quote
    score_board_quote_length = {}
    score_board_word_length = {}

    # all quotes
    all_quotes = Quote.all.pluck(:id)

    # ids of all quotes current user has already seen
    user_viewed_quotes = @user.viewed_quotes.pluck(:quote_id)

    # quote_id => quote length
    quote_length = Quote.all.pluck(:id, :length).to_h

    # quote_id => quote word avg legth
    quote_word_length = Quote.all.pluck(:id, :word_avg_length).to_h

    # length -> users preference for given length
    user_preferred_quote_lengths = UserQuoteLengthPreference.where(user_id: @user.id)
                                       .pluck(:length, :preference).to_h

    # length -> number quotes of given length
    quotes_by_quote_length = Quote.group(:length).count

    # word_avg_length -> users preference for given word_avg_length
    user_preferred_word_lengths = UserWordLengthPreference.where(user_id: @user.id)
                                      .pluck(:length, :preference)
                                      .to_h
    # word_avg_length -> number quotes of given length
    quotes_by_word_avg_length = Quote.group(:word_avg_length).count

    (all_quotes - user_viewed_quotes).each do |quote_id|

      # quote length
      score_board_quote_length[quote_id] = 0 if score_board_quote_length[quote_id].nil?
      # sum of preference * IDF for both quote length
      score_board_quote_length[quote_id] += user_preferred_quote_lengths.fetch(quote_length[quote_id], 0) *
          Math.log10(all_quotes.size / quotes_by_quote_length[quote_length[quote_id]])

      # quote word average length
      score_board_word_length[quote_id] = 0 if score_board_word_length[quote_id].nil?
      # sum of preference * IDF for both quote word average length
      score_board_word_length[quote_id] += user_preferred_word_lengths.fetch(quote_word_length[quote_id], 0) *
          Math.log10(all_quotes.size / quotes_by_word_avg_length[quote_word_length[quote_id]])

    end

    normalize score_board_word_length
    normalize score_board_quote_length

    merged_score_board = score_board_quote_length.merge(score_board_word_length) {|quote, val1, val2| val1 + val2}
    final_score_board = merged_score_board.sort_by {|key, value| value}.reverse.to_h


    # choose the best quote to display
    best_quote_id = unless final_score_board.empty?
                   final_score_board.keys[0]
                 end

    # if we dont know users preference, return random unseen quote
    # this happens when there is no quote rating or no unseen quote
    if best_quote_id.nil?
      # Consider all quotes as unseen quotes if the user has already viewed all quotes
      unseen_quotes = (all_quotes - user_viewed_quotes).empty? ? all_quotes : (all_quotes - user_viewed_quotes)
      Quote.find unseen_quotes.sample
    else
      # return best result
      Quote.find best_quote_id
    end
  end


  private

  # All scores normalized to value (0,1)
  def normalize(score_board)
    max = score_board.values.max
    min = score_board.values.min

    score_board.each do |key, value|
      score_board[key] = (value - min) / (max - min)
    end
  end
end
