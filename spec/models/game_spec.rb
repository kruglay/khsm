# (c) goodprogrammer.ru

require 'rails_helper'
require 'support/my_spec_helper' # наш собственный класс с вспомогательными методами

# Тестовый сценарий для модели Игры
# В идеале - все методы должны быть покрыты тестами,
# в этом классе содержится ключевая логика игры и значит работы сайта.
RSpec.describe Game, type: :model do
  # пользователь для создания игр
  let(:user) { FactoryGirl.create(:user) }

  # игра с прописанными игровыми вопросами
  let(:game_w_questions) { FactoryGirl.create(:game_with_questions, user: user) }


  # Группа тестов на работу фабрики создания новых игр
  context 'Game Factory' do
    it 'Game.create_game! new correct game' do
      # генерим 60 вопросов с 4х запасом по полю level,
      # чтобы проверить работу RANDOM при создании игры
      generate_questions(60)

      game = nil
      # создaли игру, обернули в блок, на который накладываем проверки
      expect {
        game = Game.create_game_for_user!(user)
      }.to change(Game, :count).by(1).and(# проверка: Game.count изменился на 1 (создали в базе 1 игру)
        change(GameQuestion, :count).by(15).and(# GameQuestion.count +15
          change(Question, :count).by(0) # Game.count не должен измениться
        )
      )
      # проверяем статус и поля
      expect(game.user).to eq(user)
      expect(game.status).to eq(:in_progress)
      # проверяем корректность массива игровых вопросов
      expect(game.game_questions.size).to eq(15)
      expect(game.game_questions.map(&:level)).to eq (0..14).to_a
    end
  end



  # тесты на основную игровую логику
  context 'game mechanics' do

    # правильный ответ должен продолжать игру
    it 'answer correct continues game' do
      # текущий уровень игры и статус
      level = game_w_questions.current_level
      q = game_w_questions.current_game_question
      expect(game_w_questions.status).to eq(:in_progress)

      game_w_questions.answer_current_question!(q.correct_answer_key)

      # перешли на след. уровень
      expect(game_w_questions.current_level).to eq(level + 1)
      # ранее текущий вопрос стал предыдущим
      expect(game_w_questions.previous_game_question).to eq(q)
      expect(game_w_questions.current_game_question).not_to eq(q)
      # игра продолжается
      expect(game_w_questions.status).to eq(:in_progress)
      expect(game_w_questions.finished?).to be_falsey
    end

    it 'Game.take_money! finishes the game' do
      question = game_w_questions.current_game_question
      game_w_questions.answer_current_question!(question.correct_answer_key)

      game_w_questions.take_money!

      prize = game_w_questions.prize

      expect(prize).to be > 0

      expect(game_w_questions.status).to eq(:money)
      expect(game_w_questions.finished?).to be_truthy
      expect(user.balance).to eq prize

    end
  end

  context 'game condition' do
    it 'correct .current_game_question' do
      game_w_questions.current_level = 1
      game_w_questions.game_questions.order(:current_level)
      expect(game_w_questions.current_game_question).to eq(game_w_questions.game_questions[1])
    end

    it 'correct .previous_game_question' do
      expect(game_w_questions.previous_game_question).to eq(nil)

      game_w_questions.game_questions.order(:current_level)

      game_w_questions.current_level = 2
      expect(game_w_questions.previous_game_question).to eq(game_w_questions.game_questions[1])
    end

    it 'correct .previous_level' do
      game_w_questions.current_level = 2
      expect(game_w_questions.previous_level).to eq(1)
    end
  end

  context '.answer_current_question!' do
    it 'return false if time end' do
      game_w_questions.current_level = 2
      game_w_questions.created_at = Time.now - 3600
      # letter 'd' always right
      expect(game_w_questions.answer_current_question!('d')).to be_falsey
      expect(game_w_questions.status).to eq :timeout
    end

    it 'return false if game finished' do
      game_w_questions.current_level = 2
      game_w_questions.finished_at = Time.now - 10
      expect(game_w_questions.answer_current_question!('d')).to be_falsey
      expect(game_w_questions.status).to eq :money
    end

    it 'answer incorrect' do
      game_w_questions.current_level = 5
      user_balance_before = user.balance
      game_w_questions.answer_current_question!('a')

      expect(game_w_questions.prize).to eq(Game::PRIZES[Game::FIREPROOF_LEVELS[0]])
      expect(game_w_questions.finished_at).to be_between(Time.now - 10, Time.now)
      expect(game_w_questions.is_failed).to be_truthy
      expect(user.balance).to eq(user_balance_before + game_w_questions.prize)
      expect(game_w_questions.status).to eq :fail
    end

    it 'last correct answer' do
      last_level = Question::QUESTION_LEVELS.max
      game_w_questions.current_level = last_level
      user_balance_before = user.balance
      game_w_questions.answer_current_question!('d')

      expect(game_w_questions.prize).to eq(Game::PRIZES[last_level])
      expect(game_w_questions.finished_at).to be_between(Time.now - 10, Time.now)
      expect(game_w_questions.is_failed).to be_falsey
      expect(user.balance).to eq(user_balance_before + game_w_questions.prize)
      expect(game_w_questions.status).to eq :won
    end

    it 'correct answer' do
      game_w_questions.current_level = 2
      game_w_questions.answer_current_question!('d')

      expect(game_w_questions.current_level).to eq(3)
      expect(game_w_questions.status).to eq :in_progress
    end
  end

  context '.status' do
    # перед каждым тестом "завершаем игру"
    before(:each) do
      game_w_questions.finished_at = Time.now
      expect(game_w_questions.finished?).to be_truthy
    end

    it ':won' do
      game_w_questions.current_level = Question::QUESTION_LEVELS.max + 1
      expect(game_w_questions.status).to eq(:won)
    end

    it ':fail' do
      game_w_questions.is_failed = true
      expect(game_w_questions.status).to eq(:fail)
    end

    it ':timeout' do
      game_w_questions.created_at = 1.hour.ago
      game_w_questions.is_failed = true
      expect(game_w_questions.status).to eq(:timeout)
    end

    it ':money' do
      expect(game_w_questions.status).to eq(:money)
    end
  end
end
