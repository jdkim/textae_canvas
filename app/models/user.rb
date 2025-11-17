class User < ApplicationRecord
  devise :omniauthable, omniauth_providers: %i[google_oauth2]

  validates :email, presence: true, uniqueness: true
  validates :google_id, presence: true, uniqueness: true

  def self.from_omniauth(auth)
    user = find_by(email: auth.info.email)

    if user
      # Update existing user
      user.email = auth.info.email
      user.google_id = auth.uid
      user.id_token = auth.credentials.id_token if auth.credentials&.id_token
      user.save!
    else
      # Create new user
      user = create!(
        email: auth.info.email,
        google_id: auth.uid,
        id_token: auth.credentials&.id_token
      )
    end

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
      exp = payload["exp"] if payload

      # Valid if current time is before expiration
      exp && Time.now.to_i < exp
    rescue JWT::DecodeError, JWT::ExpiredSignature
      false
    end
  end
end
