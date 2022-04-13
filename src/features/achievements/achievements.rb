# frozen_string_literal: true

# Base achievement class
class Achievement
  def self.init(daatbase)
    @@db = daatbase
  end

  def self.try_award(_user)
    raise 'Not implemented'
  end

  def self.progress(_user)
    raise 0
  end

  def self.allow?(user, achievement)
    row = @@db.query_single_row('select * from badges_users where bd_id = $1 and user_id = $2', achievement, user)
    row.nil?
  end
end

###
# Account exists
class ExistAchievement < Achievement
  @id = 1

  def self.try_award(user)
    if Achievement.allow?(user, @id)
      u = @@db.query('select * from users where id = $1', user)
      p u
      @@db.query('insert into badges_users (bd_id, user_id) values($1, $2)', @id, user) unless u.nil?
    end
    true
  end
end
