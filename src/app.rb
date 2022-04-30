require 'sinatra'
require 'sinatra/reloader' if development?
require 'slim'
require 'sqlite3'

require_relative 'models'
require_relative 'utils'
require_relative 'routes'

configure :development do
  register Sinatra::Reloader
end

include Utils

also_reload('models.rb', 'utils.rb', 'routes.rb', *Dir.glob('routes/*.rb'))

enable :sessions

# Visar framsidan
#
get '/' do
  results = Resultat.senaste(finished: true)
  challenges = current_user ? Challenge.my_challenges(current_user.id).reject(&:nil?) : []

  p challenges

  slim :"application/index", locals: { results: results, challenges: challenges }
end

get '/api/users' do
  User.all.to_json
end
