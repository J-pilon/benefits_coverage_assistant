class ChatMessage < ApplicationRecord
  belongs_to :profile
  has_many :support_tickets, dependent: :destroy

  validates :user_message, presence: true

  # Order messages by creation time (newest first for display)
  scope :ordered, -> { order(created_at: :asc) }
  scope :recent_first, -> { order(created_at: :desc) }
end
