class User < ApplicationRecord
  has_many :bookmarks, dependent: :destroy
end
