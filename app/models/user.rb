# == Schema Information
#
# Table name: users
#
#  id                     :integer          not null, primary key
#  name                   :string           not null
#  email                  :string           default(""), not null
#  is_admin               :boolean          default("f"), not null
#  balance                :integer          default("0"), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  encrypted_password     :string           default(""), not null
#  reset_password_token   :string
#  reset_password_sent_at :datetime
#  remember_created_at    :datetime
#
# Indexes
#
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#

#  (c) goodprogrammer.ru
#
# Юзер — он и в Африке юзер, только в Африке черный :)
class User < ActiveRecord::Base
  devise :database_authenticatable, :registerable, :recoverable, :validatable, :rememberable

  # имя не пустое, email валидирует Devise
  validates :name, presence: true

  # поле только булевское (лож/истина) - недопустимо nil
  validates :is_admin, inclusion: {in: [true, false]}, allow_nil: false

  # это поле должно быть только целым числом, значение nil - недопустимо
  validates :balance, numericality: {only_integer: true}, allow_nil: false

  # у юзера много игр, они удалятся из базы вместе с ним
  has_many :games, dependent: :destroy

  # расчет среднего выигрыша по всем играм юзера
  def average_prize
    (balance.to_f/games.count).round unless games.count.zero?
  end
end
