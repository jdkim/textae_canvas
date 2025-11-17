class User < ApplicationRecord
  devise :omniauthable, omniauth_providers: %i[google_oauth2]

  validates :email, presence: true, uniqueness: true
  validates :google_id, presence: true, uniqueness: true

  def self.from_omniauth(auth)
    user = where(email: auth.info.email).first_or_initialize do |u|
      u.email = auth.info.email
      u.google_id = auth.uid
    end

    # Update user info (both on create and on existing record update)
    user.email = auth.info.email
    user.google_id = auth.uid

    # Store OpenID Connect ID token (contained inside credentials)
    if auth.credentials&.id_token
      user.id_token = auth.credentials.id_token
    end

    user.save!
    user
  end

  # Return Google ID token (OpenID Connect)
  def jwt_token
    id_token if id_token.present? && token_valid?
  end

  private

  # Check whether the ID token is valid
  def token_valid?
    return false if id_token.blank?

    begin
      # Attempt to decode JWT (no signature verification; only checks expiration)
      decoded_token = JWT.decode(id_token, nil, false)
      payload = decoded_token.first
      exp = payload['exp'] if payload

      # Valid if current time is before expiration
      exp && Time.now.to_i < exp
    rescue JWT::DecodeError, JWT::ExpiredSignature
      false
    end
  end
end
