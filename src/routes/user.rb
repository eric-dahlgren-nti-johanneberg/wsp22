# frozen_string_literal: true

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
  if session[:user_id]
    redirect "/user/#{session[:user_id]}"
  else
    redirect '/sign-in'
  end
end

# Visar profilsidan för en användare
#
# @param [Integer] uid användarens id
get '/user/:uid' do |uid|
  @user = User.find_by_id(uid.to_i)
  @user_matches = Resultat.senaste(uid.to_i, finished: true)

  slim :'users/profile'
end

# Loggar in användaren
#
# @param [String] username
# @param [String] password
post '/user/signin' do
  user = User.find_by_username(params[:username])
  if user&.password_matches(params[:password])
    if user.disabled?
      session[:signin_error] = 'Ditt konto är avstängt'
      redirect '/sign-in'
    else
      session[:user_id] = user.id
      session[:attempts] = 0
      session[:signin_error] = ''
      redirect '/'
    end
  else
    session[:attempts] += 1
    session[:last_attempt] = Time.new
    session[:signin_error] = 'Användare eller lösenord är fel'
    return redirect '/sign-in'

  end
end

# Skapar en användare om kriterierna uppfylls
# - Användarnamn och lösenord är ifyllt
# - Användarnamnet är ledigt
#
# @param [String] username
# @param [String] password
post '/user/signup' do
  user_id = User.skapa(params[:username], params[:password])
  session[:user_id] = user_id unless user_id.nil?
  if user_id.nil?
    session[:signup_error] = 'Användaren existerar redan'
    redirect '/sign-in'
  end
end

# Check om användaren är admin
#
before '/user/:id/disable' do
  redirect '/' unless current_user&.admin
end

# Stänger av en användare
#
# @param [Integer] id
# @see Models#disable_user
post '/user/:id/disable' do |id|
  user = User.find_by_id(id.to_i)
  user.disable!
  redirect('/')
end

# Återställer en användare
#
# @param [Integer] id
# @see Models#disable_user
post '/user/:id/enable' do |id|
  user = User.find_by_id(id.to_i)
  user.undisable!
  redirect('/')
end

# Raderar en användare och dess matcher
#
# @param [Integer] id
# @see Models#delete_user
post '/user/:id/delete' do |id|
  user = User.find_by_id(id.to_i)
  user.delete!
  return redirect '/user/signout' if id.to_i == session[:user_id]

  redirect '/'
end
