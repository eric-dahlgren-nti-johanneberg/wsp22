# frozen_string_literal: true

require 'sinatra'
require 'sinatra/reloader' if development?

configure :development do
  register Sinatra::Reloader
end

get '/' do
  'hello there    '
end
