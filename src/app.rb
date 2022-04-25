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
  results = Resultat.senaste

  slim :"application/index", locals: { results: results, challenges: [] }
end