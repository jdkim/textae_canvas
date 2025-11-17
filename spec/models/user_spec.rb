require 'rails_helper'

RSpec.describe User, type: :model do
  let(:user) { User.new(params) }
  describe '#valid?' do
    subject { user }

    context 'with valid email, google_id' do
      let(:params) { { email: "test@example.com", google_id: 1 } }
      it { is_expected.to be_valid }
    end

    context 'without email' do
      let(:params) { { google_id: 1 } }
      it {
        is_expected.not_to be_valid
        expect(user.errors[:email]).to include("can't be blank")
      }
    end

    context 'without google_id' do
      let(:params) { { email: "test@example.com" } }
      it {
        is_expected.not_to be_valid
        expect(user.errors[:google_id]).to include("can't be blank")
      }
    end

    context 'with duplicate email' do
      before { User.create!(email: "test@example.com", google_id: 1) }
      let(:user) { User.new(email: "test@example.com", google_id: 2) }
      it 'is not valid' do
        expect(user).not_to be_valid
        expect(user.errors[:email]).to include("has already been taken")
      end
    end

    context 'with duplicate google_id' do
      before { User.create!(email: "test1@example.com", google_id: 1) }
      let(:user) { User.new(email: "test2@example.com", google_id: 1) }
      it 'is not valid' do
        expect(user).not_to be_valid
        expect(user.errors[:google_id]).to include("has already been taken")
      end
    end
  end

  describe '.from_omniauth' do
    let(:auth) do
      double('auth',
        info: double('info', email: 'test@example.com'),
        uid: '12345',
        credentials: double('credentials', id_token: 'mock_id_token')
      )
    end

    context 'when user does not exist' do
      it 'creates a new user with omniauth data' do
        expect {
          User.from_omniauth(auth)
        }.to change(User, :count).by(1)

        user = User.last
        expect(user.email).to eq('test@example.com')
        expect(user.google_id).to eq('12345')
        expect(user.id_token).to eq('mock_id_token')
      end
    end

    context 'when user already exists' do
      let!(:existing_user) { User.create!(email: 'test@example.com', google_id: '12345', id_token: 'old_token') }

      it 'updates only id_token and keeps immutable fields' do
        expect {
          User.from_omniauth(auth)
        }.not_to change(User, :count)

        existing_user.reload
        expect(existing_user.email).to eq('test@example.com')
        expect(existing_user.google_id).to eq('12345')
        expect(existing_user.id_token).to eq('mock_id_token')
      end
    end

    context 'when auth has no id_token' do
      let(:auth_without_token) do
        double('auth',
          info: double('info', email: 'test@example.com'),
          uid: '12345',
          credentials: nil
        )
      end

      it 'creates user without id_token' do
        user = User.from_omniauth(auth_without_token)
        expect(user.id_token).to be_nil
      end
    end
  end

  describe '#jwt_token' do
    let(:user) { User.create!(email: 'test@example.com', google_id: '12345') }

    context 'when user has valid id_token' do
      before do
        # 有効なIDトークンをモック（1時間後に期限切れ）
        payload = { exp: Time.now.to_i + 3600 }
        valid_token = JWT.encode(payload, 'secret', 'HS256')
        user.update!(id_token: valid_token)
      end

      it 'returns the Google ID token' do
        expect(user.jwt_token).to eq(user.id_token)
      end
    end

    context 'when user has expired id_token' do
      before do
        # 期限切れのIDトークンをモック
        payload = { exp: Time.now.to_i - 3600 }
        expired_token = JWT.encode(payload, 'secret', 'HS256')
        user.update!(id_token: expired_token)
      end

      it 'returns nil for expired token' do
        expect(user.jwt_token).to be_nil
      end
    end

    context 'when user has no id_token' do
      it 'returns nil' do
        expect(user.jwt_token).to be_nil
      end
    end
  end
end
