class User < ApplicationRecord
  validates :public_key, presence: true, uniqueness: true
end
