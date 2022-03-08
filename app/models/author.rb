class Author < ApplicationRecord
  has_many :notes, dependent: :destroy
end
