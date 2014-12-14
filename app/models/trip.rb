class Trip < ActiveRecord::Base
  belongs_to :users
  belongs_to :destination

  validates_presence_of :start, :end
  validate :start_date_cannot_be_greater_than_end

  def start_date_cannot_be_greater_than_end
    errors.add(:start, "can't be in the past") if verify_blank && start > self.end
  end

  private

  def verify_blank
    !start.blank? && !self.end.blank?
  end
end
