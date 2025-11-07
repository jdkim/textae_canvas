class User < ApplicationRecord
  devise :omniauthable, omniauth_providers: %i[google_oauth2]

  validates :email, presence: true, uniqueness: true
  validates :google_id, presence: true, uniqueness: true

  def self.from_omniauth(auth)
    user = where(email: auth.info.email).first_or_initialize do |u|
      u.email = auth.info.email
      u.google_id = auth.uid
    end

    # ユーザー情報を更新（新規作成時と既存ユーザーの更新時の両方）
    user.email = auth.info.email
    user.google_id = auth.uid

    # OpenID ConnectのIDトークンを保存（credentials内に含まれている）
    if auth.credentials&.id_token
      user.id_token = auth.credentials.id_token
    end

    user.save!
    user
  end

  # GoogleのIDトークン（OpenID Connect）を返す
  def jwt_token
    id_token if id_token.present? && token_valid?
  end

  private

  # IDトークンの有効性をチェック
  def token_valid?
    return false if id_token.blank?

    begin
      # JWTのデコードを試行（検証なしで期限のみチェック）
      decoded_token = JWT.decode(id_token, nil, false)
      payload = decoded_token.first
      exp = payload['exp'] if payload

      # 現在時刻が期限より前であれば有効
      exp && Time.now.to_i < exp
    rescue JWT::DecodeError, JWT::ExpiredSignature
      false
    end
  end
end
