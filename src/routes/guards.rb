# Check för om användare kan tävla
#
before '/challenge/:id' do
  redirect '/sign-in' unless current_user
  # redirect '/' if disabled?(id.to_i) && request.get?
  next unless request.post?

  redirect "/challenge/#{user}" if params[:move].empty?
end

# Hantera inloggnign
before '/user/signin' do
  next unless request.post?

  session[:signup_error] = ''
  session[:attempts] = 0 if Time.new.to_i - session[:last_attempt].to_i > 300
  if session[:attempts] > 5
    session[:signin_error] = 'För många försök. Försök igen senare.'
    return redirect '/sign-in'
  end
end

# hantera registrering
before '/user/signup' do
  next unless request.post?

  session[:signin_error] = ''
end

# hantera radering
before '/user/:id/delete' do |id|
  redirect '/' unless current_user
  redirect '/' unless current_user.admin || id.to_i == current_user.id
end

# Check om användaren har tillgång till utmaningen
#
# @param [Integer] tävlingens användarens id
before '/challenge/:id/*' do
  redirect '/' unless Challenge.can_access?(params[:id].to_i, session[:user_id])
end

# Check om användaren är admin
#
before '/challenge/:id/delete' do
  return redirect '/' unless current_user
  return redirect '/' unless current_user.admin
end

# Check om användaren kan skapa ett resultat
before '/result' do
  return redirect '/' unless current_user
  return redirect '/' unless current_user.admin

  verified_error = verify_params(params, %w[winner loser challenger_move challenged_move]).nil?
  p verified_error
  unless verified_error
    session[:result_error] = 'Alla fält måste fyllas i'
    return redirect '/'
  end
end
