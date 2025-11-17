class User < ApplicationRecord
  devise :omniauthable, omniauth_providers: %i[google_oauth2]

  validates :email, presence: true, uniqueness: true
  validates :google_id, presence: true, uniqueness: true

  def self.from_omniauth(auth)
    user = where(email: auth.info.email).first_or_initialize(
      google_id: auth.uid
    )

    user.id_token = auth.credentials.id_token if auth.credentials&.id_token
    user.save!
    user
  end

  # Return Google ID token (OpenID Connect)
  # Validate expiration timestamp when using the token
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
